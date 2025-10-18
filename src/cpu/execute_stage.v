module execute_stage #(
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
) (
    // Clock and reset
    input wire                                  clk,
    input wire                                  rst_n,

    // Pipeline control
    input wire                                  flush,
    input wire                                  stall,

    // Pipeline inputs from Decode Stage
    input wire [DATA_WIDTH-1:0]                 instr_in,
    input wire [ADDR_WIDTH-1:0]                 pc_in,
    input wire [REGFILE_ADDR_WIDTH-1:0]         rd_in,
    input wire [DATA_WIDTH-1:0]                 rs1_data_in,
    input wire [DATA_WIDTH-1:0]                 rs2_data_in,
    input wire [DATA_WIDTH-1:0]                 imm_in,
    input wire [6:0]                            opcode_in,
    input wire [2:0]                            funct3_in,
    input wire [6:0]                            funct7_in,
    input wire                                  valid_in,

    // Control signals from Decode Stage (Control Unit)
    input wire                                  reg_write_in,
    input wire                                  mem_write_in,
    input wire                                  mem_read_in,
    input wire [1:0]                            mem_to_reg_in,
    input wire                                  branch_in,
    input wire                                  jump_in,
    input wire                                  alu_src_in,
    input wire [3:0]                            alu_op_in,

    // Forwarding inputs
    input wire [DATA_WIDTH-1:0]                 mem_alu_result,    // From MEM stage (alu_result_out)
    input wire [DATA_WIDTH-1:0]                 wb_result,         // From WB stage (result_out)
    input wire [1:0]                            forward_rs1,
    input wire [1:0]                            forward_rs2,

    // Pipeline outputs to Memory Stage
    output reg [ADDR_WIDTH-1:0]                 pc_plus_4_out,
    output reg [DATA_WIDTH-1:0]                 alu_result_out,
    output reg [DATA_WIDTH-1:0]                 mem_data_out,
    output reg [REGFILE_ADDR_WIDTH-1:0]         rd_out,
    output reg                                  reg_write_out,
    output reg                                  mem_write_out,
    output reg                                  mem_read_out,
    output reg [1:0]                            mem_to_reg_out,
    output reg [2:0]                            funct3_out,
    output reg                                  valid_out,

    // Branch/jump signals
    output reg                                  branch_taken_out, // for branch and jump instructions
    output reg [DATA_WIDTH-1:0]                 branch_target_out
);

    // -------------------------------------------
    // Internal Signals
    // -------------------------------------------
    // ALU signals
    wire [DATA_WIDTH-1:0] alu_result;
    wire                  alu_zero;
    wire                  alu_lt;
    wire                  alu_ltu;
    wire [DATA_WIDTH-1:0] alu_operand_a;
    wire [DATA_WIDTH-1:0] alu_operand_b;

    // Forwarded operand selection
    wire [DATA_WIDTH-1:0] rs1_data_forwarded;
    wire [DATA_WIDTH-1:0] rs2_data_forwarded;


    // -------------------------------------------
    // BRANCH Code
    // -------------------------------------------
    localparam [2:0] BR_BEQ  = 3'b000;
    localparam [2:0] BR_BNE  = 3'b001;
    localparam [2:0] BR_BLT  = 3'b100;
    localparam [2:0] BR_BGE  = 3'b101;
    localparam [2:0] BR_BLTU = 3'b110;
    localparam [2:0] BR_BGEU = 3'b111;

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
    // Forwarding Logic (Fixed)
    // -------------------------------------------

    // Forwarding selection codes
    localparam [1:0] FROM_REG  = 2'b00;
    localparam [1:0] FROM_EX   = 2'b01;
    localparam [1:0] FROM_MEM  = 2'b10;
    localparam [1:0] FROM_WB   = 2'b11;

    assign rs1_data_forwarded = 
        (forward_rs1 == FROM_MEM) ? mem_alu_result :    // FROM_MEM: Forward from memory stage
        (forward_rs1 == FROM_WB) ? wb_result :          // FROM_WB: Forward from writeback stage
        rs1_data_in;                                    // FROM_REG: Use register file

    assign rs2_data_forwarded = 
        (forward_rs2 == FROM_MEM) ? mem_alu_result :    // FROM_MEM
        (forward_rs2 == FROM_WB) ? wb_result :          // FROM_WB
        rs2_data_in;                                    // FROM_REG
    
    // -------------------------------------------
    // ALU Input Selection
    // -------------------------------------------
    assign alu_operand_a = (opcode_in == OP_AUIPC) ? pc_in : rs1_data_forwarded;
    assign alu_operand_b = alu_src_in ? imm_in : rs2_data_forwarded;
    

    // -------------------------------------------
    // ALU Instance
    // -------------------------------------------
    alu alu_u (
        .alu_op     (alu_op_in      ),
        .operand_a  (alu_operand_a  ),
        .operand_b  (alu_operand_b  ),
        .alu_result (alu_result     ),
        .alu_zero   (alu_zero       ),
        .alu_lt     (alu_lt         ),
        .alu_ltu    (alu_ltu        )
    );

    // -------------------------------------------
    // Branch/Jump Logic
    // -------------------------------------------
    always @(*) begin
        branch_taken_out  = 1'b0;
        branch_target_out = pc_in + imm_in;
        
        if (branch_in && valid_in) begin
            case (funct3_in)
                BR_BEQ:  branch_taken_out = alu_zero;  // BEQ: rs1 == rs2
                BR_BNE:  branch_taken_out = !alu_zero; // BNE: rs1 != rs2
                BR_BLT:  branch_taken_out = alu_lt;    // BLT: rs1 < rs2 (signed)
                BR_BGE:  branch_taken_out = !alu_lt;   // BGE: rs1 >= rs2 (signed)
                BR_BLTU: branch_taken_out = alu_ltu;   // BLTU: rs1 < rs2 (unsigned)
                BR_BGEU: branch_taken_out = !alu_ltu;  // BGEU: rs1 >= rs2 (unsigned)
                default: branch_taken_out = 1'b0;      // Invalid branch type
            endcase
        end
        else if (jump_in && valid_in) begin
            branch_taken_out = 1'b1;
            if (opcode_in == OP_JALR) begin // JALR
                branch_target_out = (rs1_data_forwarded + imm_in) & ~32'h1;
            end
        end
    end

    // -------------------------------------------
    // Pipeline Registers Update
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all outputs
            alu_result_out      <= 0;
            mem_data_out        <= 0;
            rd_out              <= 0;
            reg_write_out       <= 0;
            mem_write_out       <= 0;
            mem_read_out        <= 0;
            mem_to_reg_out      <= 2'b00;
            funct3_out          <= 0;
            valid_out           <= 0;
            pc_plus_4_out       <= 0;
            branch_taken_out    <= 0;
            branch_target_out   <= 0;
        end else if (flush) begin
            // Flush pipeline (insert bubble)
            valid_out           <= 0;
            reg_write_out       <= 0;
            mem_write_out       <= 0;
            mem_read_out        <= 0;
            branch_taken_out    <= 0;
        end else if (!stall) begin
            // Normal pipeline operation
            alu_result_out      <= alu_result;
            mem_data_out        <= rs2_data_forwarded;  // Use forwarded data for stores
            rd_out              <= rd_in;
            reg_write_out       <= reg_write_in && valid_in;
            mem_write_out       <= mem_write_in && valid_in;
            mem_read_out        <= mem_read_in && valid_in;
            mem_to_reg_out      <= mem_to_reg_in;
            funct3_out          <= funct3_in;
            valid_out           <= valid_in;
            pc_plus_4_out       <= pc_in + 4;
            
            // Branch/jump signals (registered to avoid combinational paths)
            branch_taken_out    <= (branch_in || jump_in) && valid_in ? branch_taken_out : 1'b0;
            branch_target_out   <= branch_target_out;
        end
        // When stalled, registers maintain their values
    end
    

endmodule