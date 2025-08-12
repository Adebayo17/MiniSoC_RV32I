module moduleName #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter SIZE_KB    = 4
) (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n
);
    
    // ----------------------------
    // Parameters
    // ----------------------------
    localparam [31:0] IMEM_BASE_ADDR = 32'h0000_0000;
    localparam [31:0] DMEM_BASE_ADDR = 32'h1000_0000;

    // ----------------------------
    // Wires and Reg
    // ----------------------------
    // MEM_INIT Instance: init_controller
    wire                      init_start;
    wire                      init_done;
    wire                      imem_init_en;
    wire [ADDR_WIDTH-1:0]     imem_init_addr;
    wire [DATA_WIDTH-1:0]     imem_init_data;
    wire                      dmem_init_en;
    wire [ADDR_WIDTH-1:0]     dmem_init_addr;
    wire [DATA_WIDTH-1:0]     dmem_init_data;

    // IMEM Instance: imem_inst
    wire                      wbs_imem_cyc       ;
    wire                      wbs_imem_stb       ;
    wire                      wbs_imem_we        ;
    wire [ADDR_WIDTH-1:0]     wbs_imem_addr      ;
    wire [DATA_WIDTH-1:0]     wbs_imem_data_write;
    wire [3:0]                wbs_imem_sel       ;
    wire [DATA_WIDTH-1:0]     wbs_imem_data_read ;
    wire                      wbs_imem_ack       ;

    // DMEM Instance: dmem_inst
    wire                      wbs_dmem_cyc       ;
    wire                      wbs_dmem_stb       ;
    wire                      wbs_dmem_we        ;
    wire [ADDR_WIDTH-1:0]     wbs_dmem_addr      ;
    wire [DATA_WIDTH-1:0]     wbs_dmem_data_write;
    wire [3:0]                wbs_dmem_sel       ;
    wire [DATA_WIDTH-1:0]     wbs_dmem_data_read ;
    wire                      wbs_dmem_ack       ;


    // CPU Instance

    // ----------------------------
    // MEM_INIT Instance
    // ----------------------------
    mem_init init_controller(
        .clk                (clk           ),
        .rst_n              (rst_n         ),
        .init_start         (~rst_n        ),   // Auto-start after reset
        .init_done          (init_done     ),
        .imem_init_en       (imem_init_en  ),
        .imem_init_addr     (imem_init_addr),
        .imem_init_data     (imem_init_data),
        .dmem_init_en       (dmem_init_en  ),
        .dmem_init_addr     (dmem_init_addr),
        .dmem_init_data     (dmem_init_data)
    );

    // ----------------------------
    // IMEM Instance
    // ----------------------------
    imem_wrapper #(
        .BASE_ADDR  (IMEM_BASE_ADDR ),
        .SIZE_KB    (SIZE_KB        ),
        .ADDR_WIDTH (ADDR_WIDTH     ),
        .DATA_WIDTH (DATA_WIDTH     )
    ) imem_inst (
        .clk                (clk                  ),
        .rst_n              (rst_n                ),
        .wbs_cyc            (wbs_imem_cyc         ),
        .wbs_stb            (wbs_imem_stb         ),
        .wbs_we             (wbs_imem_we          ),
        .wbs_addr           (wbs_imem_addr        ),  
        .wbs_data_write     (wbs_imem_data_write  ),
        .wbs_sel            (wbs_imem_sel         ),
        .wbs_data_read      (wbs_imem_data_read   ),
        .wbs_ack            (wbs_imem_ack         ),
        .init_en            (imem_init_en         ),
        .init_addr          (imem_init_addr       ),
        .init_data          (imem_init_data       )
    );


    // ----------------------------
    // DMEM Instance
    // ----------------------------
    dmem_wrapper #(
        .BASE_ADDR  (DMEM_BASE_ADDR ),
        .SIZE_KB    (SIZE_KB        ),
        .ADDR_WIDTH (ADDR_WIDTH     ),
        .DATA_WIDTH (DATA_WIDTH     )
    ) dmem_inst (
        .clk                (clk                  ),
        .rst_n              (rst_n                ),
        .wbs_cyc            (wbs_dmem_cyc         ),
        .wbs_stb            (wbs_dmem_stb         ),
        .wbs_we             (wbs_dmem_we          ),
        .wbs_addr           (wbs_dmem_addr        ),  
        .wbs_data_write     (wbs_dmem_data_write  ),
        .wbs_sel            (wbs_dmem_sel         ),
        .wbs_data_read      (wbs_dmem_data_read   ),
        .wbs_ack            (wbs_dmem_ack         ),
        .init_en            (dmem_init_en         ),
        .init_addr          (dmem_init_addr       ),
        .init_data          (dmem_init_data       )
    );

    // ----------------------------
    // CPU Instance
    // ----------------------------
    reg cpu_rst_n;
    always @(posedge clk) begin
        cpu_rst_n <= rst_n && init_done;
    end

endmodule