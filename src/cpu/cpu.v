module cpu #(
    parameter RESET_PC           = 32'h0000_0000,
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
) (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n,

    // Wishbone Master Instruction Interface (IMEM)
    output wire                     wbm_imem_cyc,
    output wire                     wbm_imem_stb,
    output wire                     wbm_imem_we,            // always 0
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
    // WIRES AND REGS
    // -------------------------------------------
    // Regfile0
    wire [REGFILE_ADDR_WIDTH-1:0] regfile_rs1_addr    ;
    wire [REGFILE_ADDR_WIDTH-1:0] regfile_rs2_addr    ;
    wire [DATA_WIDTH-1:0]         regfile_rs1_data    ;
    wire [DATA_WIDTH-1:0]         regfile_rs2_data    ;
    wire                          regfile_wr_en       ;
    wire [REGFILE_ADDR_WIDTH-1:0] regfile_wr_addr     ;
    wire [DATA_WIDTH-1:0]         regfile_wr_data     ;

    // Fetcher
    wire                    fetcher_flush           ;
    wire [ADDR_WIDTH-1:0]   fetcher_new_pc          ;
    wire                    fetcher_stall           ;
    wire [DATA_WIDTH-1:0]   fetcher_instr_out       ;
    wire [ADDR_WIDTH-1:0]   fetcher_pc_out          ;
    wire                    fetcher_valid_out       ;

    // Decoder
    wire [DATA_WIDTH-1:0]   decoder_instr_in        ;
    wire [ADDR_WIDTH-1:0]   decoder_pc_in           ;
    wire                    decoder_valid_in        ;
    wire                    decoder_flush           ;
    wire                    decoder_stall           ;
    wire [DATA_WIDTH-1:0]   decoder_instr_out       ;
    wire [ADDR_WIDTH-1:0]   decoder_pc_out          ;
    wire [4:0]              decoder_rs1_out         ;
    wire [4:0]              decoder_rs2_out         ;
    wire [4:0]              decoder_rd_out          ;
    wire [DATA_WIDTH-1:0]   decoder_imm_out         ;
    wire [6:0]              decoder_opcode_out      ;
    wire [2:0]              decoder_funct3_out      ;
    wire [6:0]              decoder_funct7_out      ;
    wire                    decoder_valid_out       ;

    // Control Unit
    wire [6:0]  ctrl_unit_opcode        ;
    wire [2:0]  ctrl_unit_funct3        ;
    wire [6:0]  ctrl_unit_funct7        ;
    wire        ctrl_unit_reg_write     ;
    wire        ctrl_unit_mem_write     ;
    wire        ctrl_unit_mem_read      ;
    wire [1:0]  ctrl_unit_mem_to_reg    ;
    wire        ctrl_unit_branch        ;
    wire        ctrl_unit_alu_src       ;
    wire [3:0]  ctrl_unit_alu_op        ;
    wire        ctrl_unit_jump          ;
    wire        ctrl_unit_illegal_instr ;

    // Executer
    wire [DATA_WIDTH-1:0] executer_pc_in               ;
    wire [4:0]            executer_rd_in               ;
    wire [DATA_WIDTH-1:0] executer_rs1_data            ;
    wire [DATA_WIDTH-1:0] executer_rs2_data            ;
    wire [DATA_WIDTH-1:0] executer_imm_in              ;
    wire [6:0]            executer_opcode_in           ;
    wire [2:0]            executer_funct3_in           ;
    wire [6:0]            executer_funct7_in           ;
    wire                  executer_valid_in            ;
    wire                  executer_reg_write_in        ;
    wire                  executer_mem_write_in        ;
    wire                  executer_mem_read_in         ;
    wire [1:0]            executer_mem_to_reg_in       ;
    wire                  executer_branch_in           ;
    wire                  executer_jump_in             ;
    wire                  executer_alu_src_in          ;
    wire [3:0]            executer_alu_op_in           ;
    wire [DATA_WIDTH-1:0] executer_alu_result_out      ;
    wire [DATA_WIDTH-1:0] executer_mem_data_out        ;
    wire [4:0]            executer_rd_out              ;
    wire                  executer_reg_write_out       ;
    wire                  executer_mem_write_out       ;
    wire                  executer_mem_read_out        ;
    wire [1:0]            executer_mem_to_reg_out      ;
    wire [2:0]            executer_funct3_out          ;
    wire                  executer_valid_out           ;
    wire                  executer_branch_taken_out    ;
    wire [DATA_WIDTH-1:0] executer_branch_target_out   ;
    wire [DATA_WIDTH-1:0] executer_pc_plus_4_out       ;

    // Memory
    wire [DATA_WIDTH-1:0] memory_pc_plus_4_in          ;
    wire [DATA_WIDTH-1:0] memory_alu_result_in         ;
    wire [DATA_WIDTH-1:0] memory_mem_data_in           ;
    wire [4:0]            memory_rd_in                 ;
    wire                  memory_reg_write_in          ;
    wire                  memory_mem_write_in          ;
    wire                  memory_mem_read_in           ;
    wire [1:0]            memory_mem_to_reg_in         ;
    wire [2:0]            memory_funct3_in             ;
    wire                  memory_valid_in              ;
    wire [DATA_WIDTH-1:0] memory_pc_plus_4_out         ;
    wire [DATA_WIDTH-1:0] memory_mem_result_out        ;
    wire [DATA_WIDTH-1:0] memory_alu_result_out        ;
    wire [4:0]            memory_rd_out                ;
    wire                  memory_reg_write_out         ;
    wire [1:0]            memory_mem_to_reg_out        ;
    wire                  memory_valid_out             ;
    wire                  memory_load_misaligned       ;
    wire                  memory_store_misaligned      ;

    // Writebacker
    wire [DATA_WIDTH-1:0] writebacker_pc_plus_4_in    ;
    wire [DATA_WIDTH-1:0] writebacker_mem_result_in   ;
    wire [DATA_WIDTH-1:0] writebacker_alu_result_in   ;
    wire [4:0]            writebacker_rd_in           ;
    wire                  writebacker_reg_write_in    ;
    wire [1:0]            writebacker_mem_to_reg_in   ;
    wire                  writebacker_valid_in        ;
    wire                  writebacker_regfile_we      ;
    wire [4:0]            writebacker_regfile_rd_addr ;
    wire [DATA_WIDTH-1:0] writebacker_regfile_wr_data ;
    wire                  writebacker_valid_out       ;



    // -------------------------------------------
    // REGFILE 
    // -------------------------------------------
    regfile #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (REGFILE_ADDR_WIDTH)
    ) regfile0 (
        .clk         (clk                 ),
        .rst_n       (rst_n               ),
        .rs1_addr    (regfile_rs1_addr    ),
        .rs2_addr    (regfile_rs2_addr    ),
        .rs1_data    (regfile_rs1_data    ),
        .rs2_data    (regfile_rs2_data    ),
        .wr_en       (regfile_wr_en       ),
        .wr_addr     (regfile_wr_addr     ),
        .wr_data     (regfile_wr_data     )
    );


    // -------------------------------------------
    // FETCH STAGE
    // -------------------------------------------
    fetch_stage #(
        .RESET_PC   (RESET_PC  ),
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) fetcher (
        .clk                 (clk                    ),
        .rst_n               (rst_n                  ),
        .wbm_imem_cyc        (wbm_imem_cyc           ),
        .wbm_imem_stb        (wbm_imem_stb           ),
        .wbm_imem_we         (wbm_imem_we            ),
        .wbm_imem_addr       (wbm_imem_addr          ),
        .wbm_imem_data_write (wbm_imem_data_write    ),
        .wbm_imem_sel        (wbm_imem_sel           ),
        .wbm_imem_data_read  (wbm_imem_data_read     ),
        .wbm_imem_ack        (wbm_imem_ack           ),
        .flush               (fetcher_flush          ),
        .new_pc              (fetcher_new_pc         ),
        .stall               (fetcher_stall          ),
        .instr_out           (fetcher_instr_out      ),
        .pc_out              (fetcher_pc_out         ),
        .valid_out           (fetcher_valid_out      )
    );



    // -------------------------------------------
    // DECODE STAGE
    // -------------------------------------------
    decode_stage #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) decoder (
        .clk             (clk                     ),
        .rst_n           (rst_n                   ),
        .instr_in        (decoder_instr_in        ),
        .pc_in           (decoder_pc_in           ),
        .valid_in        (decoder_valid_in        ),
        .flush           (decoder_flush           ),
        .stall           (decoder_stall           ),
        .instr_out       (decoder_instr_out       ),
        .pc_out          (decoder_pc_out          ),
        .rs1_out         (decoder_rs1_out         ),
        .rs2_out         (decoder_rs2_out         ),
        .rd_out          (decoder_rd_out          ),
        .imm_out         (decoder_imm_out         ),
        .opcode_out      (decoder_opcode_out      ),
        .funct3_out      (decoder_funct3_out      ),
        .funct7_out      (decoder_funct7_out      ),
        .valid_out       (decoder_valid_out       )
    );

    // -------------------------------------------
    // Control Unit
    // -------------------------------------------
    control_unit ctrl_unit (
        .opcode        (ctrl_unit_opcode        ),
        .funct3        (ctrl_unit_funct3        ),
        .funct7        (ctrl_unit_funct7        ),
        .reg_write     (ctrl_unit_reg_write     ),
        .mem_write     (ctrl_unit_mem_write     ),
        .mem_read      (ctrl_unit_mem_read      ),
        .mem_to_reg    (ctrl_unit_mem_to_reg    ),
        .branch        (ctrl_unit_branch        ),
        .alu_src       (ctrl_unit_alu_src       ),
        .alu_op        (ctrl_unit_alu_op        ),
        .jump          (ctrl_unit_jump          ),
        .illegal_instr (ctrl_unit_illegal_instr )
    );

    // -------------------------------------------
    // EXECUTE STAGE
    // -------------------------------------------
    execute_stage #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) executer (
        .clk                 (clk                          ),
        .rst_n               (rst_n                        ),
        .pc_in               (executer_pc_in               ),
        .rd_in               (executer_rd_in               ),
        .rs1_data            (executer_rs1_data            ),
        .rs2_data            (executer_rs2_data            ),
        .imm_in              (executer_imm_in              ),
        .opcode_in           (executer_opcode_in           ),
        .funct3_in           (executer_funct3_in           ),
        .funct7_in           (executer_funct7_in           ),
        .valid_in            (executer_valid_in            ),
        .reg_write_in        (executer_reg_write_in        ),
        .mem_write_in        (executer_mem_write_in        ),
        .mem_read_in         (executer_mem_read_in         ),
        .mem_to_reg_in       (executer_mem_to_reg_in       ),
        .branch_in           (executer_branch_in           ),
        .jump_in             (executer_jump_in             ),
        .alu_src_in          (executer_alu_src_in          ),
        .alu_op_in           (executer_alu_op_in           ),
        .alu_result_out      (executer_alu_result_out      ),
        .mem_data_out        (executer_mem_data_out        ),
        .rd_out              (executer_rd_out              ),
        .reg_write_out       (executer_reg_write_out       ),
        .mem_write_out       (executer_mem_write_out       ),
        .mem_read_out        (executer_mem_read_out        ),
        .mem_to_reg_out      (executer_mem_to_reg_out      ),
        .funct3_out          (executer_funct3_out          ),
        .valid_out           (executer_valid_out           ),
        .branch_taken_out    (executer_branch_taken_out    ),
        .branch_target_out   (executer_branch_target_out   ),
        .pc_plus_4_out       (executer_pc_plus_4_out       ),
        .forwarded_mem_result(memory_alu_result_in         ),
        .forwarded_wb_result (writebacker_regfile_wr_data  ),
        .forward_rs1         (forward_rs1                  ),
        .forward_rs2         (forward_rs2                  )
    );

    // -------------------------------------------
    // MEMORY STAGE
    // -------------------------------------------
    mem_stage #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) memory (
        .clk                     (clk                          ),
        .rst_n                   (rst_n                        ),
        .pc_plus_4_in            (memory_pc_plus_4_in          ),
        .alu_result_in           (memory_alu_result_in         ),
        .mem_data_in             (memory_mem_data_in           ),
        .rd_in                   (memory_rd_in                 ),
        .reg_write_in            (memory_reg_write_in          ),
        .mem_write_in            (memory_mem_write_in          ),
        .mem_read_in             (memory_mem_read_in           ),
        .mem_to_reg_in           (memory_mem_to_reg_in         ),
        .funct3_in               (memory_funct3_in             ),
        .valid_in                (memory_valid_in              ),
        .wbm_dmem_cyc            (wbm_dmem_cyc                 ),
        .wbm_dmem_stb            (wbm_dmem_stb                 ),
        .wbm_dmem_we             (wbm_dmem_we                  ),
        .wbm_dmem_addr           (wbm_dmem_addr                ),
        .wbm_dmem_data_write     (wbm_dmem_data_write          ),
        .wbm_dmem_sel            (wbm_dmem_sel                 ),
        .wbm_dmem_data_read      (wbm_dmem_data_read           ),
        .wbm_dmem_ack            (wbm_dmem_ack                 ),
        .pc_plus_4_out           (memory_pc_plus_4_out         ),
        .mem_result_out          (memory_mem_result_out        ),
        .alu_result_out          (memory_alu_result_out        ),
        .rd_out                  (memory_rd_out                ),
        .reg_write_out           (memory_reg_write_out         ),
        .mem_to_reg_out          (memory_mem_to_reg_out        ),
        .valid_out               (memory_valid_out             ),
        .load_misaligned         (memory_load_misaligned       ),
        .store_misaligned        (memory_store_misaligned      )
    );

    // -------------------------------------------
    // WRITEBACK STAGE
    // -------------------------------------------
    wb_stage #(
        .DATA_WIDTH (DATA_WIDTH)
    ) writebacker (
        .clk             (clk                         ),
        .rst_n           (rst_n                       ),
        .pc_plus_4_in    (writebacker_pc_plus_4_in    ),
        .mem_result_in   (writebacker_mem_result_in   ),
        .alu_result_in   (writebacker_alu_result_in   ),
        .rd_in           (writebacker_rd_in           ),
        .reg_write_in    (writebacker_reg_write_in    ),
        .mem_to_reg_in   (writebacker_mem_to_reg_in   ),
        .valid_in        (writebacker_valid_in        ),
        .regfile_we      (writebacker_regfile_we      ),
        .regfile_rd_addr (writebacker_regfile_rd_addr ),
        .regfile_wr_data (writebacker_regfile_wr_data ),
        .valid_out       (writebacker_valid_out       )
    );

    // -------------------------------------------
    // FORWARDING UNIT INSTANTIATION
    // -------------------------------------------
    wire [1:0] forward_rs1, forward_rs2;
    
    forwarding_unit forwarding_u (
        .decode_rs1(decoder_rs1_out),
        .decode_rs2(decoder_rs2_out),
        .execute_rd(executer_rd_in),
        .execute_reg_write(executer_reg_write_in),
        .memory_rd(memory_rd_in),
        .memory_reg_write(memory_reg_write_in),
        .writeback_rd(writebacker_rd_in),
        .writeback_reg_write(writebacker_reg_write_in),
        .forward_rs1(forward_rs1),
        .forward_rs2(forward_rs2)
    );

    // -------------------------------------------
    // HAZARD UNIT INSTANTIATION
    // -------------------------------------------
    wire hazard_flush;
    wire hazard_stall;

    hazard_unit hazard_u (
        .decode_rs1(decoder_rs1_out),
        .decode_rs2(decoder_rs2_out),
        .execute_rd(executer_rd_out),
        .execute_reg_write(executer_reg_write_out),
        .execute_mem_read(executer_mem_read_out),
        .memory_rd(memory_rd_out),
        .memory_reg_write(memory_reg_write_out),
        .branch_taken(executer_branch_taken_out),
        .stall(hazard_stall),
        .flush(hazard_flush)
    );


    // -------------------------------------------
    // PIPELINE CONNECTIONS
    // -------------------------------------------

    // Fetch stage
    assign fetcher_stall                = hazard_stall;
    assign fetcher_flush                = hazard_flush | executer_branch_taken_out;
    assign fetcher_new_pc               = executer_branch_target_out;

    // Fetch -> Decode
    assign decoder_instr_in             = fetcher_instr_out;
    assign decoder_pc_in                = fetcher_pc_out;
    assign decoder_valid_in             = fetcher_valid_out;
    assign decoder_stall                = hazard_stall;
    assign decoder_flush                = hazard_flush | executer_branch_taken_out;

    // Decode -> Execute
    assign executer_pc_in               = decoder_pc_out;
    assign executer_rd_in               = decoder_rd_out;
    assign executer_rs1_data            = regfile_rs1_data;
    assign executer_rs2_data            = regfile_rs2_data;
    assign executer_imm_in              = decoder_imm_out;
    assign executer_opcode_in           = decoder_opcode_out;
    assign executer_funct3_in           = decoder_funct3_out;
    assign executer_funct7_in           = decoder_funct7_out;
    assign executer_valid_in            = decoder_valid_out;
    assign executer_reg_write_in        = ctrl_unit_reg_write;
    assign executer_mem_write_in        = ctrl_unit_mem_write;
    assign executer_mem_read_in         = ctrl_unit_mem_read;
    assign executer_mem_to_reg_in       = ctrl_unit_mem_to_reg;
    assign executer_branch_in           = ctrl_unit_branch;
    assign executer_jump_in             = ctrl_unit_jump;
    assign executer_alu_src_in          = ctrl_unit_alu_src;
    assign executer_alu_op_in           = ctrl_unit_alu_op;

    // Decode -> Control Unit
    assign ctrl_unit_opcode             = decoder_opcode_out;
    assign ctrl_unit_funct3             = decoder_funct3_out;
    assign ctrl_unit_funct7             = decoder_funct7_out;
    
    // Register file read addresses
    assign regfile_rs1_addr             = decoder_rs1_out;
    assign regfile_rs2_addr             = decoder_rs2_out;

    // Execute -> Memory
    assign memory_alu_result_in         = executer_alu_result_out;
    assign memory_mem_data_in           = executer_mem_data_out;
    assign memory_rd_in                 = executer_rd_out;
    assign memory_reg_write_in          = executer_reg_write_out;
    assign memory_mem_write_in          = executer_mem_write_out;
    assign memory_mem_read_in           = executer_mem_read_out;
    assign memory_mem_to_reg_in         = executer_mem_to_reg_out;
    assign memory_funct3_in             = executer_funct3_out;
    assign memory_valid_in              = executer_valid_out;

    // Memory -> Writeback
    assign writebacker_mem_result_in    = memory_mem_result_out;
    assign writebacker_alu_result_in    = memory_alu_result_out;
    assign writebacker_rd_in            = memory_rd_out;
    assign writebacker_reg_write_in     = memory_reg_write_out;
    assign writebacker_mem_to_reg_in    = memory_mem_to_reg_out;
    assign writebacker_valid_in         = memory_valid_out;

    // Writeback -> Register File
    assign regfile_wr_en                = writebacker_regfile_we;
    assign regfile_wr_addr              = writebacker_regfile_rd_addr;
    assign regfile_wr_data              = writebacker_regfile_wr_data;
endmodule