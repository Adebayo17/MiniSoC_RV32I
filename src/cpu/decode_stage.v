module decode_stage #(
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
)(
    // Clock and reset
    input wire                              clk,
    input wire                              rst_n,
    
    // Pipeline control
    input wire                              flush,
    input wire                              stall,
    
    // From Fetch Stage
    input wire [DATA_WIDTH-1:0]             instr_in,
    input wire [ADDR_WIDTH-1:0]             pc_in,
    input wire                              valid_in,
    
    // From Writeback Stage (for register writeback)
    input wire                              wb_reg_write,
    input wire [REGFILE_ADDR_WIDTH-1:0]     wb_rd_addr,
    input wire [DATA_WIDTH-1:0]             wb_data,
    
    // Pipeline outputs to Execute Stage
    output reg [ADDR_WIDTH-1:0]             pc_out,
    output reg [DATA_WIDTH-1:0]             instr_out,
    output reg [REGFILE_ADDR_WIDTH-1:0]     rs1_addr_out,
    output reg [REGFILE_ADDR_WIDTH-1:0]     rs2_addr_out,
    output reg [REGFILE_ADDR_WIDTH-1:0]     rd_addr_out,
    output reg [DATA_WIDTH-1:0]             rs1_data_out,
    output reg [DATA_WIDTH-1:0]             rs2_data_out,
    output reg [DATA_WIDTH-1:0]             imm_out,
    output reg [6:0]                        opcode_out,
    output reg [2:0]                        funct3_out,
    output reg [6:0]                        funct7_out,
    
    // Control signals to Execute Stage
    output reg                              reg_write_out,
    output reg                              mem_write_out,
    output reg                              mem_read_out,
    output reg [1:0]                        mem_to_reg_out,
    output reg                              branch_out,
    output reg                              alu_src_out,
    output reg [3:0]                        alu_op_out,
    output reg                              jump_out,
    output reg                              valid_out
);

    // -------------------------------------------
    // Internal signals
    // -------------------------------------------
    reg  [REGFILE_ADDR_WIDTH-1:0] rs1_addr;
    reg  [REGFILE_ADDR_WIDTH-1:0] rs2_addr;
    reg  [REGFILE_ADDR_WIDTH-1:0] rd_addr;
    wire [DATA_WIDTH-1:0] rs1_data;
    wire [DATA_WIDTH-1:0] rs2_data;
    reg  [DATA_WIDTH-1:0] imm;
    reg  [6:0]            opcode;
    reg  [2:0]            funct3;
    reg  [6:0]            funct7;
    
    wire                  reg_write;
    wire                  mem_write;
    wire                  mem_read;
    wire [1:0]            mem_to_reg;
    wire                  branch;
    wire                  alu_src;
    wire [3:0]            alu_op;
    wire                  jump;

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

    // -------------------------------------------
    // Instruction Decode Logic (Combinational)
    // -------------------------------------------
    always @(*) begin
        // Extract instruction fields
        opcode      = instr_in[6:0]  ;
        funct3      = instr_in[14:12];
        rs1_addr    = instr_in[19:15];
        rs2_addr    = instr_in[24:20];
        rd_addr     = instr_in[11:7] ;
        funct7      = instr_in[31:25];
        
        // Immediate generation
        case (opcode)
            OP_IMM:     imm = {{20{instr_in[31]}}, instr_in[31:20]};
            OP_LOAD:    imm = {{20{instr_in[31]}}, instr_in[31:20]};
            OP_JALR:    imm = {{20{instr_in[31]}}, instr_in[31:20]};
            OP_STORE:   imm = {{20{instr_in[31]}}, instr_in[31:25], instr_in[11:7]};
            OP_BRANCH:  imm = {{19{instr_in[31]}}, instr_in[31], instr_in[7], instr_in[30:25], instr_in[11:8], 1'b0};
            OP_JAL:     imm = {{12{instr_in[31]}}, instr_in[19:12], instr_in[20], instr_in[30:21], 1'b0};
            default:    imm = 32'b0;
        endcase
    end

    // -------------------------------------------
    // Control Unit Instantiation
    // -------------------------------------------
    control_unit ctrl_unit (
        .opcode         (opcode         ),
        .funct3         (funct3         ),
        .funct7         (funct7         ),
        .reg_write      (reg_write      ),
        .mem_write      (mem_write      ),
        .mem_read       (mem_read       ),
        .mem_to_reg     (mem_to_reg     ),
        .branch         (branch         ),
        .alu_src        (alu_src        ),
        .alu_op         (alu_op         ),
        .jump           (jump           )
    );

    // -------------------------------------------
    // Register File Instantiation
    // -------------------------------------------
    regfile #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (REGFILE_ADDR_WIDTH)
    ) reg_file (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .wr_en(wb_reg_write),
        .wr_addr(wb_rd_addr),
        .wr_data(wb_data)
    );

    // -------------------------------------------
    // Pipeline Register Update (Sequential)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all pipeline registers
            pc_out          <= 0;
            instr_out       <= 0;
            rs1_addr_out    <= 0;
            rs2_addr_out    <= 0;
            rd_addr_out     <= 0;
            rs1_data_out    <= 0;
            rs2_data_out    <= 0;
            imm_out         <= 0;
            opcode_out      <= 0;
            funct3_out      <= 0;
            funct7_out      <= 0;
            reg_write_out   <= 0;
            mem_write_out   <= 0;
            mem_read_out    <= 0;
            mem_to_reg_out  <= 2'b00;
            branch_out      <= 0;
            alu_src_out     <= 0;
            alu_op_out      <= 0;
            jump_out        <= 0;
            valid_out       <= 0;
        end else if (flush) begin
            // Flush pipeline (insert bubble)
            valid_out       <= 0;
            reg_write_out   <= 0;
            mem_write_out   <= 0;
            mem_read_out    <= 0;
            branch_out      <= 0;
            jump_out        <= 0;
        end else if (!stall) begin
            // Normal pipeline operation
            valid_out <= valid_in;
            
            if (valid_in) begin
                // Pass through instruction and control signals
                pc_out        <= pc_in;
                instr_out     <= instr_in;
                rs1_addr_out  <= rs1_addr;
                rs2_addr_out  <= rs2_addr;
                rd_addr_out   <= rd_addr;
                rs1_data_out  <= rs1_data;
                rs2_data_out  <= rs2_data;
                imm_out       <= imm;
                opcode_out    <= opcode;
                funct3_out    <= funct3;
                funct7_out    <= funct7;
                
                // Control signals
                reg_write_out  <= reg_write;
                mem_write_out  <= mem_write;
                mem_read_out   <= mem_read;
                mem_to_reg_out <= mem_to_reg;
                branch_out     <= branch;
                alu_src_out    <= alu_src;
                alu_op_out     <= alu_op;
                jump_out       <= jump;
            end else begin
                // Insert NOP when invalid
                valid_out     <= 0;
                instr_out     <= 32'h00000013; // NOP instruction
                reg_write_out <= 0;
                mem_write_out <= 0;
                mem_read_out  <= 0;
                branch_out    <= 0;
                jump_out      <= 0;
            end
        end
        // When stalled, keep current values (implicit)
    end

endmodule
