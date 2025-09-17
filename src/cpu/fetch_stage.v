module fetch_stage #(
    parameter RESET_PC   = 32'h0000_0000,
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
    reg [ADDR_WIDTH-1:0] pc;
    reg                  fetch_pending;

    // -------------------------------------------
    // Constant assignments
    // -------------------------------------------
    assign wbm_imem_we         = 1'b0;                  // Fetch = read only
    assign wbm_imem_data_write = {DATA_WIDTH{1'b0}};    // Not used
    assign wbm_imem_sel        = 4'b1111;               // Word access
    assign wbm_imem_addr       = pc;                    // Driven by PC register

    // -------------------------------------------
    // PC Update logic
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= RESET_PC;
        end else begin
            if (flush) begin
                pc <= new_pc;   // Redirect on branch/jump
            end else if (wbm_imem_ack && !stall) begin
                pc <= pc + 4;   // Sequential flush
            end else begin
                pc <= pc;       // hold pc when stalled or waiting for ack
            end
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
            wbm_imem_cyc  <= 1'b1;
            wbm_imem_stb  <= 1'b1;
            fetch_pending <= 1'b1;
        end else if (!stall) begin
            if (!fetch_pending) begin
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
            instr_out <= {DATA_WIDTH{1'b0}};
            pc_out    <= {ADDR_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else if (flush) begin
            instr_out <= {DATA_WIDTH{1'b0}};
            pc_out    <= {ADDR_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else if (!stall && wbm_imem_ack) begin
            instr_out <= wbm_imem_data_read;
            pc_out    <= pc_reg;
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0; // No new instruction this cycle
        end
    end
    
endmodule