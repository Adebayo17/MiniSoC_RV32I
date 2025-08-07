module alu #(
    parameter DATA_WIDTH = 32
) (
    input wire [3:0]            alu_op,
    input wire [DATA_WIDTH-1:0] operand_a,
    input wire [DATA_WIDTH-1:0] operand_b,
    output reg [DATA_WIDTH-1:0] alu_result,
    output reg                  alu_zero
);
    localparam [3:0] ALU_ADD = 4'b0000;
    localparam [3:0] ALU_SUB = 4'b0001;
    localparam [3:0] ALU_AND = 4'b0010;
    localparam [3:0] ALU_OR  = 4'b0011;
    localparam [3:0] ALU_XOR = 4'b0100;
    localparam [3:0] ALU_SLL = 4'b0101;
    localparam [3:0] ALU_SRL = 4'b0110;
    localparam [3:0] ALU_SRA = 4'b0111;

    // Shift amount (5-bits for RV32I)
    wire [4:0] shamt;

    always @(*) begin
        alu_zero = 1'b0;
        shamt    = operand_b[4:0];
        case (alu_op)
            ALU_ADD: alu_result = operand_a + operand_b;
            ALU_SUB: alu_result = operand_a - operand_b;
            ALU_AND: alu_result = operand_a & operand_b;
            ALU_OR : alu_result = operand_a | operand_b;
            ALU_XOR: alu_result = operand_a ^ operand_b;
            ALU_SLL: alu_result = operand_a << shamt;
            ALU_SRL: alu_result = operand_a >> shamt;
            ALU_SRA: alu_result = $signed(operand_a) >>> shamt; 
            default: alu_result = 32'b0;
        endcase

        if (alu_result == 0) begin
            alu_zero = 1'b1;
        end
    end    
endmodule