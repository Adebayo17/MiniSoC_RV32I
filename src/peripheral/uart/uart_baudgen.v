module uart_baudgen (
    // Clock and reset 
    input wire                      clk,
    input wire                      rst_n,

    // Control Signals
    input wire                      enable,
    input wire [15:0]               baud_div,

    // Output
    output reg                      baud_tick
);

    // -------------------------------------------
    // Internal Signals
    // -------------------------------------------
    reg [15:0] baud_counter;

    // -------------------------------------------
    // Baud Rate Generator
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= baud_div;
            baud_tick    <= 1'b0;
        end else begin
            baud_tick    <= 1'b0;

            if (enable) begin
                if (baud_counter == 16'b0) begin
                    baud_counter <= baud_div;
                    baud_tick    <= 1'b1;
                end else begin
                    baud_counter <= baud_counter - 1;
                end
            end else begin
                baud_counter <= baud_div; // Preload when disabled
                baud_tick    <= 1'b0;
            end
        end
    end 
endmodule