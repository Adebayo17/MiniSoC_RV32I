module hazard_unit #(
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
) (
    // From Decode Stage (ID)
    input wire [REGFILE_ADDR_WIDTH-1:0]     id_rs1,         // rs1 field from instruction in decode
    input wire [REGFILE_ADDR_WIDTH-1:0]     id_rs2,         // rs2 field from instruction in decode
    input wire                              id_mem_read,    // Load instruction in decode  
    input wire                              id_valid,                
    
    // From Execute Stage (EX)
    input wire [REGFILE_ADDR_WIDTH-1:0]     ex_rd,          // Destination register of EX stage instruction
    input wire                              ex_reg_write,   // RegWrite signal from EX stage
    input wire                              ex_mem_read,    // MemRead signal from EX stage (load instruction)
    input wire                              ex_valid,
    
    // From Memory Stage (MEM) 
    input wire [REGFILE_ADDR_WIDTH-1:0]     mem_rd,         // Destination register of MEM stage instruction
    input wire                              mem_reg_write,  // RegWrite signal from MEM stage
    input wire                              mem_valid,
    input wire                              mem_busy,       // Memory operation in progress
    input wire                              mem_ack,        // Memory operation completed
    
    // Control Flow
    input                                   branch_taken,    // From execute stage branch unit

    // Outputs (Stall and Flush)
    output reg                              stall_fetch,     
    output reg                              stall_decode,    
    output reg                              stall_execute,
    output reg                              stall_mem,   
    output reg                              stall_writeback, 

    output reg                              flush_fetch,     
    output reg                              flush_decode,
    output reg                              flush_execute 
);
    
    // -------------------------------------------
    // Hazard Detection
    // -------------------------------------------
    wire load_use_hazard;
    wire ex_to_id_hazard;
    wire mem_busy_hazard;

    // True load-use hazard: instruction in decode needs result from load in execute
    // Example 1: Load → ALU operation
    //      lw  x1, 0(x2)       # EX stage - loading to x1
    //      add x3, x1, x4      # ID stage - needs x1 (NOT a load!)
    // Example 2: Load → Store  
    //      lw  x1, 0(x2)       # EX stage - loading to x1  
    //      sw  x1, 0(x3)       # ID stage - needs x1 for store (NOT a load!)
    // Example 3: Load → Branch
    //      lw  x1, 0(x2)       # EX stage - loading to x1
    //      beq x1, x0, label   # ID stage - needs x1 for branch
    assign load_use_hazard = ex_mem_read && ex_valid && 
                            ((id_rs1 == ex_rd && id_rs1 != 0) || 
                             (id_rs2 == ex_rd && id_rs2 != 0));
    

    // Memory busy hazard: multi-cycle memory operation
    assign mem_busy_hazard = mem_busy && !mem_ack;


    // -------------------------------------------
    // Hazard and Control Flow
    // -------------------------------------------
    always @(*) begin
        // Default values
        stall_fetch     = 1'b0;
        stall_decode    = 1'b0;
        stall_execute   = 1'b0;
        stall_mem       = 1'b0;
        stall_writeback = 1'b0;

        flush_fetch     = 1'b0;
        flush_decode    = 1'b0;
        flush_execute   = 1'b0;

        // Priority 1: Memory busy hazard (highest priority)
        if (mem_busy_hazard) begin
            stall_fetch     = 1'b1;
            stall_decode    = 1'b1;
            stall_execute   = 1'b1;
            stall_mem       = 1'b1;
            stall_writeback = 1'b1;
        end
        // Priority 2: Load-use hazard (requires 1-cycle stall)
        else if (load_use_hazard) begin
            stall_fetch     = 1'b1;
            stall_decode    = 1'b1;
            flush_execute   = 1'b1;     // EX advances (bubble inserted from decode stage)
        end


        // Branch/jump taken - flush wrong path instructions
        // (FLushes generally override Stalls for pipeline registers)
        if (branch_taken) begin
            flush_fetch     = 1'b1;
            flush_decode    = 1'b1;

            // Mask the stalls if we are flushing, to ensure the PC can jump to the new branch target
            stall_fetch     = 1'b0;
            stall_decode    = 1'b0;
        end
    end
endmodule