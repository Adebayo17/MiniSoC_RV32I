module forwarding_unit (
    // Decode stage inputs
    input wire [4:0] decode_rs1,
    input wire [4:0] decode_rs2,
    
    // Execute stage inputs
    input wire [4:0] execute_rd,
    input wire       execute_reg_write,
    
    // Memory stage inputs
    input wire [4:0] memory_rd,
    input wire       memory_reg_write,
    
    // Writeback stage inputs
    input wire [4:0] writeback_rd,
    input wire       writeback_reg_write,
    
    // Outputs
    output reg [1:0] forward_rs1,
    output reg [1:0] forward_rs2
);

    // Forwarding selection codes
    localparam [1:0] FROM_REG  = 2'b00;
    localparam [1:0] FROM_EX   = 2'b01;
    localparam [1:0] FROM_MEM  = 2'b10;
    localparam [1:0] FROM_WB   = 2'b11;

    always @(*) begin
        // Default to register file values
        forward_rs1 = FROM_REG;
        forward_rs2 = FROM_REG;
        
        // RS1 Forwarding
        if (decode_rs1 != 0) begin
            if (execute_reg_write && (execute_rd == decode_rs1)) begin
                forward_rs1 = FROM_EX;  // Forward from execute stage
            end
            else if (memory_reg_write && (memory_rd == decode_rs1)) begin
                forward_rs1 = FROM_MEM; // Forward from memory stage
            end
            else if (writeback_reg_write && (writeback_rd == decode_rs1)) begin
                forward_rs1 = FROM_WB;  // Forward from writeback stage
            end
        end
        
        // RS2 Forwarding
        if (decode_rs2 != 0) begin
            if (execute_reg_write && (execute_rd == decode_rs2)) begin
                forward_rs2 = FROM_EX;
            end
            else if (memory_reg_write && (memory_rd == decode_rs2)) begin
                forward_rs2 = FROM_MEM;
            end
            else if (writeback_reg_write && (writeback_rd == decode_rs2)) begin
                forward_rs2 = FROM_WB;
            end
        end
    end

endmodule