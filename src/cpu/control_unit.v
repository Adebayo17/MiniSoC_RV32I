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
    output reg        jump,
    output reg        illegal_instr
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
        illegal_instr   = 0;

        case (opcode)
            OP_R: begin // R-type
                reg_write = 1;
                mem_to_reg = 2'b00;
                alu_op    = {funct7[5], funct3};
            end
            
            OP_IMM: begin // I-type
                reg_write = 1;
                alu_src   = 1;
                mem_to_reg = 2'b00;
                alu_op    = {funct7[5] & (funct3 == 3'b101), funct3};
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
                illegal_instr = 1;
            end
        endcase
    end
endmodule