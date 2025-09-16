module cpu #(
    parameter RESET_PC           = 32'h0000_0000,
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
) (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n,
    input wire                      debug,

    // Wishbone Master Instruction Interface (IMEM)
    output wire                     wbm_imem_cyc,
    output wire                     wbm_imem_stb,
    output wire                     wbm_imem_we,
    output wire [ADDR_WIDTH-1:0]    wbm_imem_addr,
    output wire [DATA_WIDTH-1:0]    wbm_imem_data_write,
    output wire [3:0]               wbm_imem_sel,
    input wire  [DATA_WIDTH-1:0]    wbm_imem_data_read,
    input wire                      wbm_imem_ack,

    // Wishbone Master Data Interface (DMEM and Peripheral)
    output wire                     wbm_dmem_cyc,
    output wire                     wbm_dmem_stb,
    output wire                     wbm_dmem_we,
    output wire [ADDR_WIDTH-1:0]    wbm_dmem_addr,
    output wire [DATA_WIDTH-1:0]    wbm_dmem_data_write,
    output wire [3:0]               wbm_dmem_sel,
    input wire [DATA_WIDTH-1:0]     wbm_dmem_data_read,
    input wire                      wbm_dmem_ack
);

    // -------------------------------------------
    // Pipeline register signals
    // -------------------------------------------

    // IF to ID
    wire [DATA_WIDTH-1:0] IF_to_ID_instr            ;
    wire [ADDR_WIDTH-1:0] IF_to_ID_pc               ;
    wire                  IF_to_ID_valid            ;

    // ID to EX
    wire [DATA_WIDTH-1:0] ID_to_EX_instr            ;
    wire [ADDR_WIDTH-1:0] ID_to_EX_pc               ;
    wire [4:0]            ID_to_EX_rs1              ;
    wire [4:0]            ID_to_EX_rs2              ;
    wire [4:0]            ID_to_EX_rd               ;
    wire [DATA_WIDTH-1:0] ID_to_EX_imm              ;
    wire [6:0]            ID_to_EX_opcode           ;
    wire [2:0]            ID_to_EX_funct3           ;
    wire [6:0]            ID_to_EX_funct7           ;
    wire                  ID_to_EX_valid            ;
    wire                  ID_to_EX_reg_write        ;
    wire                  ID_to_EX_mem_write        ;
    wire                  ID_to_EX_mem_read         ;
    wire [1:0]            ID_to_EX_mem_to_reg       ;
    wire                  ID_to_EX_branch           ;
    wire                  ID_to_EX_jump             ;
    wire                  ID_to_EX_alu_src          ;
    wire [3:0]            ID_to_EX_alu_op           ;

    // EX to MEM
    wire [DATA_WIDTH-1:0] EX_to_MEM_pc_plus_4       ;
    wire [DATA_WIDTH-1:0] EX_to_MEM_alu_result      ;
    wire [DATA_WIDTH-1:0] EX_to_MEM_mem_data        ;
    wire [4:0]            EX_to_MEM_rd              ;
    wire                  EX_to_MEM_reg_write       ;
    wire                  EX_to_MEM_mem_write       ;
    wire                  EX_to_MEM_mem_read        ;
    wire [1:0]            EX_to_MEM_mem_to_reg      ;
    wire [2:0]            EX_to_MEM_funct3          ;
    wire                  EX_to_MEM_valid           ;
    wire                  EX_to_MEM_branch_taken    ;
    wire [DATA_WIDTH-1:0] EX_to_MEM_branch_target   ;

    // MEM to WB
    wire [DATA_WIDTH-1:0] MEM_to_WB_pc_plus_4       ;
    wire [DATA_WIDTH-1:0] MEM_to_WB_mem_result      ;
    wire [DATA_WIDTH-1:0] MEM_to_WB_alu_result      ;
    wire [4:0]            MEM_to_WB_rd              ;
    wire                  MEM_to_WB_reg_write       ;
    wire [1:0]            MEM_to_WB_mem_to_reg      ;
    wire                  MEM_to_WB_valid           ;

    // Specials 
    // EX to IF
    

    // WB to ID

    // Hazard and forwarding signals
    wire                  hazard_stall              ;
    wire                  hazard_flush              ;
    wire [1:0]            forward_rs1               ;
    wire [1:0]            forward_rs2               ;

    // Register file signals
    wire [DATA_WIDTH-1:0] regfile_rs1_data          ;
    wire [DATA_WIDTH-1:0] regfile_rs2_data          ;

    // Fetch stage signals
    wire                  fetch_stage_flush         ;
    wire [ADDR_WIDTH-1:0] fetch_stage_new_pc        ;

    // Decode stage signals
    wire                  decode_stage_flush        ;

    // -------------------------------------------
    // Pipeline Stages
    // -------------------------------------------

    // Fetch Stage
    assign fetch_stage_flush    = hazard_flush || EX_to_MEM_branch_taken;
    assign fetch_stage_new_pc   = EX_to_MEM_branch_target;

    fetch_stage #(
        .RESET_PC       (RESET_PC),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH)
    ) fetch_stage_inst (
        .clk                                    (clk                        ),
        .rst_n                                  (rst_n                      ),
        .wbm_imem_cyc                           (wbm_imem_cyc               ),
        .wbm_imem_stb                           (wbm_imem_stb               ),
        .wbm_imem_we                            (wbm_imem_we                ),
        .wbm_imem_addr                          (wbm_imem_addr              ),
        .wbm_imem_data_write                    (wbm_imem_data_write        ),
        .wbm_imem_sel                           (wbm_imem_sel               ),
        .wbm_imem_data_read                     (wbm_imem_data_read         ),
        .wbm_imem_ack                           (wbm_imem_ack               ),
        .flush                                  (fetch_stage_flush          ),
        .new_pc                                 (fetch_stage_new_pc         ),
        .stall                                  (hazard_stall               ),
        .instr_out                              (IF_to_ID_instr             ),
        .pc_out                                 (IF_to_ID_pc                ),
        .valid_out                              (IF_to_ID_valid             )
    );

    // Decode Stage
    assign decode_stage_flush    = hazard_flush || EX_to_MEM_branch_taken;

    decode_stage #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) decode_stage_inst (
        .clk                                    (clk                        ),
        .rst_n                                  (rst_n                      ),
        .instr_in                               (IF_to_ID_instr             ),
        .pc_in                                  (IF_to_ID_pc                ),
        .valid_in                               (IF_to_ID_valid             ),
        .flush                                  (decode_stage_flush         ),
        .stall                                  (hazard_stall               ),
        .instr_out                              (ID_to_EX_instr             ),
        .pc_out                                 (ID_to_EX_pc                ),
        .rs1_out                                (ID_to_EX_rs1               ),
        .rs2_out                                (ID_to_EX_rs2               ),
        .rd_out                                 (ID_to_EX_rd                ),
        .imm_out                                (ID_to_EX_imm               ),
        .opcode_out                             (ID_to_EX_opcode            ),
        .funct3_out                             (ID_to_EX_funct3            ),
        .funct7_out                             (ID_to_EX_funct7            ),
        .valid_out                              (ID_to_EX_valid             )
    );

    // Control Unit
    control_unit control_unit_inst (
        .opcode(ID_to_EX_opcode),
        .funct3(ID_to_EX_funct3),
        .funct7(ID_to_EX_funct7),
        .reg_write(ID_to_EX_reg_write),
        .mem_write(ID_to_EX_mem_write),
        .mem_read(ID_to_EX_mem_read),
        .mem_to_reg(ID_to_EX_mem_to_reg),
        .branch(ID_to_EX_branch),
        .alu_src(ID_to_EX_alu_src),
        .alu_op(ID_to_EX_alu_op),
        .jump(ID_to_EX_jump),
        .illegal_instr() // Optional: connect to exception handling
    );

    // Register File
    regfile #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(REGFILE_ADDR_WIDTH)
    ) regfile_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(ID_to_EX_rs1),
        .rs2_addr(ID_to_EX_rs2),
        .rs1_data(regfile_rs1_data),
        .rs2_data(regfile_rs2_data),
        .wr_en(MEM_to_WB_reg_write && MEM_to_WB_valid),
        .wr_addr(MEM_to_WB_rd),
        .wr_data(MEM_to_WB_mem_to_reg == 2'b01 ? MEM_to_WB_mem_result : 
                 MEM_to_WB_mem_to_reg == 2'b10 ? MEM_to_WB_pc_plus_4 : 
                 MEM_to_WB_alu_result)
    );

    // Execute Stage
    execute_stage #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) execute_stage_inst (
        .clk(clk),
        .rst_n(rst_n),
        .instr_in(ID_to_EX_instr),
        .pc_in(ID_to_EX_pc),
        .rd_in(ID_to_EX_rd),
        .rs1_data(regfile_rs1_data),
        .rs2_data(regfile_rs2_data),
        .imm_in(ID_to_EX_imm),
        .opcode_in(ID_to_EX_opcode),
        .funct3_in(ID_to_EX_funct3),
        .funct7_in(ID_to_EX_funct7),
        .valid_in(ID_to_EX_valid),
        .reg_write_in(ID_to_EX_reg_write),
        .mem_write_in(ID_to_EX_mem_write),
        .mem_read_in(ID_to_EX_mem_read),
        .mem_to_reg_in(ID_to_EX_mem_to_reg),
        .branch_in(ID_to_EX_branch),
        .jump_in(ID_to_EX_jump),
        .alu_src_in(ID_to_EX_alu_src),
        .alu_op_in(ID_to_EX_alu_op),
        .alu_result_out(EX_to_MEM_alu_result),
        .mem_data_out(EX_to_MEM_mem_data),
        .rd_out(EX_to_MEM_rd),
        .reg_write_out(EX_to_MEM_reg_write),
        .mem_write_out(EX_to_MEM_mem_write),
        .mem_read_out(EX_to_MEM_mem_read),
        .mem_to_reg_out(EX_to_MEM_mem_to_reg),
        .funct3_out(EX_to_MEM_funct3),
        .valid_out(EX_to_MEM_valid),
        .branch_taken_out(EX_to_MEM_branch_taken),
        .branch_target_out(EX_to_MEM_branch_target),
        .pc_plus_4_out(EX_to_MEM_pc_plus_4),
        .forwarded_mem_result(MEM_to_WB_alu_result),
        .forwarded_wb_result(MEM_to_WB_mem_to_reg == 2'b01 ? MEM_to_WB_mem_result : 
                            MEM_to_WB_mem_to_reg == 2'b10 ? MEM_to_WB_pc_plus_4 : 
                            MEM_to_WB_alu_result),
        .forward_rs1(forward_rs1),
        .forward_rs2(forward_rs2)
    );

    // Memory Stage
    mem_stage #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) mem_stage_inst (
        .clk(clk),
        .rst_n(rst_n),
        .pc_plus_4_in(EX_to_MEM_pc_plus_4),
        .alu_result_in(EX_to_MEM_alu_result),
        .mem_data_in(EX_to_MEM_mem_data),
        .rd_in(EX_to_MEM_rd),
        .reg_write_in(EX_to_MEM_reg_write),
        .mem_write_in(EX_to_MEM_mem_write),
        .mem_read_in(EX_to_MEM_mem_read),
        .mem_to_reg_in(EX_to_MEM_mem_to_reg),
        .funct3_in(EX_to_MEM_funct3),
        .valid_in(EX_to_MEM_valid),
        .wbm_dmem_cyc(wbm_dmem_cyc),
        .wbm_dmem_stb(wbm_dmem_stb),
        .wbm_dmem_we(wbm_dmem_we),
        .wbm_dmem_addr(wbm_dmem_addr),
        .wbm_dmem_data_write(wbm_dmem_data_write),
        .wbm_dmem_sel(wbm_dmem_sel),
        .wbm_dmem_data_read(wbm_dmem_data_read),
        .wbm_dmem_ack(wbm_dmem_ack),
        .pc_plus_4_out(MEM_to_WB_pc_plus_4),
        .mem_result_out(MEM_to_WB_mem_result),
        .alu_result_out(MEM_to_WB_alu_result),
        .rd_out(MEM_to_WB_rd),
        .reg_write_out(MEM_to_WB_reg_write),
        .mem_to_reg_out(MEM_to_WB_mem_to_reg),
        .valid_out(MEM_to_WB_valid),
        .load_misaligned(),
        .store_misaligned()
    );

    // Hazard Unit
    hazard_unit hazard_unit_inst (
        .decode_rs1(ID_to_EX_rs1),
        .decode_rs2(ID_to_EX_rs2),
        .execute_rd(EX_to_MEM_rd),
        .execute_reg_write(EX_to_MEM_reg_write),
        .execute_mem_read(EX_to_MEM_mem_read),
        .memory_rd(MEM_to_WB_rd),
        .memory_reg_write(MEM_to_WB_reg_write),
        .branch_taken(EX_to_MEM_branch_taken),
        .stall(hazard_stall),
        .flush(hazard_flush)
    );

    // Forwarding Unit
    forwarding_unit forwarding_unit_inst (
        .decode_rs1(ID_to_EX_rs1),
        .decode_rs2(ID_to_EX_rs2),
        .execute_rd(EX_to_MEM_rd),
        .execute_reg_write(EX_to_MEM_reg_write),
        .memory_rd(MEM_to_WB_rd),
        .memory_reg_write(MEM_to_WB_reg_write),
        .writeback_rd(MEM_to_WB_rd),
        .writeback_reg_write(MEM_to_WB_reg_write),
        .forward_rs1(forward_rs1),
        .forward_rs2(forward_rs2)
    );

endmodule