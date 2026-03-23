module uart_tx (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n,

    // Control  Signals
    input wire                      tx_enable,      // Transmitter enable
    input wire [7:0]                tx_data,        // Data to transmit
    input wire                      tx_start,       // Start transmission pulse
    input wire                      baud_tick,      // Baud Tick

    // Status Signal
    output reg                      tx_busy,        // Transmission in progress
    output reg                      tx_ready,       // Transmitter ready for new data

    // UART Physical interface
    output reg                      uart_tx         // Serial Output
);
    
    // -------------------------------------------
    // Parameter Definitions
    // -------------------------------------------
    // Transmitter states
    localparam [1:0] TX_IDLE  = 2'b00;
    localparam [1:0] TX_START = 2'b01;
    localparam [1:0] TX_DATA  = 2'b10;
    localparam [1:0] TX_STOP  = 2'b11;

    // -------------------------------------------
    // Internal Signals
    // -------------------------------------------
    reg [1:0]   tx_state;
    reg [2:0]   tx_bit_counter;
    reg [7:0]   tx_shift_reg;


    // -------------------------------------------
    // Transmitter State Machine
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state         <= TX_IDLE;
            uart_tx          <= 1'b1;
            tx_bit_counter   <= 3'b0;
            tx_shift_reg     <= 8'b0;
            tx_busy          <= 1'b0;
            tx_ready         <= 1'b1;
        end else begin

            case (tx_state)
                TX_IDLE: begin
                    uart_tx        <= 1'b1;
                    tx_busy        <= 1'b0;

                    if (tx_enable && tx_start) begin
                        tx_state     <= TX_START;
                        tx_shift_reg <= tx_data;
                        tx_busy      <= 1'b1;
                        tx_ready     <= 1'b0;
                    end
                end

                TX_START: begin
                    if (baud_tick) begin
                        uart_tx        <= 1'b0;  // Start bit
                        tx_state       <= TX_DATA;
                        tx_bit_counter <= 3'b0;
                    end
                end

                TX_DATA: begin
                    if (baud_tick) begin
                        uart_tx      <= tx_shift_reg[0]; // Send LSB first
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]}; // Shift right

                        if (tx_bit_counter == 3'd7) begin
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bit_counter <= tx_bit_counter + 1;
                        end
                    end
                end

                TX_STOP: begin
                    if (baud_tick) begin
                        uart_tx        <= 1'b1;
                        tx_state       <= TX_IDLE;
                        tx_busy        <= 1'b0;
                        tx_ready       <= 1'b1;
                    end
                end 
            endcase
        end
    end
endmodule