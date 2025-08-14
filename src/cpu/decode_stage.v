module decode_stage #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset
    input wire                  clk,
    input wire                  rst_n,

    // Pipeline Input
    // - From Fetch Stage
    input wire [DATA_WIDTH-1:0] instr_in,
    input wire [ADDR_WIDTH-1:0] pc_in,
    input wire                  valid_in,
    // - From execute stage
    input wire                  flush,
    // - From hazard unit
    input wire                  stall,

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
    localparam OP_SYSTEM  = 7'b1110011; // Not used

    // -------------------------------------------
    // Main Process
    // -------------------------------------------
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
        end else if (flush) begin
            valid_out       <= 0;
        end else if (!stall) begin
            // Normal  operation
            valid_out <= valid_in;
            instr_out <= valid_in ? instr_in : 32'h00000013; // NOP when invalid
            pc_out    <= pc_in;

            if (valid_in) begin
                // Common fields
                opcode_out  <= instr_in[6:0];
                funct3_out <= instr_in[14:12];
                rs1_out <= instr_in[19:15];
                rs2_out <= instr_in[24:20];
                rd_out <= instr_in[11:7];
                funct7_out <= instr_in[31:25];

                case (instr_in[6:0])
                    OP_IMM:     imm_out <= {{20{instr_in[31]}}, instr_in[31:20]};
                    OP_LOAD:    imm_out <= {{20{instr_in[31]}}, instr_in[31:20]};
                    OP_JALR:    imm_out <= {{20{instr_in[31]}}, instr_in[31:20]};
                    OP_STORE:   imm_out <= {{20{instr_in[31]}}, instr_in[31:25], instr_in[11:7]};
                    OP_BRANCH:  imm_out <= {{19{instr_in[31]}}, instr_in[31], instr_in[7], instr_in[30:25], instr_in[11:8], 1'b0};
                    OP_JAL:     imm_out <= {{12{instr_in[31]}}, instr_in[19:12], instr_in[20], instr_in[30:21], 1'b0};
                    OP_R:       imm_out <= 32'b0;
                    default:    imm_out <= 32'b0;
                endcase
            end else begin
                valid_out     <= 0;
            end
        end
    end 
endmodule
