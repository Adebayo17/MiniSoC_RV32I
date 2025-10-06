module imem #(
    parameter SIZE_KB    = 8,           // 4KB memory (1024 * 32-bit words)
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
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

    // Direct initialization interface
    input wire                      init_en,
    input wire [ADDR_WIDTH-1:0]     init_addr,
    input wire [DATA_WIDTH-1:0]     init_data
);

    // Memory array (power-of-2 sized)
    localparam DEPTH = SIZE_KB * 1024 / 4;
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    wire [$clog2(DEPTH)-1:0] word_addr;
    wire [$clog2(DEPTH)-1:0] init_word_addr;
    assign word_addr      = wbs_addr[$clog2(DEPTH)+1:2];
    assign init_word_addr = init_addr[$clog2(DEPTH)+1:2];



    // -------------------------------------------
    // Read Path (Synchronous)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_data_read <= {DATA_WIDTH{1'b0}};
        end else begin
            if (wbs_cyc && wbs_stb && !wbs_we) begin
                wbs_data_read <= mem[word_addr];
            end 
            // else begin
            //     wbs_data_read <= {DATA_WIDTH{1'b0}};
            // end
        end
    end

    // -------------------------------------------
    // Write Path (Initialization only)
    // -------------------------------------------
    always @(posedge clk) begin
        if (init_en) begin
            mem[init_word_addr] <= init_data;
            `ifdef DEBUG
            $display("[DEBUG]: IMEM init mem at @ %h with %h", init_word_addr, init_data);
            `endif
        end 
        // Hardware write protection (IMEM is read-only during operation)
        else if(wbs_cyc && wbs_stb && wbs_we) begin
            $display("[WARNING]: Attempted IMEM write at %h", wbs_addr);
        end
    end

    // -------------------------------------------
    // Acknowledge Generation (1-cycle pulse)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_ack <= 0;
        end else begin
            wbs_ack <= (wbs_cyc && wbs_stb);
        end
    end  
endmodule