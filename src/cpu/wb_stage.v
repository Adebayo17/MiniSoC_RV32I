module wb_stage #(
    parameter DATA_WIDTH = 32
)(
    input wire                  clk,
    input wire                  rst_n,

    // Pipeline inputs from memory stage
    input wire [DATA_WIDTH-1:0] mem_result_in,
    input wire [DATA_WIDTH-1:0] alu_result_in,
    input wire [4:0]            rd_in,
    input wire                  reg_write_in,
    input wire                  valid_in,

    // Register file interface
    output reg                  regfile_we,
    output reg [4:0]            regfile_rd_addr,
    output reg [DATA_WIDTH-1:0] regfile_wr_data,

    // Pipeline outputs (for debug)
    output reg                  valid_out
);

    // -------------------------------------------
    // Writeback Mux
    // -------------------------------------------
    always @(*) begin
        regfile_we = reg_write_in && valid_in;
        regfile_rd_addr = rd_in;
        
        // Default to ALU result, override with memory load when needed
        regfile_wr_data = alu_result_in;
        
        if (mem_result_in != alu_result_in) begin
            regfile_wr_data = mem_result_in; // Load operations
        end
    end

    // -------------------------------------------
    // Pipeline Register
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
        end else begin
            valid_out <= valid_in;
        end
    end

endmodule