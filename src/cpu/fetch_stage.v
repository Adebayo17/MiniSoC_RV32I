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
    output reg [ADDR_WIDTH-1:0]     wbm_imem_addr,
    input wire [DATA_WIDTH-1:0]     wbm_imem_data_read,
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
    reg                  pending_fetch;

    // -------------------------------------------
    // PC Update logic
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= RESET_PC;
            pending_fetch <= 1'b0;
        end else begin
            if (flush) begin
                pc <= new_pc;               // Redirect on branch/jump
                pending_fetch <= 1'b1;
            end else if(wbm_imem_ack && !stall) begin
                pc <= next_pc;              // Normal sequential flow
                pending_fetch <= 1'b1;
            end 

            // Clear pending flag when request is made
            if (wbm_imem_stb) begin
                pending_fetch <= 1'b0;
            end
        end
    end

    // -------------------------------------------
    // Next PC Update ; TODO: Add branch/jump handling
    // -------------------------------------------   
    always @(*) begin
        if (!rst_n) begin
            next_pc = 0;
        end else begin
            if (flush) begin
                next_pc = new_pc;
            end else if (wbm_imem_ack) begin
                next_pc = pc + 4;
            end else begin
                next_pc = pc;
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
            // Start new transaction when:
            // 1. We have a pending fetch, and
            // 2. Not stalling, and
            // 3. No outstanding request
            if (pending_fetch && !stall && !(wbm_imem_cyc && !wbm_imem_ack)) begin
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
        end
    end

    // Continuous address assignment
    assign wbm_imem_addr = pc;

    // -------------------------------------------
    // Pipeline Register
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_out <= 32'h00000013; // NOP
            pc_out <= RESET_PC;
            valid_out <= 1'b0;
        end else if (!stall) begin
            if (wbm_imem_ack) begin
                instr_out <= wbm_imem_data_read;
                pc_out <= pc;
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule