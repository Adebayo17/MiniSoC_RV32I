module gpio_wrapper #(
    parameter BASE_ADDR     = 32'h4000_0000,
    parameter SIZE_KB       = 4,
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 32,
    parameter N_GPIO        = 8
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

    // GPIO Physical Interface
    input wire  [N_GPIO-1:0]        gpio_in,        // GPIO input pins
    output wire [N_GPIO-1:0]        gpio_out,       // GPIO output pins
    output wire [N_GPIO-1:0]        gpio_oe         // GPIO output enable (1=output, 0= input)
);

    // -------------------------------------------
    // Temporary wishbone signal
    // -------------------------------------------
    wire                  tmp_wbs_ack;
    wire [DATA_WIDTH-1:0] tmp_wbs_data_read;

    // ----------------------------
    // Address Decoding
    // ----------------------------
    wire gpio_select = (wbs_addr >= BASE_ADDR) && (wbs_addr < BASE_ADDR + (SIZE_KB * 1024));


    // GPIO instance
    gpio #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .N_GPIO(N_GPIO)
    ) gpio_inst (
        .clk                (clk                    ),
        .rst_n              (rst_n                  ),
        .wbs_cyc            (wbs_cyc && gpio_select ),
        .wbs_stb            (wbs_stb && gpio_select ),
        .wbs_we             (wbs_we                 ),
        .wbs_addr           (wbs_addr               ),
        .wbs_data_write     (wbs_data_write         ),
        .wbs_sel            (wbs_sel                ),
        .wbs_data_read      (tmp_wbs_data_read      ),
        .wbs_ack            (tmp_wbs_ack            ),
        .gpio_in            (gpio_in                ),
        .gpio_out           (gpio_out               ),
        .gpio_oe            (gpio_oe                )
    );

    // ----------------------------
    // ACK and Data Read Handling
    // ----------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            wbs_data_read <= {DATA_WIDTH{1'b0}};
            wbs_ack       <= 1'b0;
        end else begin
            if (gpio_select) begin
                wbs_data_read <= tmp_wbs_data_read;
                wbs_ack       <= tmp_wbs_ack;
            end else begin
                wbs_ack       <= 1'b0;
            end
        end
    end
    
endmodule