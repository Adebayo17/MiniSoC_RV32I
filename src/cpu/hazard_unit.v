module hazard_unit (
    // From Decode Stage
    input [4:0] decode_rs1,      // rs1 field from instruction in decode
    input [4:0] decode_rs2,      // rs2 field from instruction in decode
    
    // From Execute Stage
    input [4:0] execute_rd,      // Destination register of EX stage instruction
    input       execute_reg_write,// RegWrite signal from EX stage
    input       execute_mem_read, // MemRead signal from EX stage (load instruction)
    
    // From Memory Stage  
    input [4:0] memory_rd,       // Destination register of MEM stage instruction
    input       memory_reg_write, // RegWrite signal from MEM stage
    
    // From Control Flow
    input       branch_taken,    // From execute stage branch unit
    // Outputs
    output reg  stall,           // Pipeline stall signal
    output reg  flush            // Pipeline flush signal
);
    wire load_use_hazard, ex_hazard, mem_hazard;

    // Detect if decode stage needs result from current load instruction
    assign load_use_hazard = execute_mem_read && 
                            ((decode_rs1 == execute_rd) || 
                            (decode_rs2 == execute_rd));

    // EX hazard (forward from ALU result)
    assign ex_hazard = execute_reg_write && 
                    ((decode_rs1 == execute_rd) || 
                    (decode_rs2 == execute_rd));

    // MEM hazard (forward from memory stage)
    assign mem_hazard = memory_reg_write && 
                    ((decode_rs1 == memory_rd) || 
                    (decode_rs2 == memory_rd));

    // Flush pipeline after taken branch/jump
    assign flush = branch_taken;

    always @(*) begin
        flush = branch_taken;
        stall = load_use_hazard || ex_hazard || mem_hazard;
    end

endmodule