module imem #(
    parameter SIZE_KB    = 8,           // 4KB memory (1024 * 32-bit words)
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n,
    
    // Wishbone Slave Interface for Instruction FETCH (CPU-side)
    input wire                      wbs_if_cyc,
    input wire                      wbs_if_stb,
    input wire                      wbs_if_we,
    input wire [ADDR_WIDTH-1:0]     wbs_if_addr,
    input wire [DATA_WIDTH-1:0]     wbs_if_data_write,
    input wire [3:0]                wbs_if_sel,
    output reg [DATA_WIDTH-1:0]     wbs_if_data_read,
    output reg                      wbs_if_ack,

    // Wishbone Slave Interface for Read-only data (System Bus-side)
    input wire                      wbs_ro_cyc,
    input wire                      wbs_ro_stb,
    input wire                      wbs_ro_we,
    input wire [ADDR_WIDTH-1:0]     wbs_ro_addr,
    input wire [DATA_WIDTH-1:0]     wbs_ro_data_write,
    input wire [3:0]                wbs_ro_sel,
    output reg [DATA_WIDTH-1:0]     wbs_ro_data_read,
    output reg                      wbs_ro_ack,

    // Direct initialization interface
    input wire                      init_en,
    input wire [ADDR_WIDTH-1:0]     init_addr,
    input wire [DATA_WIDTH-1:0]     init_data
);

    // Memory array (power-of-2 sized)
    localparam DEPTH = SIZE_KB * 1024 / 4;
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    wire [$clog2(DEPTH)-1:0] word_addr_if;
    wire [$clog2(DEPTH)-1:0] word_addr_ro;
    wire [$clog2(DEPTH)-1:0] init_word_addr;
    assign word_addr_if    = wbs_if_addr[$clog2(DEPTH)+1:2];
    assign word_addr_ro    = wbs_ro_addr[$clog2(DEPTH)+1:2];
    assign init_word_addr  = init_addr[$clog2(DEPTH)+1:2];



    // -------------------------------------------
    // Read Path (Synchronous)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_if_data_read <= {DATA_WIDTH{1'b0}};
        end else begin
            if (wbs_if_cyc && wbs_if_stb && !wbs_if_we) begin
                wbs_if_data_read <= mem[word_addr_if];
            end 
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_ro_data_read <= {DATA_WIDTH{1'b0}};
        end else begin
            if (wbs_ro_cyc && wbs_ro_stb && !wbs_ro_we) begin
                wbs_ro_data_read <= mem[word_addr_ro];
            end 
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
        else if((wbs_if_cyc && wbs_if_stb && wbs_if_we)) begin
            $display("[WARNING]: Attempted IMEM IF write at %h", wbs_if_addr);
        end
        // Hardware write protection (IMEM is read-only during operation)
        else if((wbs_ro_cyc && wbs_ro_stb && wbs_ro_we)) begin
            $display("[WARNING]: Attempted IMEM RO write at %h", wbs_if_addr);
        end
    end

    // -------------------------------------------
    // Acknowledge Generation (1-cycle pulse)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_if_ack <= 0;
        end else begin
            wbs_if_ack <= (wbs_if_cyc && wbs_if_stb);
        end
    end  

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_ro_ack <= 0;
        end else begin
            wbs_ro_ack <= (wbs_ro_cyc && wbs_ro_stb);
        end
    end  
endmodule