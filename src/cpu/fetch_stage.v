module fetch_stage #(
    parameter RESET_PC = 32'h0000_0000,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,
    input wire pc_reset,

    // Wishbone interface
    output reg                      wb_m_cpu_cyc,
    output reg                      wb_m_cpu_stb,
    output reg [ADDR_WIDTH-1:0]     wb_m_cpu_addr,
    input wire [DATA_WIDTH-1:0]     wb_m_cpu_data_read,
    input wire                      wb_m_cpu_ack,

    // Pipeline output
    output reg [DATA_WIDTH-1:0]     instr_out,
    output reg [ADDR_WIDTH-1:0]     pc_out,
    output reg                      valid_out
);
    reg [ADDR_WIDTH-1:0] pc;
    reg [ADDR_WIDTH-1:0] next_pc;

    // -------------------------------------------
    // PC Update logic
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= RESET_PC;
        end else if(wb_m_cpu_ack) begin
            pc <= next_pc;
        end 
    end

    // -------------------------------------------
    // Instruction fetch FSM
    // -------------------------------------------
    
    // Drive Wishbone interface combinatorially
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_m_cpu_cyc <= 0;
            wb_m_cpu_stb <= 0;
        end else begin
            wb_m_cpu_cyc <= !wb_m_cpu_ack; // Keep high until ack
            wb_m_cpu_stb <= !wb_m_cpu_ack; // New request if no ack
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_out <= 0;
            pc_out    <= 0;
            valid_out <= 0;
        end else if(wb_m_cpu_ack) begin
            instr_out <= wb_m_cpu_data_read;
            pc_out    <= pc;
            valid_out <= 1'b1;
            next_pc   <= pc + 4;
        end else begin
            valid_out = 1'b0;
        end 
    end

    // -------------------------------------------
    // Next PC Update ; TODO: Add branch/jump handling
    // -------------------------------------------   
    always @(*) begin
        if (!rst_n) begin
            next_pc <= 0;
        end else begin
            if (wb_m_cpu_ack) begin
                // Default
                next_pc <= pc + 4;
            end
        end
    end
endmodule