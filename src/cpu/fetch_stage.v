module fetch_stage #(
    parameter RESET_PC = 32'h0000_0000,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset 
    input wire                      clk,
    input wire                      rst_n,

    // Instruction Memory Interface (NEW)
    output reg                      wbm_imem_cyc,
    output reg                      wbm_imem_stb,
    output wire                     wbm_imem_we,
    output wire [ADDR_WIDTH-1:0]    wbm_imem_addr,
    output wire [DATA_WIDTH-1:0]    wbm_imem_data_write,
    output wire [3:0]               wbm_imem_sel,
    input wire  [DATA_WIDTH-1:0]    wbm_imem_data_read,
    input wire                      wbm_imem_ack,

    // Pipeline input
    input wire                      flush,          // From branch/jump
    input wire [ADDR_WIDTH-1:0]     new_pc,         // From execute stage
    input wire                      stall,          // From hazard unit

    // Pipeline output
    output reg [DATA_WIDTH-1:0]     instr_out,
    output reg [ADDR_WIDTH-1:0]     pc_out,
    output reg                      valid_out
);
    // -------------------------------------------
    // Internal State
    // -------------------------------------------
    reg [ADDR_WIDTH-1:0] pc;
    reg [ADDR_WIDTH-1:0] next_pc;
    reg                  pending_request;

    // -------------------------------------------
    // PC Update logic
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc              <= RESET_PC;
            pending_request <= 1'b0;
        end else begin
            if (flush) begin
                pc              <= new_pc;      // Redirect on branch/jump
                pending_request <= 1'b1;        // Need to fetch new instruction
            end else if (wbm_imem_ack && !stall) begin
                pc              <= next_pc;     // Advance to next instruction
                pending_request <= 1'b1;        // Need to fetch next instruction
            end
            
            // Clear pending request when we start a new fetch
            if (wbm_imem_stb && wbm_imem_cyc) begin
                pending_request <= 1'b0;
            end
        end
    end

    // -------------------------------------------
    // Next PC Computation
    // -------------------------------------------   
    always @(posedge clk) begin
        if (!rst_n) begin
            next_pc = 0;
        end else begin
            if (flush) begin
                next_pc = new_pc;
            end else begin
                next_pc = pc + 4;
            end
        end
    end

    // ----------------------------
    // Wishbone FSM (NEW - Sequential)
    // ----------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbm_imem_cyc <= 1'b0;
            wbm_imem_stb <= 1'b0;
        end else begin
            // Start new transaction when we have a pending fetch and not stalling
            if (pending_request && !stall && !(wbm_imem_cyc && !wbm_imem_ack)) begin
                wbm_imem_cyc <= 1'b1;
                wbm_imem_stb <= 1'b1;
            end
            
            // Deassert STB after one cycle
            if (wbm_imem_stb) begin
                wbm_imem_stb <= 1'b0;
            end
            
            // End cycle when done
            if (wbm_imem_ack) begin
                wbm_imem_cyc <= 1'b0;
            end

            // If stalling, maintain current state
            if (stall) begin
                wbm_imem_stb <= 1'b0;
            end
        end
    end

    // Continuous address assignment
    assign wbm_imem_addr = pc;
    assign wbm_imem_we   = 1'b0;
    assign wbm_imem_sel  = 4'b1111;

    // -------------------------------------------
    // Pipeline Register
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_out   <= 32'h00000013; // NOP
            pc_out      <= RESET_PC;
            valid_out   <= 1'b0;
        end else if (!stall) begin
            if (wbm_imem_ack) begin
                instr_out   <= wbm_imem_data_read;
                pc_out      <= pc;
                valid_out   <= 1'b1;
            end else begin
                valid_out   <= 1'b0;
            end
        end
    end
endmodule