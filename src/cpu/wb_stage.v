module writeback_stage #(
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
)(
    // Clock and reset
    input wire                                  clk,
    input wire                                  rst_n,

    // Pipeline inputs from memory stage
    input wire [DATA_WIDTH-1:0]                 instr_in,
    input wire [ADDR_WIDTH-1:0]                 pc_in,
    input wire [DATA_WIDTH-1:0]                 pc_plus_4_in,
    input wire [DATA_WIDTH-1:0]                 mem_result_in,
    input wire [DATA_WIDTH-1:0]                 alu_result_in,
    input wire [REGFILE_ADDR_WIDTH-1:0]         rd_in,
    input wire                                  reg_write_in,
    input wire [1:0]                            mem_to_reg_in,
    input wire                                  valid_in,

    // Register file interface
    output reg                                  regfile_we,
    output reg [REGFILE_ADDR_WIDTH-1:0]         regfile_rd_addr,
    output reg [DATA_WIDTH-1:0]                 regfile_wr_data,

    // Pipeline outputs (for debug)
    output wire[DATA_WIDTH-1:0]                 instr_out,
    output wire[ADDR_WIDTH-1:0]                 pc_out,
    output wire                                 valid_out
);

    // -------------------------------------------
    // Internal signals
    // -------------------------------------------
    reg [DATA_WIDTH-1:0] wr_data;
    reg                  we;

    // -------------------------------------------
    // Writeback Mux
    // -------------------------------------------
    always @(*) begin
        case (mem_to_reg_in)
            2'b00:   wr_data = alu_result_in;  // ALU result
            2'b01:   wr_data = mem_result_in;  // Memory load
            2'b10:   wr_data = pc_plus_4_in;   // JAL/JALR (return address)
            default: wr_data = alu_result_in;  // Default
        endcase

        // Generate write enable
        we = reg_write_in && valid_in && (rd_in != 0);
        
        // Direct to regfile (combinational, no delay)
        regfile_we      = we;
        regfile_rd_addr = rd_in;
        regfile_wr_data = wr_data;
    end

    // -------------------------------------------
    // Pipeline Register
    // -------------------------------------------
    assign instr_out = instr_in;
    assign pc_out    = pc_in;
    assign valid_out = valid_in; 
endmodule