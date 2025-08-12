module decode_stage #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset
    input wire                  clk,
    input wire                  rst_n,

    // Pipeline Input
    input wire [DATA_WIDTH-1:0] instr_in,
    input wire [ADDR_WIDTH-1:0] pc_in,
    input wire                  valid_in,
    input wire                  flush,          // From execute stage
    input wire                  stall,          // From hazard unit

    // Pipeline outputs
    output reg [DATA_WIDTH-1:0] instr_out,
    output reg [ADDR_WIDTH-1:0] pc_out,
    output reg [4:0]            rs1_out,
    output reg [4:0]            rs2_out,
    output reg [4:0]            rd_out,
    output reg [DATA_WIDTH-1:0] imm_out,
    output reg [6:0]            opcode_out,
    output reg [2:0]            funct3_out,
    output reg [6:0]            funct7_out,
    output reg                  reg_write_out,  // Register write enable
    output reg                  mem_write_out,  // Memory write enable
    output reg                  mem_read_out,   // Memory read enable
    output reg                  branch_out,     // Branch instruction
    output reg                  alu_src_out,    // 0=rs2, 1=immediate
    output reg [3:0]            alu_op_out,     // ALU operation code
    output reg                  jump_out,       // Jump instruction
    output reg                  illegal_instr,  // Invalid instruction
    output reg                  valid_out
);

    localparam R_TYPE_OPCODE = 7'b0110011; 
    localparam I_TYPE_OPCODE = 7'b0010011; 
    localparam LOAD_OPCODE   = 7'b0000011; 
    localparam STORE_OPCODE  = 7'b0100011; 
    localparam BRANCH_OPCODE = 7'b1100011; 
    localparam JAL_OPCODE    = 7'b1101111; 
    localparam JALR_OPCODE   = 7'b1100111; 

    // Instruction opcodes (RV32I)
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_JALR    = 7'b1100111;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_OP_IMM  = 7'b0010011;
    localparam OP_OP      = 7'b0110011;
    localparam OP_SYSTEM  = 7'b1110011;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_out       <= 0;
            pc_out          <= 0;
            rs1_out         <= 0;
            rs2_out         <= 0;
            rd_out          <= 0;
            imm_out         <= 0;
            opcode_out      <= 0;
            funct3_out      <= 0;
            funct7_out      <= 0;
            valid_out       <= 0;
            reg_write_out   <= 0;
            mem_write_out   <= 0;
            mem_read_out    <= 0; 
            branch_out      <= 0;   
            alu_src_out     <= 0;  
            alu_op_out      <= 0;
            jump_out        <= 0;     
            illegal_instr   <= 0;
        end else if (flush) begin
            valid_out       <= 0;
            reg_write_out   <= 0;
            mem_write_out   <= 0;
            illegal_instr   <= 0;
        end else if (!stall) begin
            // Normal  operation
            valid_out <= valid_in;
            instr_out <= valid_in ? instr_in : 32'h00000013; // NOP when invalid
            pc_out    <= pc_in;

            if (valid_in) begin
                // Default values
                reg_write_out <= 0;
                mem_write_out <= 0;
                mem_read_out <= 0;
                branch_out <= 0;
                jump_out <= 0;
                illegal_instr <= 0;
                alu_src_out <= 0;
                alu_op_out <= 4'b0000; // ADD

                // Common fields
                opcode_out  <= instr_in[6:0];
                funct3_out <= instr_in[14:12];
                rs1_out <= instr_in[19:15];
                rs2_out <= instr_in[24:20];
                rd_out <= instr_in[11:7];
                funct7_out <= instr_in[31:25];

                case (instr_in[6:0])
                    R_TYPE_OPCODE: begin
                        imm_out     <= 32'b0;
                        reg_write_out <= 1;
                        alu_op_out    <= {instr_in[30], funct3_out};
                    end

                    I_TYPE_OPCODE: begin
                        imm_out     <= {{20{instr_in[31]}}, instr_in[31:20]};
                        reg_write_out <= 1;
                        alu_src_out <= 1; // Use immediate
                        alu_op_out <= {instr_in[30] & (funct3_out == 3'b101), funct3_out}; // SRAI vs SRLI
                    end

                    LOAD_OPCODE:   begin
                        imm_out     <= {{20{instr_in[31]}}, instr_in[31:20]};
                        reg_write_out <= 1;
                        mem_read_out  <= 1;
                        alu_src_out   <= 1;       // Use immediate
                        alu_op_out    <= 4'b0000; // ADD for address calculation
                    end  

                    STORE_OPCODE:  begin
                        imm_out     <= {{20{instr_in[31]}}, instr_in[31:25], instr_in[11:7]};
                        mem_write_out <= 1;
                        alu_src_out   <= 1;       // Use immediate
                        alu_op_out    <= 4'b0000; // ADD for address calculation
                    end

                    BRANCH_OPCODE: begin
                        imm_out     <= {{19{instr_in[31]}}, instr_in[31], instr_in[7], instr_in[30:25], instr_in[11:8], 1'b0};
                        branch_out  <= 1;
                        alu_op_out  <= {1'b0, funct3_out}; // Compare operations
                    end

                    JAL_OPCODE:    begin
                        imm_out     <= {{12{instr_in[31]}}, instr_in[19:12], instr_in[20], instr_in[30:21], 1'b0};
                        jump_out      <= 1;
                        reg_write_out <= 1;
                        alu_op_out    <= 4'b0000; // ADD for PC+4
                    end

                    JALR_OPCODE:   begin
                        imm_out <= {{20{instr_in[31]}}, instr_in[31:20]};
                        jump_out      <= 1;
                        reg_write_out <= 1;
                        alu_op_out    <= 4'b0000; // ADD for PC+4
                    end
                    
                    default:       begin
                        imm_out     <= 32'b0;
                        illegal_instr <= 1;
                    end
                endcase
            end else begin
                // Invalid instruction (bubble)
                valid_out     <= 0;
                imm_out       <= 0;
                reg_write_out <= 0;
                mem_write_out <= 0;
            end
        end
    end 
endmodule



                // opcode_out  <= instr_in[6:0];
                // rd_out      <= instr_in[11:7];
                // funct3_out  <= instr_in[14:12];
                // rs1_out     <= instr_in[19:15];
                // rs2_out     <= instr_in[24:20];
                // funct7_out  <= instr_in[31:25];

                // case (instr_in[6:0])
                //     I_TYPE_OPCODE:  imm_out <= {{20{instr_in[31]}}, instr_in[31:20]};
                //     LOAD_OPCODE:    imm_out <= {{20{instr_in[31]}}, instr_in[31:20]};
                //     JALR_OPCODE:    imm_out <= {{20{instr_in[31]}}, instr_in[31:20]};
                //     STORE_OPCODE:   imm_out <= {{20{instr_in[31]}}, instr_in[31:25], instr_in[11:7]};
                //     BRANCH_OPCODE:  imm_out <= {{19{instr_in[31]}}, instr_in[31], instr_in[7], instr_in[30:25], instr_in[11:8], 1'b0};
                //     JAL_OPCODE:     imm_out <= {{12{instr_in[31]}}, instr_in[19:12], instr_in[20], instr_in[30:21], 1'b0};
                //     R_TYPE_OPCODE:  imm_out <= 32'b0;
                //     default:        imm_out <= 32'b0;
                // endcase
