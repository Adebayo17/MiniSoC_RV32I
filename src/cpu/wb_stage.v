module writeback_stage #(
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
)(
    // Clock and reset
    input wire                                  clk,
    input wire                                  rst_n,

    // Pipeline control
    input wire                                  stall,

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
    output reg [DATA_WIDTH-1:0]                 instr_out,
    output reg [ADDR_WIDTH-1:0]                 pc_out,
    output reg [ADDR_WIDTH-1:0]                 pc_plus_4_out,
    output reg [REGFILE_ADDR_WIDTH-1:0]         rd_out,
    output reg [DATA_WIDTH-1:0]                 result_out,
    output reg                                  reg_write_out,
    output reg                                  valid_out
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
        //we = reg_write_in && valid_in;
    end

    // -------------------------------------------
    // Pipeline Register
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all outputs
            instr_out           <= 32'h00000013;
            pc_out              <= {ADDR_WIDTH{1'b0}};
            pc_plus_4_out       <= 0;
            regfile_we          <= 1'b0;
            regfile_rd_addr     <= 0;
            regfile_wr_data     <= 0;
            rd_out              <= 0;
            result_out          <= 0;
            reg_write_out       <= 1'b0;
            valid_out           <= 1'b0;
        end else if (stall) begin
            // HOLD Register value
        end
        else if (!stall) begin
            if (valid_in) begin
                // Normal pipeline operation
                regfile_we          <= we;
                regfile_rd_addr     <= rd_in;
                regfile_wr_data     <= wr_data;
                
                // Outputs for forwarding and debug
                instr_out           <= instr_in;
                pc_out              <= pc_in;
                pc_plus_4_out       <= pc_plus_4_in;
                rd_out              <= rd_in;
                result_out          <= wr_data;
                reg_write_out       <= reg_write_in && valid_in;
                valid_out           <= 1'b1;
            end else begin
                valid_out           <= 1'b0;
            end 
            
        end 
    end
endmodule