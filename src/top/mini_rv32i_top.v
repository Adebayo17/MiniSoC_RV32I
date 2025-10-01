module mini_rv32i_top #(
    parameter FIRMWARE_FILE = "firmware.hex",
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
    inout wire                      gpio0_io,
    inout wire                      gpio1_io,
    inout wire                      gpio2_io,
    inout wire                      gpio3_io,
    inout wire                      gpio4_io,
    inout wire                      gpio5_io,
    inout wire                      gpio6_io,
    inout wire                      gpio7_io 
);

    top_soc #(
        .FIRMWARE_FILE  (FIRMWARE_FILE  ),
        .ADDR_WIDTH     (ADDR_WIDTH     ),
        .DATA_WIDTH     (DATA_WIDTH     ),
        .IMEM_SIZE_KB   (IMEM_SIZE_KB   ),
        .DMEM_SIZE_KB   (DMEM_SIZE_KB   ),
        .DATA_SIZE_KB   (DATA_SIZE_KB   ),
        .BAUD_DIV_RST   (BAUD_DIV_RST   ),
        .N_GPIO         (N_GPIO         )
    ) top_soc_inst (
        .clk        (clk     ),
        .rst_n      (rst_n   ),
        .uart_rx    (uart_rx ),
        .uart_tx    (uart_tx ),
        .gpio0_io   (gpio0_io),
        .gpio1_io   (gpio1_io),
        .gpio2_io   (gpio2_io),
        .gpio3_io   (gpio3_io),
        .gpio4_io   (gpio4_io),
        .gpio5_io   (gpio5_io),
        .gpio6_io   (gpio6_io),
        .gpio7_io   (gpio7_io) 
    );

endmodule