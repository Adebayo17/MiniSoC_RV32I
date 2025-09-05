module dmem #(
    parameter SIZE_KB    = 4,           // 4KB memory (1024 * 32-bit words)
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

    // -------------------------------------------
    // Internal state
    // -------------------------------------------

    // Memory array (power-of-2 sized)
    localparam DEPTH = SIZE_KB * 1024 / 4;
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    wire [$clog2(DEPTH)-1:0] word_addr;
    wire [$clog2(DEPTH)-1:0] init_word_addr;
    assign word_addr      = wbs_addr[$clog2(DEPTH)+1:2];
    assign init_word_addr = init_addr[$clog2(DEPTH)+1:2];

    reg tmp_r_ack = 0;
    reg tmp_w_ack = 0;

    // -------------------------------------------
    // Read Path (Synchronus)
    // -------------------------------------------
    always @(posedge clk) begin
        if (wbs_cyc && wbs_stb && !wbs_we) begin
            wbs_data_read <= mem[word_addr];
            tmp_r_ack     <= 1;
        end else begin
            wbs_data_read <= 0;
            tmp_r_ack     <= 0;
        end
    end

    // -------------------------------------------
    // Write Path (Synchronus)
    // -------------------------------------------
    always @(posedge clk) begin
        if (init_en) begin
            mem[init_word_addr] <= init_data;
            $display("[INFO]: DMEM init mem at @ %h with %h", init_word_addr, init_data);
        end else if(wbs_cyc && wbs_stb && wbs_we) begin
            // Runtime writes with byte select
            if (wbs_sel[0])   mem[word_addr][7:0]    <= wbs_data_write[7:0]  ;
            if (wbs_sel[1])   mem[word_addr][15:8]   <= wbs_data_write[15:8] ;
            if (wbs_sel[2])   mem[word_addr][23:16]  <= wbs_data_write[23:16];
            if (wbs_sel[3])   mem[word_addr][31:24]  <= wbs_data_write[31:24];
            tmp_w_ack     <= 1;
        end else begin
            tmp_w_ack     <= 0;
        end
    end


    // -------------------------------------------
    // Acknowledge Generation (1-cycle pulse)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_ack <= 0;
        end else begin
            wbs_ack <= (wbs_cyc && wbs_stb && (tmp_r_ack || tmp_w_ack));
        end
    end 
endmodule