module hazard_unit (
    // Instruction decode info
    input wire [4:0] decode_rs1,
    input wire [4:0] decode_rs2,
    input wire       decode_mem_read,
    
    // Pipeline states
    input wire [4:0] execute_rd,
    input wire       execute_mem_read,
    input wire [4:0] memory_rd,
    input wire       memory_mem_read,
    
    // Control outputs
    output reg       stall,
    output reg       flush
);

    always @(*) begin
        // Load-use hazard detection
        stall = (execute_mem_read && 
                ((decode_rs1 == execute_rd) || 
                 (decode_rs2 == execute_rd)));
        
        // Control hazard (branches flush 1 instruction)
        flush = 0; // Connected to branch signals
    end
endmodule