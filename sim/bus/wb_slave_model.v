module wb_slave_model #(
    parameter SLAVE_ID  = 0,
    parameter BASE_ADDR  = 32'h0000_0000,
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

    // Address checking 
    wire is_selected = (wb_addr_i >= BASE_ADDR) && (wb_addr_i < BASE_ADDR + 32'h1000);

    // Address offset calculation
    wire [ADDR_WIDTH-1:0] addr_offset = wb_addr_i - BASE_ADDR;

    // -------------------------------------------
    // Main Slave Process
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            wb_ack_o  <= 0;
            wb_data_o <= 32'h0;

            // Initialize memory to known values
            for (integer i = 0; i < 1024; i = i + 1) begin
                mem[i] <= 32'hDEAD_DEAD;
            end
        end
        else if (wb_cyc_i && wb_stb_i && is_selected) begin
            wb_ack_o <= 1;
            
            if (wb_we_i) begin
                // Write operation
                mem[addr_offset[11:2]] <= wb_data_i;
                $display("[wb_slave_model][Slave %0d] Write addr=%h, data=%h", SLAVE_ID, wb_addr_i, wb_data_i);
            end else begin
                // Read operation
                wb_data_o <= mem[addr_offset[11:2]];
                $display("[wb_slave_model][Slave %0d] Read  addr=%h, data=%h", SLAVE_ID, wb_addr_i, wb_data_o);
            end
        end else begin
            wb_ack_o <= 0;
        end
    end 
endmodule