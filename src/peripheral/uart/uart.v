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

    // Status register bits
    localparam STATUS_TX_EMPTY      = 0;
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

    // Transmitter control signals
    reg  tx_start_pulse;
    wire tx_busy;
    wire tx_empty;
    wire tx_done;

    // Receiver signals
    wire        rx_ready;
    wire        rx_overrun;
    wire        rx_frame_error;
    wire [7:0]  rx_data;

    // -------------------------------------------
    // Address Decoding
    // -------------------------------------------
    wire [11:0] reg_offset;
    assign reg_offset = wbs_addr[11:0];

    wire sel_tx_data    = (reg_offset == 12'h000);
    wire sel_rx_data    = (reg_offset == 12'h004);
    wire sel_baud_div   = (reg_offset == 12'h008);
    wire sel_ctrl       = (reg_offset == 12'h00C);
    wire sel_status     = (reg_offset == 12'h010);

    // -------------------------------------------
    // Wishbone tmp ACK
    // -------------------------------------------
    reg tmp_r_ack;
    reg tmp_w_ack;

    // -------------------------------------------
    // Wishbone Read
    // -------------------------------------------
    always @(*) begin
        wbs_data_read = 32'b0;
        tmp_r_ack     = 0;
        if (wbs_cyc && wbs_stb && !wbs_we) begin
            tmp_r_ack = 1'b1;

            case (reg_offset)
                12'h000:    wbs_data_read = {24'b0, tx_data_reg};
                12'h004:    wbs_data_read = {24'b0, rx_data_reg};
                12'h008:    wbs_data_read = {16'b0, baud_div_reg};
                12'h00C:    wbs_data_read = {24'b0, ctrl_reg};
                12'h010:   wbs_data_read = {24'b0, status_reg};
                default: wbs_data_read = 32'b0;
            endcase
        end else begin
            wbs_data_read = 32'b0;
            tmp_r_ack     = 0;
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
            tmp_w_ack       <= 0;
            tx_start_pulse  <= 1'b0;
        end else begin
            tmp_w_ack       <= 0;

            // Capture received data
            if (rx_ready) begin
                rx_data_reg <= rx_data;
            end

            if (wbs_cyc && wbs_stb && wbs_we) begin
                tmp_w_ack      <= 1'b1;
                tx_start_pulse <= 1'b0;     // Single pulse

                case (reg_offset)
                    12'h000: begin
                        if (wbs_sel[0]) begin
                            tx_data_reg    <= wbs_data_write[7:0];
                            tx_start_pulse <= 1'b1;  // Start transmission
                        end 
                    end
                    12'h004: begin
                        // Reading RX data register clears RX ready flag
                        if (wbs_sel[0]) begin
                            rx_data_reg <= 8'b0; // Cleared after read
                        end
                    end
                    12'h008: begin
                        if (wbs_sel[0]) baud_div_reg[7:0]  <= wbs_data_write[7:0];
                        if (wbs_sel[1]) baud_div_reg[15:8] <= wbs_data_write[15:8];
                    end
                    12'h00C: if (wbs_sel[0]) ctrl_reg <= wbs_data_write[7:0];
                endcase
            end
        end
    end

    // -------------------------------------------
    // Wishbone ACK
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_ack <= 0;
        end else begin
            wbs_ack <= (wbs_cyc && wbs_stb && (tmp_w_ack || tmp_r_ack));
        end
    end 

    // -------------------------------------------
    // UART Transmitter Logic
    // -------------------------------------------
    uart_tx uart_tx_inst (
        .clk            (clk                        ),
        .rst_n          (rst_n                      ),
        .tx_enable      (ctrl_reg[CTRL_TX_ENABLE]   ),
        .tx_data        (tx_data_reg                ),
        .tx_start       (tx_start_pulse             ),
        .baud_div       (baud_div_reg               ),
        .tx_busy        (tx_busy                    ),
        .tx_empty       (tx_empty                   ),
        .tx_done        (tx_done                    ),
        .uart_tx        (uart_tx                    )
    );

    // -------------------------------------------
    // UART Receiver Logic
    // -------------------------------------------
    uart_rx uart_rx_inst (
        .clk            (clk                        ),
        .rst_n          (rst_n                      ),
        .rx_enable      (ctrl_reg[CTRL_RX_ENABLE]   ),
        .baud_div       (baud_div_reg               ),
        .rx_ready       (rx_ready                   ),
        .rx_overrun     (rx_overrun                 ),
        .rx_frame_error (rx_frame_error             ),
        .rx_data        (rx_data                    ),
        .uart_rx        (uart_rx                    )
    );

    // -------------------------------------------
    // Status Register Update
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_reg <= 8'b00000001;
        end else begin
            // Update TX status from transmitter
            status_reg[STATUS_TX_EMPTY]     <= tx_empty;
            status_reg[STATUS_TX_BUSY]      <= tx_busy;

            // Update RX status from receiver
            status_reg[STATUS_RX_READY]     <= rx_ready;
            status_reg[STATUS_RX_OVERRUN]   <= rx_overrun;
            status_reg[STATUS_RX_FRAME_ERR] <= rx_frame_error;

            // Clear RX_READY when RX data register is read
            if (wbs_cyc && wbs_stb && !wbs_we && sel_rx_data) begin
                status_reg[STATUS_RX_READY]     <= 1'b0;
            end

            // Clear error flags on read
            if (wbs_cyc && wbs_stb && !wbs_we && sel_status) begin
                status_reg[STATUS_RX_OVERRUN] <= 1'b0;
                status_reg[STATUS_RX_FRAME_ERR] <= 1'b0;
            end
        end 
    end
    
endmodule