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
    input wire [DATA_WIDTH-1:0]                 rs1_data,
    input wire [DATA_WIDTH-1:0]                 rs2_data,
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
    output reg [DATA_WIDTH-1:0]                 branch_target_out,
    

    // Forwarding inputs
    input wire [DATA_WIDTH-1:0]                 forwarded_mem_result,   // From MEM stage
    input wire [DATA_WIDTH-1:0]                 forwarded_wb_result,    // From WB  stage
    input wire [1:0]                            forward_rs1,
    input wire [1:0]                            forward_rs2
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
    // Forwarding Logic (Fixed)
    // -------------------------------------------

    assign rs1_data_forwarded = 
        (forward_rs1 == 2'b10) ? forwarded_mem_result : // MEM->EX
        (forward_rs1 == 2'b11) ? forwarded_wb_result :  // WB->EX
        rs1_data;                                       // Regfile

    assign rs2_data_forwarded = 
        (forward_rs2 == 2'b10) ? forwarded_mem_result :
        (forward_rs2 == 2'b11) ? forwarded_wb_result :
        rs2_data;
    
    // -------------------------------------------
    // ALU Input Selection
    // -------------------------------------------
    assign alu_operand_a = rs1_data_forwarded;
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
                3'b000: branch_taken_out = alu_zero;  // BEQ
                3'b001: branch_taken_out = !alu_zero; // BNE
                3'b100: branch_taken_out = alu_lt;    // BLT
                3'b101: branch_taken_out = !alu_lt;   // BGE
                3'b110: branch_taken_out = alu_ltu;   // BLTU
                3'b111: branch_taken_out = !alu_ltu;  // BGEU
            endcase
        end
        else if (jump_in && valid_in) begin
            branch_taken_out = 1'b1;
            if (opcode_in == 7'b1100111) begin // JALR
                branch_target_out = (rs1_data + imm_in) & ~32'h1;
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