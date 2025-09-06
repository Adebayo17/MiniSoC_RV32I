module uart_rx (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n,

    // Control  Signals
    input wire                      rx_enable,      // Receiver enable
    input wire [15:0]               baud_div,       // Baud rate divisor

    // Status Signal
    output reg                      rx_ready,       // Data available to read
    output reg                      rx_overrun,     // Overrun error (new data before previous read)
    output reg                      rx_frame_error, // Frame error (stop bit not detected)

    // Data output
    output reg [7:0]                rx_data,

    // UART Physical interface
    input wire                      uart_tx         // Serial Input
);
    
    // -------------------------------------------
    // Parameter Definitions
    // -------------------------------------------
    // Receiver states
    localparam [2:0] RX_IDLE  = 3'b000;
    localparam [2:0] RX_START = 3'b001;
    localparam [2:0] RX_DATA  = 3'b010;
    localparam [2:0] RX_STOP  = 3'b011;
    localparam [2:0] RX_ERROR = 3'b100;

    // -------------------------------------------
    // Internal Signals
    // -------------------------------------------
    reg [2:0]   rx_state;
    reg [2:0]   rx_bit_counter;
    reg [7:0]   rx_shift_reg;
    reg [15:0]  baud_counter;
    reg         baud_tick;
    reg         uart_rx_sync;
    reg         uart_rx_prev;

    // -------------------------------------------
    // Synchronization flip-flop for metastability protection
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_rx_sync <= 1'b1;
            uart_rx_prev <= 1'b1;
        end else begin
            uart_rx_prev <= uart_rx_sync;
            uart_rx_sync <= uart_rx;
        end
    end 

    // Edge detection for start bit
    wire rx_falling_edge = uart_rx_prev && !uart_rx_sync;

    // -------------------------------------------
    // Baud Rate Generator
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= 16'b0;
            baud_tick    <= 1'b0;
        end else begin
            baud_tick    <= 1'b0;
            if (rx_state != RX_IDLE) begin
                if (baud_counter == 16'b0) begin
                    baud_counter <= baud_div;
                    baud_tick    <= 1'b1;
                end else begin
                    baud_counter <= baud_counter - 1;
                end
            end else begin
                baud_counter <= baud_counter >> 1; // Sample at middle of bit
            end
        end
    end 

    // -------------------------------------------
    // Receiver State Machine
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state       <= TX_IDLE;
            rx_bit_counter <= 3'b0;
            rx_shift_reg   <= 8'b0;
            rx_data        <= 1'b0;
            rx_ready       <= 1'b1;
            rx_overrun     <= 1'b0;
            rx_frame_error <= 1'b0;
        end else begin
            // Clear single-cycle signal
            rx_overrun     <= 1'b0;
            rx_frame_error <= 1'b0;

            case (rx_state)
                RX_IDLE: begin
                    rx_ready <= 1'b0;

                    if (rx_enable && rx_falling_edge) begin
                        rx_state       <= RX_START;
                        rx_bit_counter <= 3'b0;
                    end
                end

                RX_START: begin
                    if (baud_tick) begin
                        // Verify start bit is still low (glitch protection)
                        if (uart_rx_sync == 1'b0) begin
                            rx_state <= RX_DATA;
                        end else begin
                            rx_state <= RX_ERROR;
                        end
                    end
                end

                RX_DATA: begin
                    if (baud_tick) begin
                        rx_shift_reg <= {uart_rx_sync, rx_shift_reg[7:1]}; // Shift in MSB first

                        if (rx_bit_counter == 3'd7) begin
                            rx_state <= rX_STOP;
                        end else begin
                            rx_bit_counter <= rx_bit_counter + 1;
                        end
                    end
                end

                RX_STOP: begin
                    if (baud_tick) begin
                        // Check stop bit (should be high)
                        if (uart_rx_sync == 1'b1) begin
                            rx_data <= rx_shift_reg;
                            rx_ready <= 1'b1;
                            rx_state <= RX_IDLE;
                        end else begin
                            rx_state <= RX_ERROR;
                        end 
                    end
                end 

                RX_ERROR: begin
                    rx_frame_error <= 1'b1;
                    rx_state       <= RX_IDLE;
                end
            endcase

            // Overrun detection: new data arrives before previous data is read 
            if (rx_ready && rx_state == RX_START) begin
                rx_overrun <= 1'b1;
            end
        end
    end
endmodule