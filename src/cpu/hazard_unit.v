module hazard_unit #(
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
) (
    // From Fetch Stage
    input wire                              fetch_valid,
    input wire [DATA_WIDTH-1:0]             if_instr_out,

    // From Decode Stage
    input wire [REGFILE_ADDR_WIDTH-1:0]     id_rs1,         // rs1 field from instruction in decode
    input wire [REGFILE_ADDR_WIDTH-1:0]     id_rs2,         // rs2 field from instruction in decode
    input wire                              id_mem_read,    // Load instruction in decode  
    input wire                              id_valid,                
    
    // From Execute Stage
    input wire [REGFILE_ADDR_WIDTH-1:0]     ex_rd,          // Destination register of EX stage instruction
    input wire                              ex_reg_write,   // RegWrite signal from EX stage
    input wire                              ex_mem_read,    // MemRead signal from EX stage (load instruction)
    input wire                              ex_valid,
    
    // From Memory Stage  
    input wire [REGFILE_ADDR_WIDTH-1:0]     mem_rd,         // Destination register of MEM stage instruction
    input wire                              mem_reg_write,  // RegWrite signal from MEM stage
    input wire                              mem_valid,
    input wire                              mem_busy,       // Memory operation in progress
    input wire                              mem_ack,        // Memory operation completed
    
    // Control Flow
    input                                   branch_taken,    // From execute stage branch unit

    // Outputs
    output reg                              stall_fetch,     // Pipeline stall signal
    output reg                              stall_decode,    // Pipeline stall signal
    output reg                              stall_execute,   // Pipeline stall signal
    output reg                              stall_writeback, // Pipeline stall signal
    output reg                              flush_fetch,     // Pipeline flush signal
    output reg                              flush_decode,    // Pipeline flush signal
    output reg                              flush_execute    // Pipeline flush signal
);
    
    // -------------------------------------------
    // Hazard Detection
    // -------------------------------------------
    wire decode_use_hazard;
    wire load_use_hazard;
    wire mem_busy_hazard;

    // assign decode_stage_hazard = (id_valid && ex_reg_write && ex_valid && // Instruction in decode uses register being written by instruction in execute
    //                             ((id_rs1 == ex_rd && id_rs1 != 0)   || 
    //                              (id_rs2 == ex_rd && id_rs2 != 0))) ||
    //                              (id_valid && ex_mem_read && ex_valid &&  // Instruction in decode uses register being loaded by instruction in execute  
    //                             ((id_rs1 == ex_rd && id_rs1 != 0) || 
    //                              (id_rs2 == ex_rd && id_rs2 != 0)));
                                
    assign decode_stage_hazard = 
                                // Case 1: Instruction in decode is LOAD and depends on load in execute
                                (id_mem_read && id_valid && ex_mem_read && ex_valid &&
                                ((id_rs1 == ex_rd && id_rs1 != 0) || (id_rs2 == ex_rd && id_rs2 != 0))) ||
                                
                                // Case 2: Instruction in decode is STORE and depends on load in execute
                                (id_valid && !id_mem_read && ex_mem_read && ex_valid &&  // Store instruction
                                ((id_rs1 == ex_rd && id_rs1 != 0) || (id_rs2 == ex_rd && id_rs2 != 0))) ||
                                
                                // Case 3: Critical ALU dependency that forwarding can't handle
                                (id_valid && ex_mem_read && ex_valid &&  // Load in execute
                                ((id_rs1 == ex_rd && id_rs1 != 0) || (id_rs2 == ex_rd && id_rs2 != 0)));


    // Detect if decode stage needs result from current load instruction in execute
    assign load_use_hazard =  ex_mem_read && ex_valid && 
                              id_mem_read && id_valid && 
                            ((id_rs1 == ex_rd && id_rs1 != 0) || 
                             (id_rs2 == ex_rd && id_rs2 != 0));

    assign  mem_busy_hazard = ex_mem_read && mem_busy && !mem_ack;


    // -------------------------------------------
    // Hazard and Control Flow
    // -------------------------------------------
    always @(*) begin
        // Default values
        stall_fetch     = 1'b0;
        stall_decode    = 1'b0;
        stall_execute   = 1'b0;
        stall_writeback = 1'b0;

        flush_fetch     = 1'b0;
        flush_decode    = 1'b0;
        flush_execute   = 1'b0;

        // Priority 1: Load-use hazard: stall fetch and decode
        if (decode_stage_hazard) begin
            stall_fetch     = 1'b1;
            stall_decode    = 1'b1;
            stall_execute   = 1'b0; // Let load instruction proceed
            stall_writeback = 1'b0;
        end
        else if (load_use_hazard) begin
            stall_fetch     = 1'b1;
            stall_decode    = 1'b1;
            stall_execute   = 1'b0; // Let load instruction proceed
            stall_writeback = 1'b0;
        end
        // Priority 2 - Multi-cycle memory operations
        else if (mem_busy_hazard) begin
            stall_fetch     = 1'b1;
            stall_decode    = 1'b1;
            stall_execute   = 1'b1; // Stall execute until memory responds
            stall_writeback = 1'b1; // Stall WB during memory ops
        end


        // Branch/Jump taken: flush wrong path instructions
        if (branch_taken) begin
            flush_fetch     = 1'b1;
            flush_decode    = 1'b1;
            // Note: Execute stage contains the branch/jump it self, so no flush
        end
    end
endmodule