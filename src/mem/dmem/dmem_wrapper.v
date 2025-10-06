module dmem_wrapper #(
    parameter BASE_ADDR  = 32'h1000_0000,
    parameter SIZE_KB    = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset
    input   wire                      clk,
    input   wire                      rst_n,

    // Wishbone Slave Interface
    input   wire                      wbs_cyc,
    input   wire                      wbs_stb,
    input   wire                      wbs_we,
    input   wire [ADDR_WIDTH-1:0]     wbs_addr,
    input   wire [DATA_WIDTH-1:0]     wbs_data_write,
    input   wire [3:0]                wbs_sel,
    output  wire [DATA_WIDTH-1:0]     wbs_data_read,
    output  wire                      wbs_ack,

    // Direct Initialization Port
    input   wire                      init_en,
    input   wire [ADDR_WIDTH-1:0]     init_addr,
    input   wire [DATA_WIDTH-1:0]     init_data
);

    // ----------------------------
    // Address Decoding
    // ----------------------------
    wire mem_select  = (wbs_addr >= BASE_ADDR) && (wbs_addr < BASE_ADDR + (SIZE_KB * 1024));
    wire init_select = (init_addr >= BASE_ADDR) && (init_addr < BASE_ADDR + (SIZE_KB * 1024));

    wire [ADDR_WIDTH-1:0] dmem_wbs_addr, dmem_init_addr;
    assign dmem_wbs_addr  = wbs_addr  - BASE_ADDR;   // Offset addressing
    assign dmem_init_addr = init_addr - BASE_ADDR;

    // ----------------------------
    // DMEM Instance
    // ----------------------------
    dmem #(
        .SIZE_KB(SIZE_KB),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dmem_inst (
        .clk                    (clk                    ),
        .rst_n                  (rst_n                  ),
        .wbs_cyc                (wbs_cyc && mem_select  ),
        .wbs_stb                (wbs_stb && mem_select  ),
        .wbs_we                 (wbs_we                 ),
        .wbs_addr               (dmem_wbs_addr          ), 
        .wbs_data_write         (wbs_data_write         ),
        .wbs_sel                (wbs_sel                ),
        .wbs_data_read          (wbs_data_read          ),
        .wbs_ack                (wbs_ack                ),
        .init_en                (init_en && init_select ),
        .init_addr              (dmem_init_addr         ),
        .init_data              (init_data              )
    );
endmodule