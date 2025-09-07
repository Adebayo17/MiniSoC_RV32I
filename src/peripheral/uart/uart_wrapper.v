module uart_wrapper #(
    parameter BASE_ADDR     = 32'h2000_0000,
    parameter SIZE_KB       = 4,
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 32,
    parameter BAUD_DIV_RST  = 16'd104                // 115200 baud @ 12MHz
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
    output wire                     uart_tx,
    input wire                      uart_rx
);
    // -------------------------------------------
    // Temporary wishbone signal
    // -------------------------------------------
    wire                  tmp_wbs_ack;
    wire [DATA_WIDTH-1:0] tmp_wbs_data_read;

    // ----------------------------
    // Address Decoding
    // ----------------------------
    wire uart_select = (wbs_addr >= BASE_ADDR) && (wbs_addr < BASE_ADDR + (SIZE_KB * 1024));

    // ----------------------------
    // UART Instance
    // ----------------------------
    uart #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BAUD_DIV_RST(BAUD_DIV_RST)
    ) uart_inst (
        .clk                (clk                    ),
        .rst_n              (rst_n                  ),
        .wbs_cyc            (wbs_cyc && uart_select ),
        .wbs_stb            (wbs_stb && uart_select ),
        .wbs_we             (wbs_we                 ),
        .wbs_addr           (wbs_addr               ),
        .wbs_data_write     (wbs_data_write         ),
        .wbs_sel            (wbs_sel                ),
        .wbs_data_read      (tmp_wbs_data_read      ),
        .wbs_ack            (tmp_wbs_ack            ),
        .uart_tx            (uart_tx                ),
        .uart_rx            (uart_rx                )
    );

    // ----------------------------
    // ACK and Data Read Handling
    // ----------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            wbs_data_read <= {DATA_WIDTH{1'b0}};
            wbs_ack       <= 1'b0;
        end else begin
            if (uart_select) begin
                wbs_data_read <= tmp_wbs_data_read;
                wbs_ack       <= tmp_wbs_ack;
            end else begin
                wbs_ack       <= 1'b0;
            end
        end
    end
    
endmodule