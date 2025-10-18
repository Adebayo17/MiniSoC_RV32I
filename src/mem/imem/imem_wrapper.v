module imem_wrapper #(
    parameter BASE_ADDR  = 32'h0000_0000,
    parameter SIZE_KB    = 8,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset
    input   wire                      clk,
    input   wire                      rst_n,

    // Wishbone Slave Interface for Instruction FETCH (CPU-side)
    input   wire                      wbs_if_cyc,
    input   wire                      wbs_if_stb,
    input   wire                      wbs_if_we,
    input   wire [ADDR_WIDTH-1:0]     wbs_if_addr,
    input   wire [DATA_WIDTH-1:0]     wbs_if_data_write,
    input   wire [3:0]                wbs_if_sel,
    output  wire [DATA_WIDTH-1:0]     wbs_if_data_read,
    output  wire                      wbs_if_ack,

    // Wishbone Slave Interface for Read-only data (System Bus-side)
    input   wire                      wbs_ro_cyc,
    input   wire                      wbs_ro_stb,
    input   wire                      wbs_ro_we,
    input   wire [ADDR_WIDTH-1:0]     wbs_ro_addr,
    input   wire [DATA_WIDTH-1:0]     wbs_ro_data_write,
    input   wire [3:0]                wbs_ro_sel,
    output  wire [DATA_WIDTH-1:0]     wbs_ro_data_read,
    output  wire                      wbs_ro_ack,

    // Direct Initialization interface
    input   wire                      init_en,
    input   wire [ADDR_WIDTH-1:0]     init_addr,
    input   wire [DATA_WIDTH-1:0]     init_data
);

    // -------------------------------------------
    // Address Decoding
    // -------------------------------------------
    wire mem_select_if  = (wbs_if_addr >= BASE_ADDR) && (wbs_if_addr < (BASE_ADDR + (SIZE_KB * 1024)));
    wire mem_select_ro  = (wbs_ro_addr >= BASE_ADDR) && (wbs_ro_addr < (BASE_ADDR + (SIZE_KB * 1024)));
    wire init_select    = (init_addr >= BASE_ADDR) && (init_addr < BASE_ADDR + (SIZE_KB * 1024));
    
    wire [ADDR_WIDTH-1:0] imem_wbs_if_addr, imem_wbs_ro_addr, imem_init_addr;
    assign imem_wbs_if_addr = wbs_if_addr - BASE_ADDR;   // Offset addressing
    assign imem_wbs_ro_addr = wbs_ro_addr - BASE_ADDR;   // Offset addressing
    assign imem_init_addr = init_addr - BASE_ADDR;

    // -------------------------------------------
    // IMEM Instance
    // -------------------------------------------
    imem #(
        .SIZE_KB(SIZE_KB),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) imem_inst (
        .clk                    (clk                            ),
        .rst_n                  (rst_n                          ),
        .wbs_if_cyc             (wbs_if_cyc && mem_select_if    ),
        .wbs_if_stb             (wbs_if_stb && mem_select_if    ),
        .wbs_if_we              (wbs_if_we                      ),
        .wbs_if_addr            (imem_wbs_if_addr               ),
        .wbs_if_data_write      (wbs_if_data_write              ),
        .wbs_if_sel             (wbs_if_sel                     ),
        .wbs_if_data_read       (wbs_if_data_read               ),
        .wbs_if_ack             (wbs_if_ack                     ),
        .wbs_ro_cyc             (wbs_ro_cyc && mem_select_ro    ),
        .wbs_ro_stb             (wbs_ro_stb && mem_select_ro    ),
        .wbs_ro_we              (wbs_ro_we                      ),
        .wbs_ro_addr            (imem_wbs_ro_addr               ),
        .wbs_ro_data_write      (wbs_ro_data_write              ),
        .wbs_ro_sel             (wbs_ro_sel                     ),
        .wbs_ro_data_read       (wbs_ro_data_read               ),
        .wbs_ro_ack             (wbs_ro_ack                     ),
        .init_en                (init_en && init_select         ),
        .init_addr              (imem_init_addr                 ),
        .init_data              (init_data                      )
    );
endmodule