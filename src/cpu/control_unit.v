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
    localparam OP_LUI     = 7'b0110111;
    localparam OP_AUIPC   = 7'b0010111;
    localparam OP_SYSTEM  = 7'b1110011;


    // -------------------------------------------
    // RISC-V ALU operation encoding
    // -------------------------------------------
    localparam [3:0]    ALU_ADD     = 4'b0000;  // add/addi
    localparam [3:0]    ALU_SUB     = 4'b1000;  // sub
    localparam [3:0]    ALU_SLL     = 4'b0001;  // sll/slli
    localparam [3:0]    ALU_SLT     = 4'b0010;  // slt/slti
    localparam [3:0]    ALU_SLTU    = 4'b0011;  // sltu/sltiu
    localparam [3:0]    ALU_XOR     = 4'b0100;  // xor/xori
    localparam [3:0]    ALU_SRL     = 4'b0101;  // srl/srli
    localparam [3:0]    ALU_SRA     = 4'b1101;  // sra/srai
    localparam [3:0]    ALU_OR      = 4'b0110;  // or/ori
    localparam [3:0]    ALU_AND     = 4'b0111;  // and/andi
    localparam [3:0]    ALU_PASSB   = 4'b1100;  // lui (pass operand_b through)

    // -------------------------------------------
    // BRANCH Code
    // -------------------------------------------
    localparam [2:0] BR_BEQ  = 3'b000;
    localparam [2:0] BR_BNE  = 3'b001;
    localparam [2:0] BR_BLT  = 3'b100;
    localparam [2:0] BR_BGE  = 3'b101;
    localparam [2:0] BR_BLTU = 3'b110;
    localparam [2:0] BR_BGEU = 3'b111;

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
                    4'b0_000: alu_op = ALU_ADD;   // ADD
                    4'b1_000: alu_op = ALU_SUB;   // SUB  
                    4'b0_001: alu_op = ALU_SLL;   // SLL
                    4'b0_010: alu_op = ALU_SLT;   // SLT
                    4'b0_011: alu_op = ALU_SLTU;  // SLTU
                    4'b0_100: alu_op = ALU_XOR;   // XOR
                    4'b0_101: alu_op = ALU_SRL;   // SRL
                    4'b1_101: alu_op = ALU_SRA;   // SRA
                    4'b0_110: alu_op = ALU_OR;    // OR
                    4'b0_111: alu_op = ALU_AND;   // AND
                    default:  alu_op = ALU_ADD;
                endcase
            end
            
            OP_IMM: begin // I-type
                reg_write  = 1;
                alu_src    = 1;
                mem_to_reg = 2'b00;
                // ALU Control Logic 
                case (funct3)
                    3'b000: alu_op = ALU_ADD;    // ADDI
                    3'b001: alu_op = ALU_SLL;    // SLLI
                    3'b010: alu_op = ALU_SLT;    // SLTI
                    3'b011: alu_op = ALU_SLTU;   // SLTIU
                    3'b100: alu_op = ALU_XOR;    // XORI
                    3'b101: alu_op = (funct7[5] ? ALU_SRA : ALU_SRL); // SRAI/SRLI
                    3'b110: alu_op = ALU_OR;     // ORI
                    3'b111: alu_op = ALU_AND;    // ANDI
                    default: alu_op = ALU_ADD;
                endcase
            end
            
            OP_LOAD: begin
                reg_write  = 1;
                mem_read   = 1;
                mem_to_reg = 2'b01;
                alu_src    = 1;
                alu_op     = ALU_ADD; // ADD
            end
            
            OP_STORE: begin
                mem_write = 1;
                alu_src   = 1;
                alu_op    = ALU_ADD; // ADD
            end
            
            OP_BRANCH: begin
                branch = 1;
                case (funct3)
                    BR_BEQ, BR_BNE:     alu_op = ALU_SUB;  // BEQ/BNE: subtract and check zero
                    BR_BLT, BR_BGE:     alu_op = ALU_SLT;  // BLT/BGE: signed compare
                    BR_BLTU, BR_BGEU:   alu_op = ALU_SLTU; // BLTU/BGEU: unsigned compare
                    default:            alu_op = ALU_SUB;
                endcase
            end
            
            OP_JAL: begin
                jump       = 1;
                reg_write  = 1;
                mem_to_reg = 2'b10;
                alu_op     = ALU_ADD; // ADD
            end
            
            OP_JALR: begin
                jump      = 1;
                reg_write = 1;
                mem_to_reg = 2'b10;
                alu_src   = 1;
                alu_op    = ALU_ADD; // ADD
            end

            OP_LUI: begin
                reg_write  = 1;
                alu_src    = 1;         // Use immediate as ALU operand B
                mem_to_reg = 2'b00;     // Write ALU result to register
                alu_op     = ALU_PASSB; // Special "PASS_B" operation (or use existing ALU op)
            end
            
            OP_AUIPC: begin
                reg_write  = 1;
                alu_src    = 1;        // Use immediate as ALU operand B  
                mem_to_reg = 2'b00;    // Write ALU result to register
                alu_op     = ALU_ADD;  // ADD (PC + immediate)
            end
            
            default: begin
                mem_to_reg    = 2'b00;
            end
        endcase
    end
endmodule