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

    // IF (Instruction Fetch) to ID (Instruction Decode) 
    wire [DATA_WIDTH-1:0]           IF_to_ID_instr              ;
    wire [ADDR_WIDTH-1:0]           IF_to_ID_pc                 ;
    wire                            IF_to_ID_valid              ;

    // ID to EX (Execute)
    wire [ADDR_WIDTH-1:0]           ID_to_EX_pc                 ;
    wire [DATA_WIDTH-1:0]           ID_to_EX_instr              ;
    wire [REGFILE_ADDR_WIDTH-1:0]   ID_to_EX_rs1_addr           ;
    wire [REGFILE_ADDR_WIDTH-1:0]   ID_to_EX_rs2_addr           ;
    wire [REGFILE_ADDR_WIDTH-1:0]   ID_to_EX_rd_addr            ;
    wire [DATA_WIDTH-1:0]           ID_to_EX_rs1_data           ;
    wire [DATA_WIDTH-1:0]           ID_to_EX_rs2_data           ;
    wire [DATA_WIDTH-1:0]           ID_to_EX_imm                ;
    wire [6:0]                      ID_to_EX_opcode             ;
    wire [2:0]                      ID_to_EX_funct3             ;
    wire [6:0]                      ID_to_EX_funct7             ;
    wire                            ID_to_EX_reg_write          ;
    wire                            ID_to_EX_mem_write          ;
    wire                            ID_to_EX_mem_read           ;
    wire [1:0]                      ID_to_EX_mem_to_reg         ;
    wire                            ID_to_EX_branch             ;
    wire                            ID_to_EX_alu_src            ;
    wire [3:0]                      ID_to_EX_alu_op             ;
    wire                            ID_to_EX_jump               ;
    wire                            ID_to_EX_valid              ;

    // EX to MEM (Memory)
    wire [ADDR_WIDTH-1:0]           EX_to_MEM_pc_plus_4         ;
    wire [DATA_WIDTH-1:0]           EX_to_MEM_alu_result        ;
    wire [DATA_WIDTH-1:0]           EX_to_MEM_mem_data          ;
    wire [REGFILE_ADDR_WIDTH-1:0]   EX_to_MEM_rd                ;
    wire                            EX_to_MEM_reg_write         ;
    wire                            EX_to_MEM_mem_write         ;
    wire                            EX_to_MEM_mem_read          ;
    wire [1:0]                      EX_to_MEM_mem_to_reg        ;
    wire [2:0]                      EX_to_MEM_funct3            ;
    wire                            EX_to_MEM_valid             ;

    // MEM to WB
    wire [ADDR_WIDTH-1:0]           MEM_to_WB_pc_plus_4         ;
    wire [DATA_WIDTH-1:0]           MEM_to_WB_mem_result        ;
    wire [DATA_WIDTH-1:0]           MEM_to_WB_alu_result        ;
    wire [REGFILE_ADDR_WIDTH-1:0]   MEM_to_WB_rd                ;
    wire                            MEM_to_WB_reg_write         ;
    wire [1:0]                      MEM_to_WB_mem_to_reg        ;
    wire                            MEM_to_WB_valid             ;

    // Special Pipeline
    // EX to IF
    wire [ADDR_WIDTH-1:0]           EX_to_IF_new_pc             ;

    // WB to ID
    wire                            WB_to_ID_reg_write          ;
    wire [REGFILE_ADDR_WIDTH-1:0]   WB_to_ID_rd_addr            ;
    wire [DATA_WIDTH-1:0]           WB_to_ID_wr_dara            ;

    // MEM to EX
    wire [DATA_WIDTH-1:0]           MEM_to_EX_alu_result        ;
    wire                            MEM_load_misaligned         ;
    wire                            MEM_store_misaligned        ;

    // WB to EX
    wire [DATA_WIDTH-1:0]           WB_to_EX_result             ;
    

    // Hazard Flush and Stall
    wire                            hazard_unit_branch_taken    ;
    wire                            hazard_unit_stall_fetch     ;
    wire                            hazard_unit_stall_decode    ; 
    wire                            hazard_unit_stall_execute   ;
    wire                            hazard_unit_flush_fetch     ;
    wire                            hazard_unit_flush_decode    ; 
    wire                            hazard_unit_flush_execute   ;

    // Forwarding 
    wire [1:0]                      forward_unit_forward_rs1    ;
    wire [1:0]                      forward_unit_forward_rs2    ;
    wire [REGFILE_ADDR_WIDTH-1:0]   forward_unit_wb_rd          ;
    wire                            forward_unit_wb_reg_write   ;
    wire                            forward_unit_wb_valid       ;

    
    // -------------------------------------------
    // Pipeline Stages
    // -------------------------------------------

    // Fetch Stage
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
        .flush                                  (hazard_unit_flush_fetch    ),
        .new_pc                                 (EX_to_IF_new_pc            ),
        .stall                                  (hazard_unit_stall_fetch    ),
        .instr_out                              (IF_to_ID_instr             ),
        .pc_out                                 (IF_to_ID_pc                ),
        .valid_out                              (IF_to_ID_valid             )
    );

   

    // Decode Stage
    decode_stage #(
        .ADDR_WIDTH         (ADDR_WIDTH         ),
        .DATA_WIDTH         (DATA_WIDTH         ),
        .REGFILE_ADDR_WIDTH (REGFILE_ADDR_WIDTH )
    ) decode_stage_inst (
        .clk                                    (clk                        ),
        .rst_n                                  (rst_n                      ),
        .flush                                  (hazard_unit_flush_decode   ),
        .stall                                  (hazard_unit_stall_decode   ),
        .instr_in                               (IF_to_ID_instr             ),
        .pc_in                                  (IF_to_ID_pc                ),
        .valid_in                               (IF_to_ID_valid             ),
        .wb_reg_write                           (WB_to_ID_reg_write         ),
        .wb_rd_addr                             (WB_to_ID_rd_addr           ),
        .wb_data                                (WB_to_ID_wr_dara           ),
        .pc_out                                 (ID_to_EX_pc                ),
        .instr_out                              (ID_to_EX_instr             ),
        .rs1_addr_out                           (ID_to_EX_rs1_addr          ),
        .rs2_addr_out                           (ID_to_EX_rs2_addr          ),
        .rd_addr_out                            (ID_to_EX_rd_addr           ),
        .rs1_data_out                           (ID_to_EX_rs1_data          ),
        .rs2_data_out                           (ID_to_EX_rs2_data          ),
        .imm_out                                (ID_to_EX_imm               ),
        .opcode_out                             (ID_to_EX_opcode            ),
        .funct3_out                             (ID_to_EX_funct3            ),
        .funct7_out                             (ID_to_EX_funct7            ),
        .reg_write_out                          (ID_to_EX_reg_write         ),
        .mem_write_out                          (ID_to_EX_mem_write         ),
        .mem_read_out                           (ID_to_EX_mem_read          ),
        .mem_to_reg_out                         (ID_to_EX_mem_to_reg        ),
        .branch_out                             (ID_to_EX_branch            ),
        .alu_src_out                            (ID_to_EX_alu_src           ),
        .alu_op_out                             (ID_to_EX_alu_op            ),
        .jump_out                               (ID_to_EX_jump              ),
        .valid_out                              (ID_to_EX_valid             )
    );



    // Execute Stage
    execute_stage #(
        .ADDR_WIDTH         (ADDR_WIDTH         ),
        .DATA_WIDTH         (DATA_WIDTH         ),
        .REGFILE_ADDR_WIDTH (REGFILE_ADDR_WIDTH )
    ) execute_stage_inst (
        .clk                                    (clk                        ),
        .rst_n                                  (rst_n                      ),
        .flush                                  (hazard_unit_flush_execute  ),
        .stall                                  (hazard_unit_stall_execute  ),
        .instr_in                               (ID_to_EX_instr             ),
        .pc_in                                  (ID_to_EX_pc                ),
        .rd_in                                  (ID_to_EX_rd_addr           ),
        .rs1_data_in                            (ID_to_EX_rs1_data          ),
        .rs2_data_in                            (ID_to_EX_rs2_data          ),
        .imm_in                                 (ID_to_EX_imm               ),
        .opcode_in                              (ID_to_EX_opcode            ),
        .funct3_in                              (ID_to_EX_funct3            ),
        .funct7_in                              (ID_to_EX_funct7            ),
        .valid_in                               (ID_to_EX_valid             ),
        .reg_write_in                           (ID_to_EX_reg_write         ),
        .mem_write_in                           (ID_to_EX_mem_write         ),
        .mem_read_in                            (ID_to_EX_mem_read          ),
        .mem_to_reg_in                          (ID_to_EX_mem_to_reg        ),
        .branch_in                              (ID_to_EX_branch            ),
        .jump_in                                (ID_to_EX_jump              ),
        .alu_src_in                             (ID_to_EX_alu_src           ),
        .alu_op_in                              (ID_to_EX_alu_op            ),
        .mem_alu_result                         (MEM_to_EX_alu_result       ),
        .wb_result                              (WB_to_EX_result            ),
        .forward_rs1                            (forward_unit_forward_rs1   ),
        .forward_rs2                            (forward_unit_forward_rs2   ),
        .pc_plus_4_out                          (EX_to_MEM_pc_plus_4        ),
        .alu_result_out                         (EX_to_MEM_alu_result       ),
        .mem_data_out                           (EX_to_MEM_mem_data         ),
        .rd_out                                 (EX_to_MEM_rd               ),
        .reg_write_out                          (EX_to_MEM_reg_write        ),
        .mem_write_out                          (EX_to_MEM_mem_write        ),
        .mem_read_out                           (EX_to_MEM_mem_read         ),
        .mem_to_reg_out                         (EX_to_MEM_mem_to_reg       ),
        .funct3_out                             (EX_to_MEM_funct3           ),
        .valid_out                              (EX_to_MEM_valid            ),
        .branch_taken_out                       (hazard_unit_branch_taken   ),
        .branch_target_out                      (EX_to_IF_new_pc            )
    );

    // Memory Stage
    mem_stage #(
        .ADDR_WIDTH         (ADDR_WIDTH         ),
        .DATA_WIDTH         (DATA_WIDTH         ),
        .REGFILE_ADDR_WIDTH (REGFILE_ADDR_WIDTH )
    ) mem_stage_inst (
        .clk                                    (clk                        ),
        .rst_n                                  (rst_n                      ),
        .pc_plus_4_in                           (EX_to_MEM_pc_plus_4        ),
        .alu_result_in                          (EX_to_MEM_alu_result       ),
        .mem_data_in                            (EX_to_MEM_mem_data         ),
        .rd_in                                  (EX_to_MEM_rd               ),
        .reg_write_in                           (EX_to_MEM_reg_write        ),
        .mem_write_in                           (EX_to_MEM_mem_write        ),
        .mem_read_in                            (EX_to_MEM_mem_read         ),
        .mem_to_reg_in                          (EX_to_MEM_mem_to_reg       ),
        .funct3_in                              (EX_to_MEM_funct3           ),
        .valid_in                               (EX_to_MEM_valid            ),
        .wbm_dmem_cyc                           (wbm_dmem_cyc               ),
        .wbm_dmem_stb                           (wbm_dmem_stb               ),
        .wbm_dmem_we                            (wbm_dmem_we                ),
        .wbm_dmem_addr                          (wbm_dmem_addr              ),
        .wbm_dmem_data_write                    (wbm_dmem_data_write        ),
        .wbm_dmem_sel                           (wbm_dmem_sel               ),
        .wbm_dmem_data_read                     (wbm_dmem_data_read         ),
        .wbm_dmem_ack                           (wbm_dmem_ack               ),
        .pc_plus_4_out                          (MEM_to_WB_pc_plus_4        ),
        .mem_result_out                         (MEM_to_WB_mem_result       ),
        .alu_result_out                         (MEM_to_WB_alu_result       ),
        .rd_out                                 (MEM_to_WB_rd               ),
        .reg_write_out                          (MEM_to_WB_reg_write        ),
        .mem_to_reg_out                         (MEM_to_WB_mem_to_reg       ),
        .valid_out                              (MEM_to_WB_valid            ),
        .load_misaligned                        (MEM_load_misaligned        ),
        .store_misaligned                       (MEM_store_misaligned       )
    );

    // Writeback Stage
    writeback_stage #(
        .ADDR_WIDTH         (ADDR_WIDTH         ),
        .DATA_WIDTH         (DATA_WIDTH         ),
        .REGFILE_ADDR_WIDTH (REGFILE_ADDR_WIDTH )
    ) writeback_stage_inst (
        .clk                                    (clk                        ),
        .rst_n                                  (rst_n                      ),
        .pc_plus_4_in                           (MEM_to_WB_pc_plus_4        ),
        .mem_result_in                          (MEM_to_WB_mem_result       ),
        .alu_result_in                          (MEM_to_WB_alu_result       ),
        .rd_in                                  (MEM_to_WB_rd               ),
        .reg_write_in                           (MEM_to_WB_reg_write        ),
        .mem_to_reg_in                          (MEM_to_WB_mem_to_reg       ),
        .valid_in                               (MEM_to_WB_valid            ),
        .regfile_we                             (WB_to_ID_reg_write         ),
        .regfile_rd_addr                        (WB_to_ID_rd_addr           ),
        .regfile_wr_data                        (WB_to_ID_wr_dara           ),
        .rd_out                                 (forward_unit_wb_rd         ),
        .result_out                             (WB_to_EX_result            ),
        .reg_write_out                          (forward_unit_wb_reg_write  ),
        .valid_out                              (forward_unit_wb_valid      )
    );

    // -------------------------------------------
    // Units
    // -------------------------------------------

    // Hazard Unit
    hazard_unit #(
        .ADDR_WIDTH         (ADDR_WIDTH         ),
        .DATA_WIDTH         (DATA_WIDTH         ),
        .REGFILE_ADDR_WIDTH (REGFILE_ADDR_WIDTH )
    ) hazard_unit_inst (
        .fetch_valid                            (IF_to_ID_valid             ),
        .id_rs1                                 (ID_to_EX_rs1_addr          ),       
        .id_rs2                                 (ID_to_EX_rs2_addr          ),       
        .id_mem_read                            (ID_to_EX_mem_read          ),  
        .id_valid                               (ID_to_EX_valid             ),
        .ex_rd                                  (EX_to_MEM_rd               ),        
        .ex_reg_write                           (EX_to_MEM_reg_write        ), 
        .ex_mem_read                            (EX_to_MEM_mem_read         ),  
        .ex_valid                               (EX_to_MEM_valid            ),
        .mem_rd                                 (MEM_to_WB_rd               ),       
        .mem_reg_write                          (MEM_to_WB_reg_write        ),
        .mem_valid                              (MEM_to_WB_valid            ),
        .branch_taken                           (hazard_unit_branch_taken   ),
        .stall_fetch                            (hazard_unit_stall_fetch    ),  
        .stall_decode                           (hazard_unit_stall_decode   ), 
        .stall_execute                          (hazard_unit_stall_execute  ),
        .flush_fetch                            (hazard_unit_flush_fetch    ),  
        .flush_decode                           (hazard_unit_flush_decode   ), 
        .flush_execute                          (hazard_unit_flush_execute  )
    );

    // Forward Unit
    forward_unit #(
        .REGFILE_ADDR_WIDTH (REGFILE_ADDR_WIDTH )
    ) forward_unit_inst (
        .decode_rs1                             (ID_to_EX_rs1_addr          ),
        .decode_rs2                             (ID_to_EX_rs2_addr          ),
        .execute_rd                             (EX_to_MEM_rd               ),
        .execute_reg_write                      (EX_to_MEM_reg_write        ),
        .execute_valid                          (EX_to_MEM_valid            ),
        .memory_rd                              (MEM_to_WB_rd               ),
        .memory_reg_write                       (MEM_to_WB_reg_write        ),
        .memory_valid                           (MEM_to_WB_valid            ),
        .forward_rs1                            (forward_unit_forward_rs1   ),
        .forward_rs2                            (forward_unit_forward_rs2   )
    );

endmodule