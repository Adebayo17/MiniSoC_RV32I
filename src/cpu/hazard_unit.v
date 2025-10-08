module hazard_unit #(
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
) (
    // From Fetch Stage
    input wire                              fetch_valid,

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
    
    // Control Flow
    input                                   branch_taken,    // From execute stage branch unit

    // Outputs
    output reg                              stall_fetch,     // Pipeline stall signal
    output reg                              stall_decode,    // Pipeline stall signal
    output reg                              stall_execute,   // Pipeline stall signal
    output reg                              flush_fetch,     // Pipeline flush signal
    output reg                              flush_decode,    // Pipeline flush signal
    output reg                              flush_execute    // Pipeline flush signal
);
    
    // -------------------------------------------
    // Hazard Detection
    // -------------------------------------------

    wire load_use_hazard;
    wire data_hazard;

    // Detect if decode stage needs result from current load instruction in execute
    assign load_use_hazard = ex_mem_read && ex_valid && 
                            ((id_rs1 == ex_rd && id_rs1 != 0) || 
                             (id_rs2 == ex_rd && id_rs2 != 0));

    // Data hazard: instruction in decode depends on result not yet available
    assign data_hazard = ex_reg_write && ex_valid && 
                        ((id_rs1 == ex_rd && id_rs1 != 0) || 
                         (id_rs2 == ex_rd && id_rs2 != 0));

    // -------------------------------------------
    // Hazard and Control Flow
    // -------------------------------------------
    always @(*) begin
        // Default values
        stall_fetch     = 1'b0;
        stall_decode    = 1'b0;
        stall_execute   = 1'b0;

        flush_fetch     = 1'b0;
        flush_decode    = 1'b0;
        flush_execute   = 1'b0;

        // Load-use hazard: stall fetch and decode
        if (load_use_hazard) begin
            stall_fetch     = 1'b1;
            stall_decode    = 1'b1;
            stall_execute   = 1'b0; // Let load instruction proceed
        end
        // else if (data_hazard) begin
        //     stall_fetch     = 1'b1;
        //     stall_decode    = 1'b1;
        //     stall_execute   = 1'b0;
        // end


        // Branch/Jump taken: flush wrong path instructions
        if (branch_taken) begin
            flush_fetch     = 1'b1;
            flush_decode    = 1'b1;
            // Note: Execute stage contains the branch/jump it self, so no flush
        end
        
        // Memory operation stall (if memory takes multiple cycles)
        // if (ex_mem_read) begin
        //     stall_fetch     = 1'b1;
        //     stall_decode    = 1'b1;
        //     stall_execute   = 1'b1;
        // end
    end


endmodule