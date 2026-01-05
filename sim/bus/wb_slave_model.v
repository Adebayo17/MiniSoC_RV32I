module wb_slave_model #(
    parameter SLAVE_ID   = 0,
    parameter BASE_ADDR  = 32'h0000_0000,
    parameter SIZE_KB    = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,

    // Wishbone Interface
    input wire                      wb_cyc_i,
    input wire                      wb_stb_i,
    input wire                      wb_we_i,
    input wire [ADDR_WIDTH-1:0]     wb_addr_i,
    input wire [DATA_WIDTH-1:0]     wb_data_i,
    input wire [3:0]                wb_sel_i,
    output reg [DATA_WIDTH-1:0]     wb_data_o,
    output reg                      wb_ack_o
);
    // Memory for slave
    reg [DATA_WIDTH-1:0] mem [0:1023];
    reg [DATA_WIDTH-1:0] full_world;

    // Address checking 
    wire is_selected = (wb_addr_i >= BASE_ADDR) && (wb_addr_i < BASE_ADDR + SIZE_KB*1024);

    // Address offset calculation
    wire [ADDR_WIDTH-1:0] addr_offset = wb_addr_i - BASE_ADDR;

    initial begin
        for (integer i = 0; i < 1024; i = i + 1) begin
            mem[i] <= 32'h0000_0000;
        end
    end

    // -------------------------------------------
    // Main Slave Process
    // -------------------------------------------
    always @(*) begin
        wb_data_o <= 32'h0;

        if (wb_cyc_i && wb_stb_i && !wb_we_i && is_selected) begin
            wb_data_o <= mem[addr_offset[11:2]];
            //$display("[wb_slave_model][Slave %0d] Read  (sel=%b)  addr=%h, data=%h", SLAVE_ID, wb_sel_i, wb_addr_i, wb_data_o);
        end
    end


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Nothing to do here
            for (integer i = 0; i < 1024; i = i + 1) begin
                mem[i] <= 32'h0000_0000;
            end
        end
        else if (wb_cyc_i && wb_stb_i && wb_we_i && is_selected) begin
            if (wb_sel_i[0]) mem[addr_offset[11:2]][7:0]   <= wb_data_i[7:0]  ;
            if (wb_sel_i[1]) mem[addr_offset[11:2]][15:8]  <= wb_data_i[15:8] ;
            if (wb_sel_i[2]) mem[addr_offset[11:2]][23:16] <= wb_data_i[23:16];
            if (wb_sel_i[3]) mem[addr_offset[11:2]][31:24] <= wb_data_i[31:24];
            
            //$display("[wb_slave_model][Slave %0d] Write (sel=%b)  addr=%h, data=%h", SLAVE_ID, wb_sel_i, wb_addr_i, wb_data_i);
        end 
    end 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
        end else begin
            wb_ack_o <= (wb_cyc_i && wb_stb_i && is_selected);
        end
    end 
endmodule