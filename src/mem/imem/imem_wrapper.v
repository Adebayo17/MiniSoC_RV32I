module imem_wrapper #(
    parameter BASE_ADDR  = 32'h0000_0000,
    parameter SIZE_KB    = 4,
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

    // Direct Initialization interface
    input wire                      init_en,
    input wire [ADDR_WIDTH-1:0]     init_addr,
    input wire [DATA_WIDTH-1:0]     init_data
);

    // -------------------------------------------
    // Temporary wishbone signal
    // -------------------------------------------
    wire                  tmp_wbs_ack;
    wire [DATA_WIDTH-1:0] tmp_wbs_data_read;

    // -------------------------------------------
    // Address Decoding
    // -------------------------------------------
    wire mem_select = (wbs_addr >= BASE_ADDR) && (wbs_addr < (BASE_ADDR + (SIZE_KB * 1024)));
    
    wire [ADDR_WIDTH-1:0] imem_wbs_addr, imem_init_addr;
    assign imem_wbs_addr = wbs_addr - BASE_ADDR;   // Offset addressing
    assign imem_init_addr = init_addr - BASE_ADDR;

    // -------------------------------------------
    // IMEM Instance
    // -------------------------------------------
    imem #(
        .SIZE_KB(SIZE_KB),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) imem_inst (
        .clk                (clk                  ),
        .rst_n              (rst_n                ),
        .wbs_cyc            (wbs_cyc && mem_select),
        .wbs_stb            (wbs_stb              ),
        .wbs_we             (wbs_we               ),
        .wbs_addr           (imem_wbs_addr        ),  
        .wbs_data_write     (wbs_data_write       ),
        .wbs_sel            (wbs_sel              ),
        .wbs_data_read      (tmp_wbs_data_read    ),
        .wbs_ack            (tmp_wbs_ack          ),
        .init_en            (init_en              ),
        .init_addr          (imem_init_addr       ),
        .init_data          (init_data            )
    );

    // -------------------------------------------
    // Error Handling
    // -------------------------------------------
    always @(posedge clk) begin
        if (wbs_cyc && wbs_stb && !mem_select) begin
            $display("Error: IMEM access out of bounds (%h)", wbs_addr);
            wbs_data_read <= 32'hBAD0_ADD0;  // Magic number for debug
            wbs_ack <= 1;
        end else begin
            wbs_data_read <= tmp_wbs_data_read;
            wbs_ack <= tmp_wbs_ack;
        end
    end
endmodule