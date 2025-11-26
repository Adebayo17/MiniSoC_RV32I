module fetch_stage #(
    parameter RESET_PC   = 32'h0000_0000,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset 
    input wire                      clk,
    input wire                      rst_n,

    // Instruction Memory Interface
    output reg                      wbm_imem_cyc,
    output reg                      wbm_imem_stb,
    output wire                     wbm_imem_we,
    output wire [ADDR_WIDTH-1:0]    wbm_imem_addr,
    output wire [DATA_WIDTH-1:0]    wbm_imem_data_write,
    output wire [3:0]               wbm_imem_sel,
    input wire  [DATA_WIDTH-1:0]    wbm_imem_data_read,
    input wire                      wbm_imem_ack,

    // Pipeline input
    input wire                      flush,          // From hazard unit
    input wire [ADDR_WIDTH-1:0]     new_pc,         // From execute stage
    input wire                      stall,          // From hazard unit

    // Pipeline output for Decode Stage
    output reg [DATA_WIDTH-1:0]     instr_out,
    output reg [ADDR_WIDTH-1:0]     pc_out,
    output reg                      valid_out
);
    
    // -------------------------------------------
    // Internal State
    // -------------------------------------------
    localparam NOP_INSTR = 32'h00000013;

    reg [ADDR_WIDTH-1:0]    pc, next_pc;
    reg                     fetch_pending;
    reg                     flush_pending;


    // -------------------------------------------
    // Constant assignments
    // -------------------------------------------
    assign wbm_imem_we         = 1'b0;                  // Fetch = read only
    assign wbm_imem_data_write = {DATA_WIDTH{1'b0}};    // Not used
    assign wbm_imem_sel        = 4'b1111;               // Word access
    assign wbm_imem_addr       = pc;                    // Driven by PC register

    // -------------------------------------------
    // NEXT_PC Update logic
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_pc         <= RESET_PC;
            flush_pending   <= 1'b0;
        end else begin
            if (flush) begin
                next_pc         <= new_pc;      // Redirect on branch/jump
                flush_pending   <= 1'b1;
            end else if (flush_pending && !fetch_pending) begin
                flush_pending   <= 1'b0;        // Flush has been processed, clear the flag
            end else if (wbm_imem_ack && !stall && !flush_pending) begin
                next_pc         <= pc + 4;      // Sequential flush
            end else begin
                next_pc         <= pc;          // hold pc when stalled or waiting for ack
            end
        end
    end 

    // -------------------------------------------
    // PC Update logic
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= RESET_PC;
        end else if (!stall) begin
            pc <= next_pc;
        end
    end 


    // ----------------------------
    // Fetch control (Wishbone)
    // ----------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbm_imem_cyc  <= 1'b0;
            wbm_imem_stb  <= 1'b0;
            fetch_pending <= 1'b0;
        end else if (flush) begin
            // Kill any pending transaction and restart
            wbm_imem_cyc  <= 1'b0;
            wbm_imem_stb  <= 1'b0;
            fetch_pending <= 1'b0;
        end else if (!stall) begin
            if (flush_pending) begin
                wbm_imem_cyc  <= 1'b0;
                wbm_imem_stb  <= 1'b0;
                fetch_pending <= 1'b0;
            end else if (!fetch_pending) begin
                // Start new Wishbone transaction
                wbm_imem_cyc  <= 1'b1;
                wbm_imem_stb  <= 1'b1;
                fetch_pending <= 1'b1;
            end else if (wbm_imem_ack) begin
                // Transaction complete
                wbm_imem_cyc  <= 1'b0;
                wbm_imem_stb  <= 1'b0;
                fetch_pending <= 1'b0;
            end
            // else: keep waiting
        end
        // else: stalled, hold handshake signals
    end


    // -------------------------------------------
    // Pipeline Register Update
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_out <= NOP_INSTR;
            pc_out    <= {ADDR_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end 
        else if (flush || flush_pending) begin
            instr_out <= NOP_INSTR;
            pc_out    <= {ADDR_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end 
        else if (stall) begin
            // HOLD everything during stall
            // Nothing to do
        end
        else if (!stall && wbm_imem_ack && !flush_pending && !fetch_pending) begin
            instr_out <= wbm_imem_data_read;
            pc_out    <= pc;
            valid_out <= 1'b1;
        end 
        else begin
            // No new instruction this cycle
            valid_out <= 1'b0; 
        end
    end
endmodule