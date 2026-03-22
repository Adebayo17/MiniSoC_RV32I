module uart #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter BAUD_DIV_RST = 16'd104                // 115200 baud @ 12MHz
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
    // Parameter Definitions
    // -------------------------------------------
    // Register Address
    localparam [11:0] REG_UART_TX_DATA     = 12'h000;
    localparam [11:0] REG_UART_RX_DATA     = 12'h004;
    localparam [11:0] REG_UART_BAUD_DIV    = 12'h008;
    localparam [11:0] REG_UART_CTRL        = 12'h00C;
    localparam [11:0] REG_UART_STATUS      = 12'h010;

    // Status register bits
    localparam STATUS_TX_READY      = 0;
    localparam STATUS_TX_BUSY       = 1;
    localparam STATUS_RX_READY      = 2;
    localparam STATUS_RX_OVERRUN    = 3;
    localparam STATUS_RX_FRAME_ERR  = 4;

    // Control register bits
    localparam CTRL_TX_ENABLE       = 0;
    localparam CTRL_RX_ENABLE       = 1;

    // -------------------------------------------
    // Register Definitions
    // -------------------------------------------
    reg [7:0]  tx_data_reg;
    reg [7:0]  rx_data_reg;
    reg [15:0] baud_div_reg;
    reg [7:0]  ctrl_reg;
    reg [7:0]  status_reg;

    // Baud generator
    wire baud_tick;

    // Transmitter control signals
    reg  tx_start_pulse;
    wire tx_busy;
    wire tx_ready;

    // Receiver signals
    wire        rx_ready;
    wire        rx_overrun;
    wire        rx_frame_error;
    wire [7:0]  rx_data;

    // Operation flags
    wire read_op  = wbs_cyc && wbs_stb && !wbs_we;
    wire write_op = wbs_cyc && wbs_stb && wbs_we;

    // Read Detection signals
    wire status_read  = read_op && sel_status;
    wire rx_data_read = read_op && sel_rx_data;

    // -------------------------------------------
    // Address Decoding
    // -------------------------------------------
    wire [11:0] reg_offset;
    assign reg_offset = wbs_addr[11:0];

    wire sel_tx_data    = (reg_offset == REG_UART_TX_DATA   );
    wire sel_rx_data    = (reg_offset == REG_UART_RX_DATA   );
    wire sel_baud_div   = (reg_offset == REG_UART_BAUD_DIV  );
    wire sel_ctrl       = (reg_offset == REG_UART_CTRL      );
    wire sel_status     = (reg_offset == REG_UART_STATUS    );


    // -------------------------------------------
    // Wishbone Read
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_data_read <= {DATA_WIDTH{1'b0}};
        end else begin
            if (wbs_cyc && wbs_stb && !wbs_we) begin
                case (reg_offset)
                    REG_UART_TX_DATA:   wbs_data_read <= {24'b0, tx_data_reg};
                    REG_UART_RX_DATA:   wbs_data_read <= {24'b0, rx_data_reg};
                    REG_UART_BAUD_DIV:  wbs_data_read <= {16'b0, baud_div_reg};
                    REG_UART_CTRL:      wbs_data_read <= {24'b0, ctrl_reg};
                    REG_UART_STATUS:    wbs_data_read <= {24'b0, status_reg};
                    default:            wbs_data_read <= {DATA_WIDTH{1'b0}};
                endcase
            end 
        end
    end

    // -------------------------------------------
    // Wishbone Write
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data_reg     <= 8'b0;
            rx_data_reg     <= 8'b0;
            baud_div_reg    <= BAUD_DIV_RST;     
            ctrl_reg        <= 8'b00000011; // Enable TX and RX
            status_reg      <= 8'b00000001; // TX empty, RX not ready
            tx_start_pulse  <= 1'b0;
        end else begin
            tx_start_pulse  <= 1'b0;     // Single pulse

            // Capture received data
            if (rx_ready && !status_reg[STATUS_RX_READY]) begin
                rx_data_reg <= rx_data;
            end

            if (wbs_cyc && wbs_stb && wbs_we) begin
                tx_start_pulse <= 1'b0;     // Single pulse

                case (reg_offset)
                    REG_UART_TX_DATA: begin
                        if (wbs_sel[0]) begin
                            tx_data_reg    <= wbs_data_write[7:0];
                            tx_start_pulse <= 1'b1;  // Start transmission
                        end 
                    end
                    REG_UART_RX_DATA: begin
                        // Reading RX data register clears RX ready flag
                        if (wbs_sel[0]) begin
                            rx_data_reg <= 8'b0; // Cleared after read
                        end
                    end
                    REG_UART_BAUD_DIV: begin
                        if (wbs_sel[0]) baud_div_reg[7:0]  <= wbs_data_write[7:0];
                        if (wbs_sel[1]) baud_div_reg[15:8] <= wbs_data_write[15:8];
                    end
                    REG_UART_CTRL: if (wbs_sel[0]) ctrl_reg <= wbs_data_write[7:0];
                endcase
            end
        end
    end

    // -------------------------------------------
    // Wishbone ACK
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wbs_ack <= 1'b0;
        else begin
            // Generate ACK only if a valid request is present 
            // AND we haven't already ack'd it
            if (wbs_cyc && wbs_stb && !wbs_ack) begin
                wbs_ack <= 1'b1;
            end else begin
                wbs_ack <= 1'b0;
            end
            // wbs_ack <= (wbs_cyc && wbs_stb);
        end
    end

    // -------------------------------------------
    // Baud Generator
    // -------------------------------------------
    uart_baudgen uart_baudgen_inst (
        .clk            (clk                                                    ),
        .rst_n          (rst_n                                                  ),
        .enable         (ctrl_reg[CTRL_TX_ENABLE] || ctrl_reg[CTRL_RX_ENABLE]   ),
        .baud_div       (baud_div_reg                                           ),
        .baud_tick      (baud_tick                                              )
    );

    // -------------------------------------------
    // UART Transmitter Logic
    // -------------------------------------------
    uart_tx uart_tx_inst (
        .clk            (clk                        ),
        .rst_n          (rst_n                      ),
        .tx_enable      (ctrl_reg[CTRL_TX_ENABLE]   ),
        .tx_data        (tx_data_reg                ),
        .tx_start       (tx_start_pulse             ),
        .baud_tick      (baud_tick                  ),
        .tx_busy        (tx_busy                    ),
        .tx_ready       (tx_ready                   ),
        .uart_tx        (uart_tx                    )
    );

    // -------------------------------------------
    // UART Receiver Logic
    // -------------------------------------------
    uart_rx uart_rx_inst (
        .clk            (clk                        ),
        .rst_n          (rst_n                      ),
        .rx_enable      (ctrl_reg[CTRL_RX_ENABLE]   ),
        .baud_tick      (baud_tick                  ),
        .rx_clear       (rx_data_read               ),
        .rx_ready       (rx_ready                   ),
        .rx_overrun     (rx_overrun                 ),
        .rx_frame_error (rx_frame_error             ),
        .rx_data        (rx_data                    ),
        .uart_rx        (uart_rx                    )
    );

    // -------------------------------------------
    // Status Register Update (Read-to-Clear Logic)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_reg <= 8'b00000001;
        end else begin
            // Update TX status from transmitter
            status_reg[STATUS_TX_READY]     <= tx_ready;
            status_reg[STATUS_TX_BUSY]      <= tx_busy;

            // Capture RX ready state (set when new data arrives)
            if (rx_ready && !status_reg[STATUS_RX_READY]) begin
                status_reg[STATUS_RX_READY] <= 1'b1;
            end

            // Capture error pulses
            if (rx_overrun) begin
                status_reg[STATUS_RX_OVERRUN] <= 1'b1;
            end
            
            if (rx_frame_error) begin
                status_reg[STATUS_RX_FRAME_ERR] <= 1'b1;
            end

            // Clear RX_READY when RX data register is read
            if (rx_data_read) begin
                status_reg[STATUS_RX_READY] <= 1'b0;
            end

            // Clear error flags when status register is read
            if (status_read) begin
                status_reg[STATUS_RX_OVERRUN] <= 1'b0;
                status_reg[STATUS_RX_FRAME_ERR] <= 1'b0;
            end

            // Update RX status from receiver
            // status_reg[STATUS_RX_READY]     <= rx_ready;
            // status_reg[STATUS_RX_OVERRUN]   <= rx_overrun;
            // status_reg[STATUS_RX_FRAME_ERR] <= rx_frame_error;
        end 
    end
    
endmodule