module alu #(
    parameter DATA_WIDTH = 32
) (
    input wire [3:0]            alu_op,
    input wire [DATA_WIDTH-1:0] operand_a,
    input wire [DATA_WIDTH-1:0] operand_b,
    output reg [DATA_WIDTH-1:0] alu_result,
    output reg                  alu_zero,
    output reg                  alu_lt,      // New: Less-than comparison
    output reg                  alu_ltu      // New: Unsigned less-than
);

    // RISC-V ALU operation encoding (matches funct3 + funct7[5])
    localparam [3:0]    ALU_ADD  = 4'b0000;  // add/addi
    localparam [3:0]    ALU_SUB  = 4'b1000;  // sub
    localparam [3:0]    ALU_SLL  = 4'b0001;  // sll/slli
    localparam [3:0]    ALU_SLT  = 4'b0010;  // slt/slti
    localparam [3:0]    ALU_SLTU = 4'b0011;  // sltu/sltiu
    localparam [3:0]    ALU_XOR  = 4'b0100;  // xor/xori
    localparam [3:0]    ALU_SRL  = 4'b0101;  // srl/srli
    localparam [3:0]    ALU_SRA  = 4'b1101;  // sra/srai
    localparam [3:0]    ALU_OR   = 4'b0110;  // or/ori
    localparam [3:0]    ALU_AND  = 4'b0111;  // and/andi

    // Shift amount (5-bits for RV32I)
    wire [4:0] shamt = operand_b[4:0];

    always @(*) begin
        // Default outputs
        alu_zero = 1'b0;
        alu_lt   = 1'b0;
        alu_ltu  = 1'b0;
        
        case (alu_op)
            ALU_ADD:  alu_result = operand_a + operand_b;
            ALU_SUB:  alu_result = operand_a - operand_b;
            ALU_SLL:  alu_result = operand_a << shamt;
            ALU_SLT:  begin
                alu_result = {31'b0, $signed(operand_a) < $signed(operand_b)};
                alu_lt = $signed(operand_a) < $signed(operand_b);
            end
            ALU_SLTU: begin
                alu_result = {31'b0, operand_a < operand_b};
                alu_ltu = operand_a < operand_b;
            end
            ALU_XOR:  alu_result = operand_a ^ operand_b;
            ALU_SRL:  alu_result = operand_a >> shamt;
            ALU_SRA:  alu_result = $signed(operand_a) >>> shamt;
            ALU_OR:   alu_result = operand_a | operand_b;
            ALU_AND:  alu_result = operand_a & operand_b;
            default:  alu_result = 32'b0;  // Should never occur
        endcase

        // Zero flag (for BEQ/BNE)
        alu_zero = (alu_result == 0);
    end

    // Formal verification assertions
    // synthesis translate_off
    always @(*) begin
        if (alu_op == ALU_SLL || alu_op == ALU_SRL || alu_op == ALU_SRA) begin
            assert(shamt < 32) else $error("Invalid shift amount");
        end
    end
    // synthesis translate_on

endmodule
