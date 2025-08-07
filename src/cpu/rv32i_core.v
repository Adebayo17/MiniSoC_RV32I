module rv32i_core #(
    parameter RESET_PC   = 32'h0000_0000,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n,

    // Wishbone Instruction Interface (IMEM)
    output reg                      wb_m_cpu_cyc,
    output reg                      wb_m_cpu_stb,
    output reg                      wb_m_cpu_we,            // always 0
    output reg [ADDR_WIDTH-1:0]     wb_m_cpu_addr,
    output reg [DATA_WIDTH-1:0]     wb_m_cpu_data_write,
    output reg [3:0]                wb_m_cpu_sel,
    input wire [DATA_WIDTH-1:0]     wb_m_cpu_data_read,
    input wire                      wb_m_cpu_ack

    // Wishbone Data Interface (DMEM and Peripheral)
    output reg                      wb_m_cpu_cyc,
    output reg                      wb_m_cpu_stb,
    output reg                      wb_m_cpu_we,
    output reg [ADDR_WIDTH-1:0]     wb_m_cpu_addr,
    output reg [DATA_WIDTH-1:0]     wb_m_cpu_data_write,
    output reg [3:0]                wb_m_cpu_sel,
    input wire [DATA_WIDTH-1:0]     wb_m_cpu_data_read,
    input wire                      wb_m_cpu_ack
);
    
endmodule