module fetch_stage #(
    parameter RESET_PC   = 32'h0000_0000,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n,

    // Instruction Memory Interface (Wishbone)
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
    // Parameters and constant assignments
    // -------------------------------------------
    localparam NOP_INSTR = 32'h00000013;

    assign wbm_imem_we          = 1'b0;                     // Fetch = read only
    assign wbm_imem_sel         = 4'b1111;                  // Word access
    assign wbm_imem_addr        = pc;                       // Driven by PC register
    assign wbm_imem_data_write  = {DATA_WIDTH{1'b0}};       // Not used

    // -------------------------------------------
    // FSM state encoding
    // -------------------------------------------
    localparam IDLE = 2'b00;                                // No transaction pending
    localparam WAIT = 2'b01;                                // Waiting for Wishbone ack
    localparam HOLD = 2'b10;                                // Instruction fetched but stalled

    reg [1:0] state, next_state;

    // -------------------------------------------
    // Internal registers
    // -------------------------------------------
    reg [ADDR_WIDTH-1:0] pc;                                // Current fetch address
    reg [ADDR_WIDTH-1:0] next_pc;                           // Next fetch address (PC+4 after ack)
    reg [DATA_WIDTH-1:0] fetched_instr;                     // Held instruction during stall
    reg [ADDR_WIDTH-1:0] fetched_pc;                        // PC of held instruction

    // -------------------------------------------
    // Next state logic (combinational)
    // -------------------------------------------
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if (flush)
                    next_state = IDLE;
                else if (!stall)
                    next_state = WAIT;
                else
                    next_state = IDLE;
            end

            WAIT: begin
                if (flush)
                    next_state = IDLE;
                else if (wbm_imem_ack) begin
                    if (!stall)
                        next_state = IDLE;
                    else
                        next_state = HOLD;
                end else
                    next_state = WAIT;
            end

            HOLD: begin
                if (flush)
                    next_state = IDLE;
                else if (!stall)
                    next_state = IDLE;
                else
                    next_state = HOLD;
            end
        endcase
    end

    // -------------------------------------------
    // State and register updates (sequential)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            pc              <= RESET_PC;
            next_pc         <= RESET_PC;
            fetched_instr   <= {DATA_WIDTH{1'b0}};
            fetched_pc      <= {ADDR_WIDTH{1'b0}};
        end else begin
            state <= next_state;

            // Update next_pc on ack or flush
            if (flush)
                next_pc <= new_pc;
            else if (wbm_imem_ack && (state == WAIT))
                next_pc <= pc + 4;

            // Update PC when not stalled
            if (!stall)
                pc <= next_pc;

            // Capture fetched instruction on ack in WAIT
            if (wbm_imem_ack && (state == WAIT)) begin
                fetched_instr <= wbm_imem_data_read;
                fetched_pc    <= pc;
            end
        end
    end

    // -------------------------------------------
    // Wishbone control outputs (registered)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbm_imem_cyc <= 1'b0;
            wbm_imem_stb <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (!stall && !flush) begin
                        wbm_imem_cyc <= 1'b1;
                        wbm_imem_stb <= 1'b1;
                    end else begin
                        wbm_imem_cyc <= 1'b0;
                        wbm_imem_stb <= 1'b0;
                    end
                end

                WAIT: begin
                    if (flush) begin
                        wbm_imem_cyc <= 1'b0;
                        wbm_imem_stb <= 1'b0;
                    end else if (wbm_imem_ack) begin
                        // Deassert after ack
                        wbm_imem_cyc <= 1'b0;
                        wbm_imem_stb <= 1'b0;
                    end else begin
                        wbm_imem_cyc <= 1'b1;
                        wbm_imem_stb <= 1'b1;
                    end
                end

                HOLD: begin
                    wbm_imem_cyc <= 1'b0;
                    wbm_imem_stb <= 1'b0;
                end
            endcase
        end
    end

    // -------------------------------------------
    // Pipeline register update (output to decode)
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_out  <= NOP_INSTR;
            pc_out     <= {ADDR_WIDTH{1'b0}};
            valid_out  <= 1'b0;
        end else begin
            if (flush) begin
                instr_out  <= NOP_INSTR;
                pc_out     <= {ADDR_WIDTH{1'b0}};
                valid_out  <= 1'b0;
            end else begin
                case (state)
                    IDLE: begin
                        valid_out <= 1'b0;
                    end

                    WAIT: begin
                        if (wbm_imem_ack && !stall) begin
                            instr_out  <= wbm_imem_data_read;
                            pc_out     <= pc;
                            valid_out  <= 1'b1;
                        end else begin
                            valid_out <= 1'b0;
                        end
                    end

                    HOLD: begin
                        if (!stall) begin
                            instr_out  <= fetched_instr;
                            pc_out     <= fetched_pc;
                            valid_out  <= 1'b1;
                        end else begin
                            valid_out <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end
endmodule