module timer_wrapper #(
    parameter BASE_ADDR  = 32'h3000_0000,
    parameter SIZE_KB    = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset
    input   wire                      clk,
    input   wire                      rst_n,

    // Wishbone Slave Interface
    input   wire                      wbs_cyc,
    input   wire                      wbs_stb,
    input   wire                      wbs_we,
    input   wire [ADDR_WIDTH-1:0]     wbs_addr,
    input   wire [DATA_WIDTH-1:0]     wbs_data_write,
    input   wire [3:0]                wbs_sel,
    output  wire [DATA_WIDTH-1:0]     wbs_data_read,
    output  wire                      wbs_ack
);

    // ----------------------------
    // Address Decoding
    // ----------------------------
    wire timer_select = (wbs_addr >= BASE_ADDR) && (wbs_addr < BASE_ADDR + (SIZE_KB * 1024));

    // ----------------------------
    // Timer Instance
    // ----------------------------
    timer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) timer_inst (
        .clk                (clk                        ),
        .rst_n              (rst_n                      ),
        .wbs_cyc            (wbs_cyc && timer_select    ),
        .wbs_stb            (wbs_stb && timer_select    ),
        .wbs_we             (wbs_we                     ),
        .wbs_addr           (wbs_addr                   ),
        .wbs_data_write     (wbs_data_write             ),
        .wbs_sel            (wbs_sel                    ),
        .wbs_data_read      (wbs_data_read              ),
        .wbs_ack            (wbs_ack                    )
    );
endmodule