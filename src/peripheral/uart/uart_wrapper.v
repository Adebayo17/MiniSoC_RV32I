module uart_wrapper #(
    parameter BASE_ADDR  = 32'h2000_0000,
    parameter SIZE_KB    = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CLK_FREQ   = 12_000_000
) (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n,
    
    // Wishbone Slave Interface
    input wire                      wbs_cyc,
    input wire                      wbs_stb,
    input wire                      wbs_we,
    input wire [ADDR_WIDTH-1:0]     wbs_addr,
    input wire [DATA_WIDTH-1:0]     wbs_data_write,
    input wire [3:0]                wbs_sel,
    output reg [DATA_WIDTH-1:0]     wbs_data_read,
    output reg                      wbs_ack,

    // UART Physical Interface
    output reg                      uart_tx,
    input wire                      uart_rx
);

    // ----------------------------
    // Address Decoding
    // ----------------------------
    wire uart_select = (wbs_addr >= BASE_ADDR) && (wbs_addr < BASE_ADDR + (SIZE_KB * 1024));

    // ----------------------------
    // UART Instance
    // ----------------------------
    uart uart_inst (
        .clk                (clk                    ),
        .rst_n              (rst_n                  ),
        .wbs_cyc            (wbs_cyc && uart_select ),
        .wbs_stb            (wbs_stb && uart_select ),
        .wbs_we             (wbs_we                 ),
        .wbs_addr           (wbs_addr               ),
        .wbs_data_write     (wbs_data_write         ),
        .wbs_sel            (wbs_sel                ),
        .wbs_data_read      (wbs_data_read          ),
        .wbs_ack            (wbs_ack                ),
        .uart_tx            (uart_tx                ),
        .uart_rx            (uart_rx                )
    );
    
endmodule