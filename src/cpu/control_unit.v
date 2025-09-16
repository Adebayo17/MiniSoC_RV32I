module control_unit (
    input wire [6:0]  opcode,
    input wire [2:0]  funct3,
    input wire [6:0]  funct7,
    
    output reg        reg_write,
    output reg        mem_write,
    output reg        mem_read,
    output reg [1:0]  mem_to_reg,
    output reg        branch,
    output reg        alu_src,
    output reg [3:0]  alu_op,
    output reg        jump
);
    // -------------------------------------------
    // Instruction opcodes (RV32I)
    // -------------------------------------------
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_JALR    = 7'b1100111;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_IMM     = 7'b0010011;
    localparam OP_R       = 7'b0110011;
    localparam OP_SYSTEM  = 7'b1110011;

    always @(*) begin
        // Default values
        reg_write       = 0;
        mem_write       = 0;
        mem_read        = 0;
        mem_to_reg      = 2'b00;
        branch          = 0;
        alu_src         = 0;
        alu_op          = 4'b0000;
        jump            = 0;

        case (opcode)
            OP_R: begin // R-type
                reg_write = 1;
                mem_to_reg = 2'b00;
                // ALU Control Logic 
                case ({funct7[5], funct3})
                    4'b0000: alu_op = 4'b0000; // ADD
                    4'b1000: alu_op = 4'b0001; // SUB
                    4'b0111: alu_op = 4'b0010; // AND
                    4'b0110: alu_op = 4'b0011; // OR
                    4'b0100: alu_op = 4'b0100; // XOR
                    4'b0001: alu_op = 4'b0101; // SLL
                    4'b0101: alu_op = 4'b0110; // SRL
                    4'b1101: alu_op = 4'b0111; // SRA
                    4'b0010: alu_op = 4'b1000; // SLT
                    4'b0011: alu_op = 4'b1001; // SLTU
                endcase
            end
            
            OP_IMM: begin // I-type
                reg_write  = 1;
                alu_src    = 1;
                mem_to_reg = 2'b00;
                // ALU Control Logic 
                case ({funct7[5] & (funct3 == 3'b101), funct3})
                    4'b0000: alu_op = 4'b0000; // ADDI
                    4'b0111: alu_op = 4'b0010; // ANDI
                    4'b0110: alu_op = 4'b0011; // ORI
                    4'b0100: alu_op = 4'b0100; // XORI
                    4'b0001: alu_op = 4'b0101; // SLLI
                    4'b0101: alu_op = 4'b0110; // SRLI
                    4'b1101: alu_op = 4'b0111; // SRAI
                    4'b0010: alu_op = 4'b1000; // SLTI
                    4'b0011: alu_op = 4'b1001; // SLTIU
                endcase
            end
            
            OP_LOAD: begin
                reg_write  = 1;
                mem_read   = 1;
                mem_to_reg = 2'b01;
                alu_src    = 1;
                alu_op     = 4'b0000; // ADD
            end
            
            OP_STORE: begin
                mem_write = 1;
                alu_src   = 1;
                alu_op    = 4'b0000; // ADD
            end
            
            OP_BRANCH: begin
                branch = 1;
                alu_op = {1'b0, funct3}; // Compare ops
            end
            
            OP_JAL: begin
                jump       = 1;
                reg_write  = 1;
                mem_to_reg = 2'b10;
                alu_op     = 4'b0000; // ADD
            end
            
            OP_JALR: begin
                jump      = 1;
                reg_write = 1;
                mem_to_reg = 2'b10;
                alu_src   = 1;
                alu_op    = 4'b0000; // ADD
            end
            
            default: begin
                mem_to_reg    = 2'b00;
            end
        endcase
    end
endmodule