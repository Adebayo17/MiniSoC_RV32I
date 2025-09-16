module regfile #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5
)(
    input wire clk,
    input wire rst_n,

    // Read ports
    input wire [ADDR_WIDTH-1:0] rs1_addr,
    input wire [ADDR_WIDTH-1:0] rs2_addr,
    output reg [DATA_WIDTH-1:0] rs1_data,
    output reg [DATA_WIDTH-1:0] rs2_data,

    // Write port
    input wire                  wr_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data
);

    // Register storage
    reg [DATA_WIDTH-1:0] registers [0:(1<<ADDR_WIDTH)-1];   // 32 Registers (x0...x31)

    // -------------------------------------------
    // Read Logic (combinational)
    // -------------------------------------------
    always @(*) begin
        rs1_data = (rs1_addr != 0) ? registers[rs1_addr] : 0;
        rs2_data = (rs2_addr != 0) ? registers[rs2_addr] : 0;
    end

    // -------------------------------------------
    // Write Logic (synchronous)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers to 0 except x0
            for (integer i = 1; i < (1<<ADDR_WIDTH); i = i + 1) begin
                registers[i] <= 0;
            end
        end else if (wr_en && wr_addr != 0) begin
            registers[wr_addr] <= wr_data;
        end
    end

    // -------------------------------------------
    // Debug Access
    // -------------------------------------------
    // synthesis translate_off
    function [DATA_WIDTH-1:0] get_register;
        input [ADDR_WIDTH-1:0] addr;
        get_register = registers[addr];
    endfunction
    // synthesis translate_on

endmodule