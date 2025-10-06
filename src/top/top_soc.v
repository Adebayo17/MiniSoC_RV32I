module top_soc #(
    parameter FIRMWARE_FILE = "firmware.mem",
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 32,
    parameter IMEM_SIZE_KB  = 8,
    parameter DMEM_SIZE_KB  = 4,
    parameter DATA_SIZE_KB  = 4,
    parameter BAUD_DIV_RST  = 16'd104,          // 115200 baud @ 12MHz
    parameter N_GPIO        = 8
) (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n,

    // UART Physical Interface
    input wire                      uart_rx,
    output wire                     uart_tx,

    // GPIO Physical Interface
    inout wire                      gpio0_io,   // Physical pad 0
    inout wire                      gpio1_io,   // Physical pad 1
    inout wire                      gpio2_io,   // Physical pad 2
    inout wire                      gpio3_io,   // Physical pad 3
    inout wire                      gpio4_io,   // Physical pad 4
    inout wire                      gpio5_io,   // Physical pad 5
    inout wire                      gpio6_io,   // Physical pad 6
    inout wire                      gpio7_io    // Physical pad 7
);
    
    // ----------------------------
    // Parameters
    // ----------------------------
    localparam [31:0] IMEM_BASE_ADDR  = 32'h0000_0000;
    localparam [31:0] DMEM_BASE_ADDR  = 32'h1000_0000;
    localparam [31:0] UART_BASE_ADDR  = 32'h2000_0000;
    localparam [31:0] TIMER_BASE_ADDR = 32'h3000_0000;
    localparam [31:0] GPIO_BASE_ADDR  = 32'h4000_0000;

    localparam        RESET_PC        = 32'h0000_0000;

    // ----------------------------
    // Wires and Reg
    // ----------------------------
    // MEM_INIT Instance: init_controller
    wire                      init_start;
    wire                      init_done;
    wire                      imem_init_en;
    wire [ADDR_WIDTH-1:0]     imem_init_addr;
    wire [DATA_WIDTH-1:0]     imem_init_data;
    wire                      dmem_init_en;
    wire [ADDR_WIDTH-1:0]     dmem_init_addr;
    wire [DATA_WIDTH-1:0]     dmem_init_data;

    // CPU-WISHBONE Interface: 
    wire                      wbs_cpu_cyc        ;
    wire                      wbs_cpu_stb        ;
    wire                      wbs_cpu_we         ;
    wire [ADDR_WIDTH-1:0]     wbs_cpu_addr       ;
    wire [DATA_WIDTH-1:0]     wbs_cpu_data_write ;
    wire [3:0]                wbs_cpu_sel        ;
    wire [DATA_WIDTH-1:0]     wbs_cpu_data_read  ;
    wire                      wbs_cpu_ack        ;

    // IMEM Instance: imem_inst
    wire                      wbs_imem_cyc       ;
    wire                      wbs_imem_stb       ;
    wire                      wbs_imem_we        ;
    wire [ADDR_WIDTH-1:0]     wbs_imem_addr      ;
    wire [DATA_WIDTH-1:0]     wbs_imem_data_write;
    wire [3:0]                wbs_imem_sel       ;
    wire [DATA_WIDTH-1:0]     wbs_imem_data_read ;
    wire                      wbs_imem_ack       ;

    // DMEM Instance: dmem_inst
    wire                      wbs_dmem_cyc       ;
    wire                      wbs_dmem_stb       ;
    wire                      wbs_dmem_we        ;
    wire [ADDR_WIDTH-1:0]     wbs_dmem_addr      ;
    wire [DATA_WIDTH-1:0]     wbs_dmem_data_write;
    wire [3:0]                wbs_dmem_sel       ;
    wire [DATA_WIDTH-1:0]     wbs_dmem_data_read ;
    wire                      wbs_dmem_ack       ;

    // UART
    wire                      wbs_uart_cyc       ;
    wire                      wbs_uart_stb       ;
    wire                      wbs_uart_we        ;
    wire [ADDR_WIDTH-1:0]     wbs_uart_addr      ;
    wire [DATA_WIDTH-1:0]     wbs_uart_data_write;
    wire [3:0]                wbs_uart_sel       ;
    wire [DATA_WIDTH-1:0]     wbs_uart_data_read ;
    wire                      wbs_uart_ack       ;


    // TIMER
    wire                      wbs_timer_cyc       ;
    wire                      wbs_timer_stb       ;
    wire                      wbs_timer_we        ;
    wire [ADDR_WIDTH-1:0]     wbs_timer_addr      ;
    wire [DATA_WIDTH-1:0]     wbs_timer_data_write;
    wire [3:0]                wbs_timer_sel       ;
    wire [DATA_WIDTH-1:0]     wbs_timer_data_read ;
    wire                      wbs_timer_ack       ;


    // GPIO
    wire                      wbs_gpio_cyc       ;
    wire                      wbs_gpio_stb       ;
    wire                      wbs_gpio_we        ;
    wire [ADDR_WIDTH-1:0]     wbs_gpio_addr      ;
    wire [DATA_WIDTH-1:0]     wbs_gpio_data_write;
    wire [3:0]                wbs_gpio_sel       ;
    wire [DATA_WIDTH-1:0]     wbs_gpio_data_read ;
    wire                      wbs_gpio_ack       ;
    wire [N_GPIO-1:0]         gpio_in            ; 
    wire [N_GPIO-1:0]         gpio_out           ;
    wire [N_GPIO-1:0]         gpio_oe            ;


    // ----------------------------
    // Reset Signals
    // ----------------------------
    wire peripheral_rst_n;
    wire cpu_rst_n;
    wire memory_rst_n;
    
    // Reset synchronization registers
    reg rst_n_sync1, rst_n_sync2;
    reg init_done_sync1, init_done_sync2;
    
    // ----------------------------
    // Reset Synchronization
    // ----------------------------
    
    // Synchronize external reset to clock domain
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_n_sync1 <= 1'b0;
            rst_n_sync2 <= 1'b0;
        end else begin
            rst_n_sync1 <= 1'b1;
            rst_n_sync2 <= rst_n_sync1;
        end
    end
    
    // Synchronize init_done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            init_done_sync1 <= 1'b0;
            init_done_sync2 <= 1'b0;
        end else begin
            init_done_sync1 <= init_done;
            init_done_sync2 <= init_done_sync1;
        end
    end
    
    // ----------------------------
    // Reset Distribution
    // ----------------------------
    
    // Level 1: Memory and basic peripherals (reset immediately)
    assign memory_rst_n = rst_n_sync2;
    
    // Level 2: Complex peripherals (reset after memory init)
    assign peripheral_rst_n = rst_n_sync2 && init_done_sync2;
    
    // Level 3: CPU (reset after everything is ready)
    assign cpu_rst_n = rst_n_sync2 && init_done_sync2;



    // ----------------------------
    // CPU Instance
    // ----------------------------
    cpu #(
        .RESET_PC   (RESET_PC   ),
        .ADDR_WIDTH (ADDR_WIDTH ),
        .DATA_WIDTH (DATA_WIDTH )
    ) rv32i_core (
        .clk                    (clk                    ),
        .rst_n                  (cpu_rst_n              ),
        .wbm_imem_cyc           (wbs_imem_cyc           ),
        .wbm_imem_stb           (wbs_imem_stb           ),
        .wbm_imem_we            (wbs_imem_we            ),
        .wbm_imem_addr          (wbs_imem_addr          ),
        .wbm_imem_data_write    (wbs_imem_data_write    ),
        .wbm_imem_sel           (wbs_imem_sel           ),
        .wbm_imem_data_read     (wbs_imem_data_read     ),
        .wbm_imem_ack           (wbs_imem_ack           ),
        .wbm_dmem_cyc           (wbs_cpu_cyc            ),
        .wbm_dmem_stb           (wbs_cpu_stb            ),
        .wbm_dmem_we            (wbs_cpu_we             ),
        .wbm_dmem_addr          (wbs_cpu_addr           ),
        .wbm_dmem_data_write    (wbs_cpu_data_write     ),
        .wbm_dmem_sel           (wbs_cpu_sel            ),
        .wbm_dmem_data_read     (wbs_cpu_data_read      ),
        .wbm_dmem_ack           (wbs_cpu_ack            )
    );

    // always @(posedge clk) begin
    //     cpu_rst_n <= rst_n && init_done;
    // end

    // ---------------------------------------------------------------------------------------------
    // Interconnect
    // ---------------------------------------------------------------------------------------------

    // ----------------------------
    // WISHBONE INTERCONNECT Instance
    // ----------------------------
    wishbone_interconnect #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) wishbone_interconnect_inst (
        .clk                    (clk                     ),
        .rst_n                  (peripheral_rst_n        ),
        .wbm_cpu_cyc            (wbs_cpu_cyc             ),
        .wbm_cpu_stb            (wbs_cpu_stb             ),
        .wbm_cpu_we             (wbs_cpu_we              ),
        .wbm_cpu_addr           (wbs_cpu_addr            ),
        .wbm_cpu_data_write     (wbs_cpu_data_write      ),
        .wbm_cpu_sel            (wbs_cpu_sel             ),
        .wbm_cpu_data_read      (wbs_cpu_data_read       ),
        .wbm_cpu_ack            (wbs_cpu_ack             ),
        .wbs_dmem_cyc           (wbs_dmem_cyc            ),
        .wbs_dmem_stb           (wbs_dmem_stb            ),
        .wbs_dmem_we            (wbs_dmem_we             ),
        .wbs_dmem_addr          (wbs_dmem_addr           ),
        .wbs_dmem_data_write    (wbs_dmem_data_write     ),
        .wbs_dmem_sel           (wbs_dmem_sel            ),
        .wbs_dmem_data_read     (wbs_dmem_data_read      ),
        .wbs_dmem_ack           (wbs_dmem_ack            ),
        .wbs_uart_cyc           (wbs_uart_cyc            ),
        .wbs_uart_stb           (wbs_uart_stb            ),
        .wbs_uart_we            (wbs_uart_we             ),
        .wbs_uart_addr          (wbs_uart_addr           ),
        .wbs_uart_data_write    (wbs_uart_data_write     ),
        .wbs_uart_sel           (wbs_uart_sel            ),
        .wbs_uart_data_read     (wbs_uart_data_read      ),
        .wbs_uart_ack           (wbs_uart_ack            ),
        .wbs_timer_cyc          (wbs_timer_cyc           ),
        .wbs_timer_stb          (wbs_timer_stb           ),
        .wbs_timer_we           (wbs_timer_we            ),
        .wbs_timer_addr         (wbs_timer_addr          ),
        .wbs_timer_data_write   (wbs_timer_data_write    ),
        .wbs_timer_sel          (wbs_timer_sel           ),
        .wbs_timer_data_read    (wbs_timer_data_read     ),
        .wbs_timer_ack          (wbs_timer_ack           ),
        .wbs_gpio_cyc           (wbs_gpio_cyc            ),
        .wbs_gpio_stb           (wbs_gpio_stb            ),
        .wbs_gpio_we            (wbs_gpio_we             ),
        .wbs_gpio_addr          (wbs_gpio_addr           ),
        .wbs_gpio_data_write    (wbs_gpio_data_write     ),
        .wbs_gpio_sel           (wbs_gpio_sel            ),
        .wbs_gpio_data_read     (wbs_gpio_data_read      ),
        .wbs_gpio_ack           (wbs_gpio_ack            )
    );

    // ---------------------------------------------------------------------------------------------
    // MEMORIES
    // ---------------------------------------------------------------------------------------------

    // ----------------------------
    // MEM_INIT Instance
    // ----------------------------
    // reg rst_n_prev;
    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         rst_n_prev <= 1'b0;
    //     end else begin
    //         rst_n_prev <= rst_n;
    //     end
    // end
    
    // // Generate init_start on rising edge of rst_n
    // assign init_start = rst_n && !rst_n_prev;

    reg rst_n_prev;
    always @(posedge clk or negedge rst_n_sync2) begin
        if (!rst_n_sync2) begin
            rst_n_prev <= 1'b0;
        end else begin
            rst_n_prev <= rst_n_sync2;
        end
    end
    // Generate init_start on rising edge of rst_n_sync2
    assign init_start = rst_n_sync2 && !rst_n_prev;

    mem_init #(
        .IMEM_BASE      (IMEM_BASE_ADDR ),
        .DMEM_BASE      (DMEM_BASE_ADDR ),
        .INIT_FILE      (FIRMWARE_FILE  ),
        .IMEM_SIZE_KB   (IMEM_SIZE_KB   ),
        .DMEM_SIZE_KB   (DMEM_SIZE_KB   ),
        .ADDR_WIDTH     (ADDR_WIDTH     ),
        .DATA_WIDTH     (DATA_WIDTH     )
    ) init_controller(
        .clk                (clk                ),
        .rst_n              (memory_rst_n       ),
        .init_start         (init_start         ),   
        .init_done          (init_done          ),
        .imem_init_en       (imem_init_en       ),
        .imem_init_addr     (imem_init_addr     ),
        .imem_init_data     (imem_init_data     ),
        .dmem_init_en       (dmem_init_en       ),
        .dmem_init_addr     (dmem_init_addr     ),
        .dmem_init_data     (dmem_init_data     )
    );

    // ----------------------------
    // IMEM Instance
    // ----------------------------
    imem_wrapper #(
        .BASE_ADDR  (IMEM_BASE_ADDR ),
        .SIZE_KB    (IMEM_SIZE_KB   ),
        .ADDR_WIDTH (ADDR_WIDTH     ),
        .DATA_WIDTH (DATA_WIDTH     )
    ) imem_inst (
        .clk                (clk                  ),
        .rst_n              (memory_rst_n         ),
        .wbs_cyc            (wbs_imem_cyc         ),
        .wbs_stb            (wbs_imem_stb         ),
        .wbs_we             (wbs_imem_we          ),
        .wbs_addr           (wbs_imem_addr        ),  
        .wbs_data_write     (wbs_imem_data_write  ),
        .wbs_sel            (wbs_imem_sel         ),
        .wbs_data_read      (wbs_imem_data_read   ),
        .wbs_ack            (wbs_imem_ack         ),
        .init_en            (imem_init_en         ),
        .init_addr          (imem_init_addr       ),
        .init_data          (imem_init_data       )
    );


    // ----------------------------
    // DMEM Instance
    // ----------------------------
    dmem_wrapper #(
        .BASE_ADDR  (DMEM_BASE_ADDR ),
        .SIZE_KB    (DMEM_SIZE_KB   ),
        .ADDR_WIDTH (ADDR_WIDTH     ),
        .DATA_WIDTH (DATA_WIDTH     )
    ) dmem_inst (
        .clk                (clk                  ),
        .rst_n              (memory_rst_n         ),
        .wbs_cyc            (wbs_dmem_cyc         ),
        .wbs_stb            (wbs_dmem_stb         ),
        .wbs_we             (wbs_dmem_we          ),
        .wbs_addr           (wbs_dmem_addr        ),  
        .wbs_data_write     (wbs_dmem_data_write  ),
        .wbs_sel            (wbs_dmem_sel         ),
        .wbs_data_read      (wbs_dmem_data_read   ),
        .wbs_ack            (wbs_dmem_ack         ),
        .init_en            (dmem_init_en         ),
        .init_addr          (dmem_init_addr       ),
        .init_data          (dmem_init_data       )
    );



    // ---------------------------------------------------------------------------------------------
    // PERIPHERALS
    // ---------------------------------------------------------------------------------------------

    // ----------------------------
    // UART Instance
    // ----------------------------
    uart_wrapper #(
        .BASE_ADDR      (UART_BASE_ADDR     ),
        .SIZE_KB        (DATA_SIZE_KB       ),
        .ADDR_WIDTH     (ADDR_WIDTH         ),
        .DATA_WIDTH     (DATA_WIDTH         ),
        .BAUD_DIV_RST   (BAUD_DIV_RST       )
    ) uart_inst (
        .clk            (clk                ),
        .rst_n          (peripheral_rst_n   ),
        .wbs_cyc        (wbs_uart_cyc       ),
        .wbs_stb        (wbs_uart_stb       ),
        .wbs_we         (wbs_uart_we        ),
        .wbs_addr       (wbs_uart_addr      ),
        .wbs_data_write (wbs_uart_data_write),
        .wbs_sel        (wbs_uart_sel       ),
        .wbs_data_read  (wbs_uart_data_read ),
        .wbs_ack        (wbs_uart_ack       ),
        .uart_tx        (uart_tx            ),
        .uart_rx        (uart_rx            )
    );


    // ----------------------------
    // TIMER Instance
    // ----------------------------
    timer_wrapper #(
        .BASE_ADDR  (TIMER_BASE_ADDR    ),
        .SIZE_KB    (DATA_SIZE_KB       ),
        .ADDR_WIDTH (ADDR_WIDTH         ),
        .DATA_WIDTH (DATA_WIDTH         )
    ) timer_inst (
        .clk                (clk                 ),
        .rst_n              (peripheral_rst_n    ),
        .wbs_cyc            (wbs_timer_cyc       ),
        .wbs_stb            (wbs_timer_stb       ),
        .wbs_we             (wbs_timer_we        ),
        .wbs_addr           (wbs_timer_addr      ),
        .wbs_data_write     (wbs_timer_data_write),
        .wbs_sel            (wbs_timer_sel       ),
        .wbs_data_read      (wbs_timer_data_read ),
        .wbs_ack            (wbs_timer_ack       )
    );


    // ----------------------------
    // GPIO Instance
    // ----------------------------
    gpio_wrapper #(
        .BASE_ADDR  (GPIO_BASE_ADDR     ),
        .SIZE_KB    (DATA_SIZE_KB       ),
        .ADDR_WIDTH (ADDR_WIDTH         ),
        .DATA_WIDTH (DATA_WIDTH         ),
        .N_GPIO     (N_GPIO             )
    ) gpio_inst (
        .clk                (clk                ),
        .rst_n              (peripheral_rst_n   ),
        .wbs_cyc            (wbs_gpio_cyc       ),
        .wbs_stb            (wbs_gpio_stb       ),
        .wbs_we             (wbs_gpio_we        ),
        .wbs_addr           (wbs_gpio_addr      ),
        .wbs_data_write     (wbs_gpio_data_write),
        .wbs_sel            (wbs_gpio_sel       ),
        .wbs_data_read      (wbs_gpio_data_read ),
        .wbs_ack            (wbs_gpio_ack       ),
        .gpio_in            (gpio_in            ),
        .gpio_out           (gpio_out           ),
        .gpio_oe            (gpio_oe            )
    );

    // ---------------------------------------------------------------------------------------------
    // PAD I/O
    // ---------------------------------------------------------------------------------------------
    
    // ----------------------------
    // GPIO 0 Pad
    // ----------------------------
    io_pad gpio_pad_0 (
        .pad_in(gpio_in[0]),
        .pad_out(gpio_out[0]),
        .pad_oe(gpio_oe[0]),
        .pad_io(gpio0_io)
    );

    // ----------------------------
    // GPIO 1 Pad
    // ----------------------------
    io_pad gpio_pad_1 (
        .pad_in(gpio_in[1]),
        .pad_out(gpio_out[1]),
        .pad_oe(gpio_oe[1]),
        .pad_io(gpio1_io)
    );

    // ----------------------------
    // GPIO 2 Pad
    // ----------------------------
    io_pad gpio_pad_2 (
        .pad_in(gpio_in[2]),
        .pad_out(gpio_out[2]),
        .pad_oe(gpio_oe[2]),
        .pad_io(gpio2_io)
    );

    // ----------------------------
    // GPIO 3 Pad
    // ----------------------------
    io_pad gpio_pad_3 (
        .pad_in(gpio_in[3]),
        .pad_out(gpio_out[3]),
        .pad_oe(gpio_oe[3]),
        .pad_io(gpio3_io)
    );

    // ----------------------------
    // GPIO 4 Pad
    // ----------------------------
    io_pad gpio_pad_4 (
        .pad_in(gpio_in[4]),
        .pad_out(gpio_out[4]),
        .pad_oe(gpio_oe[4]),
        .pad_io(gpio4_io)
    );

    // ----------------------------
    // GPIO 5 Pad
    // ----------------------------
    io_pad gpio_pad_5 (
        .pad_in(gpio_in[5]),
        .pad_out(gpio_out[5]),
        .pad_oe(gpio_oe[5]),
        .pad_io(gpio5_io)
    );

    // ----------------------------
    // GPIO 6 Pad
    // ----------------------------
    io_pad gpio_pad_6 (
        .pad_in(gpio_in[6]),
        .pad_out(gpio_out[6]),
        .pad_oe(gpio_oe[6]),
        .pad_io(gpio6_io)
    );

    // ----------------------------
    // GPIO 7 Pad
    // ----------------------------
    io_pad gpio_pad_7 (
        .pad_in(gpio_in[7]),
        .pad_out(gpio_out[7]),
        .pad_oe(gpio_oe[7]),
        .pad_io(gpio7_io)
    );


endmodule