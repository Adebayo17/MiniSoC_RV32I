module decode_stage #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire                  clk,
    input wire                  rst_n,
    input wire [DATA_WIDTH-1:0] instr_in,
    input wire [ADDR_WIDTH-1:0] pc_in,
    input wire                  valid_in,

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
    output reg                  valid_out
);

    localparam R_TYPE_OPCODE = 7'b0110011; 
    localparam I_TYPE_OPCODE = 7'b0010011; 
    localparam LOAD_OPCODE   = 7'b0000011; 
    localparam STORE_OPCODE  = 7'b0100011; 
    localparam BRANCH_OPCODE = 7'b1100011; 
    localparam JAL_OPCODE    = 7'b1101111; 
    localparam JALR_OPCODE   = 7'b1100111; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_out   <= 0;
            pc_out      <= 0;
            rs1_out     <= 0;
            rs2_out     <= 0;
            rd_out      <= 0;
            imm_out     <= 0;
            opcode_out  <= 0;
            funct3_out  <= 0;
            funct7_out  <= 0;
            valid_out   <= 0;
        end else begin
            if (valid_in) begin
                valid_out <= valid_in;
                instr_out <= instr_in;
                pc_out    <= pc_in;

                opcode_out  <= instr_in[6:0];
                case (instr_in[6:0])
                    R_TYPE_OPCODE: begin
                        rd_out      <= instr_in[11:7];
                        funct3_out  <= instr_in[14:12];
                        rs1_out     <= instr_in[19:15];
                        rs2_out     <= instr_in[24:20];
                        funct7_out  <= instr_in[31:25];
                        imm_out     <= 32'b0;
                    end

                    I_TYPE_OPCODE: begin
                        rd_out      <= instr_in[11:7];
                        funct3_out  <= instr_in[14:12];
                        rs1_out     <= instr_in[19:15];
                        rs2_out     <= 5'b0;
                        funct7_out  <= 7'b0;
                        imm_out     <= {{20{instr_in[31]}}, instr_in[31:20]};
                    end

                    LOAD_OPCODE:   begin
                        rd_out      <= 5'b0;
                        funct3_out  <= instr_in[14:12];
                        rs1_out     <= instr_in[19:15];
                        rs2_out     <= 5'b0;
                        funct7_out  <= 7'b0;
                        imm_out     <= {{20{instr_in[31]}}, instr_in[31:20]};
                    end  

                    STORE_OPCODE:  begin
                        rd_out      <= 5'b0;
                        funct3_out  <= instr_in[14:12];
                        rs1_out     <= instr_in[19:15];
                        rs2_out     <= instr_in[24:20];
                        funct7_out  <= 7'b0;
                        imm_out     <= {{20{instr_in[31]}}, instr_in[31:25], instr_in[11:7]};
                    end

                    BRANCH_OPCODE: begin
                        rd_out      <= 5'b0;
                        funct3_out  <= instr_in[14:12];
                        rs1_out     <= instr_in[19:15];
                        rs2_out     <= instr_in[24:20];
                        funct7_out  <= 7'b0;
                        imm_out     <= {{19{instr_in[31]}}, instr_in[31], instr_in[7], instr_in[30:25], instr_in[11:8], 1'b0};
                    end

                    JAL_OPCODE:    begin
                        rd_out      <= instr_in[11:7];
                        funct3_out  <= 3'b0;
                        rs1_out     <= instr_in[19:15];
                        rs2_out     <= 5'b0;
                        funct7_out  <= 7'b0;
                        imm_out     <= {{12{instr_in[31]}}, instr_in[19:12], instr_in[20], instr_in[30:21], 1'b0};
                    end

                    JALR_OPCODE:   begin
                        rd_out      <= 5'b0;
                        funct3_out  <= instr_in[14:12];
                        rs1_out     <= instr_in[19:15];
                        rs2_out     <= 5'b0;
                        funct7_out  <= 7'b0;
                        imm_out <= {{20{instr_in[31]}}, instr_in[31:20]};
                    end
                    
                    default:       begin
                        rd_out      <= 5'b0;
                        funct3_out  <= 3'b0;
                        rs1_out     <= 5'b0;
                        rs2_out     <= 5'b0;
                        funct7_out  <= 7'b0;
                        imm_out     <= 32'b0;
                    end
                endcase
            end else begin
                valid_out   <= 0;
                instr_out   <= 0;
                pc_out      <= 0;
                opcode_out  <= 0;
                rd_out      <= 0;
                funct3_out  <= 0;
                rs1_out     <= 0;
                rs2_out     <= 0;
                funct7_out  <= 0;
                imm_out     <= 0;
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
