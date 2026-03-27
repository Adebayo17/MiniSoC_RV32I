module mem_stage #(
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
)(
    // Clock and reset
    input wire                                  clk,
    input wire                                  rst_n,

    // Pipeline control
    input wire                                  stall,

    // Pipeline inputs from execute stage
    input wire [DATA_WIDTH-1:0]                 instr_in,
    input wire [ADDR_WIDTH-1:0]                 pc_in,
    input wire [ADDR_WIDTH-1:0]                 pc_plus_4_in,
    input wire [DATA_WIDTH-1:0]                 alu_result_in,
    input wire [DATA_WIDTH-1:0]                 mem_data_in,  // Store data
    input wire [REGFILE_ADDR_WIDTH-1:0]         rd_in,
    input wire                                  reg_write_in,
    input wire                                  mem_write_in,
    input wire                                  mem_read_in,
    input wire [1:0]                            mem_to_reg_in,
    input wire [2:0]                            funct3_in,    // Size/type info
    input wire                                  valid_in,

    // Wishbone Master Data Interface (DMEM and Peripheral)
    output reg                                  wbm_dmem_cyc,
    output reg                                  wbm_dmem_stb,
    output reg                                  wbm_dmem_we,
    output wire [ADDR_WIDTH-1:0]                wbm_dmem_addr,
    output wire [DATA_WIDTH-1:0]                wbm_dmem_data_write,
    output reg [3:0]                            wbm_dmem_sel,
    input wire [DATA_WIDTH-1:0]                 wbm_dmem_data_read,
    input wire                                  wbm_dmem_ack,

    // Memory status outputs for hazard unit
    output wire                                 mem_busy,
    output wire                                 mem_ack,

    // Pipeline outputs
    output reg [DATA_WIDTH-1:0]                 instr_out,
    output reg [ADDR_WIDTH-1:0]                 pc_out,
    output reg [ADDR_WIDTH-1:0]                 pc_plus_4_out,
    output reg [DATA_WIDTH-1:0]                 mem_result_out,
    output reg [DATA_WIDTH-1:0]                 alu_result_out,
    output reg [REGFILE_ADDR_WIDTH-1:0]         rd_out,
    output reg                                  reg_write_out,
    output reg [1:0]                            mem_to_reg_out,
    output reg                                  valid_out,

    // Exception signals
    output reg                                  load_misaligned,
    output reg                                  store_misaligned
);

    // -------------------------------------------
    // Memory Access FSM
    // -------------------------------------------
    localparam [1:0]  IDLE     = 2'b00;
    localparam [1:0]  REQUEST  = 2'b01;
    
    reg [1:0] state, next_state;

    // Memory access size encoding
    localparam [2:0]  BYTE  = 3'b000;
    localparam [2:0]  HALF  = 3'b001;
    localparam [2:0]  WORD  = 3'b010;
    localparam [2:0]  BYTEU = 3'b100;
    localparam [2:0]  HALFU = 3'b101;

    // Internal signals
    wire is_mem_op      = (mem_read_in || mem_write_in) && valid_in;
    wire is_load        = mem_read_in && valid_in;
    wire is_store       = mem_write_in && valid_in;

    wire mem_op_complete = wbm_dmem_ack;

    // Memory status assignments
    assign mem_busy = (state != IDLE) || is_mem_op;
    assign mem_ack  = (state == REQUEST && wbm_dmem_ack);

    // -------------------------------------------
    // Address Alignment Checking
    // -------------------------------------------
    always @(*) begin
        load_misaligned  = 1'b0;
        store_misaligned = 1'b0;

        if (is_load || is_store) begin
            case (funct3_in)
                WORD:  if (alu_result_in[1:0] != 2'b00) begin
                           load_misaligned  = is_load;
                           store_misaligned = is_store;
                       end
                HALF, 
                HALFU: if (alu_result_in[0] != 1'b0) begin
                           load_misaligned  = is_load;
                           store_misaligned = is_store;
                       end
                // BYTE/BYTEU are always aligned
                default: begin
                    load_misaligned  = 1'b0;
                    store_misaligned = 1'b0;
                end
            endcase
        end
    end

    // -------------------------------------------
    // Context Registers for Memory Operations
    // -------------------------------------------
    reg [DATA_WIDTH-1:0]            instr_reg;
    reg [ADDR_WIDTH-1:0]            pc_reg;
    reg [ADDR_WIDTH-1:0]            pc_plus_4_reg;
    reg [REGFILE_ADDR_WIDTH-1:0]    rd_reg;
    reg                             reg_write_reg;
    reg [1:0]                       mem_to_reg_reg;
    reg [2:0]                       funct3_reg;
    reg                             mem_read_reg;
    reg                             mem_write_reg;
    reg [DATA_WIDTH-1:0]            store_data_reg;
    reg [ADDR_WIDTH-1:0]            mem_addr_reg;
    reg                             memory_op_active;

    // Snapshot logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            memory_op_active    <= 1'b0;
            instr_reg           <= 32'h00000013;
            pc_reg              <= 0;
            pc_plus_4_reg       <= 0;
            rd_reg              <= 0;
            reg_write_reg       <= 0;
            mem_to_reg_reg      <= 0;
            funct3_reg          <= 0;
            mem_read_reg        <= 0;
            mem_write_reg       <= 0;
            store_data_reg      <= 0;
            mem_addr_reg        <= 0;
        end else begin
            // Capture state ONLY when moving from IDLE to REQUEST
            if (is_mem_op && state == IDLE && !load_misaligned && !store_misaligned) begin
                instr_reg           <= instr_in;
                pc_reg              <= pc_in;
                pc_plus_4_reg       <= pc_plus_4_in;
                rd_reg              <= rd_in;
                reg_write_reg       <= reg_write_in;
                mem_to_reg_reg      <= mem_to_reg_in;
                funct3_reg          <= funct3_in;
                mem_read_reg        <= mem_read_in;
                mem_write_reg       <= mem_write_in;
                mem_addr_reg        <= alu_result_in;
                memory_op_active    <= 1'b1;

                // Prepare store data
                case (funct3_in)
                    BYTE:       store_data_reg <= {4{mem_data_in[7:0]}};
                    HALF:       store_data_reg <= {2{mem_data_in[15:0]}};
                    default:    store_data_reg <= mem_data_in;
                endcase
            end 
            else if (state == REQUEST && wbm_dmem_ack) begin
                // Clear active flag when transaction completes
                memory_op_active    <= 1'b0;
            end
        end
    end


    // -------------------------------------------
    // Wishbone Bus Interface
    // -------------------------------------------
    
    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM Combinational Logic
    always @(*) begin
        // Default assignments
        next_state   = state;
        wbm_dmem_cyc = 1'b0;
        wbm_dmem_stb = 1'b0;
        wbm_dmem_we  = 1'b0;

        case (state)
            IDLE: begin
                if (is_mem_op && !load_misaligned && !store_misaligned) begin
                    next_state   = REQUEST;
                end
            end

            REQUEST: begin
                wbm_dmem_cyc    = 1'b1;
                wbm_dmem_stb    = 1'b1;
                wbm_dmem_we     = mem_write_reg;

                if (wbm_dmem_ack) begin
                    next_state = IDLE;
                end 
            end

            default: next_state = IDLE;
        endcase
    end

    // Always drive Wishbone outputs from registered values
    assign wbm_dmem_data_write = store_data_reg;
    assign wbm_dmem_addr       = mem_addr_reg;


    // -------------------------------------------
    // Byte Select Generation
    // -------------------------------------------
    always @(*) begin
        case (funct3_reg)
            BYTE, BYTEU:  wbm_dmem_sel = 4'b0001 << mem_addr_reg[1:0];
            HALF, HALFU:  wbm_dmem_sel = 4'b0011 << {mem_addr_reg[1],1'b0};
            WORD:         wbm_dmem_sel = 4'b1111;
            default:      wbm_dmem_sel = 4'b0000;
        endcase
    end


    // -------------------------------------------
    // Load Data Processing
    // -------------------------------------------
    reg [DATA_WIDTH-1:0] load_data;
    wire [7:0]  byte_data;
    wire [15:0] half_data;

    // Extract the relevant bytes based on address alignment
    assign byte_data = wbm_dmem_data_read >> (8 * mem_addr_reg[1:0]);
    assign half_data = wbm_dmem_data_read >> (8 * {mem_addr_reg[1], 1'b0});

    always @(*) begin
        case (funct3_reg)
            BYTE:  load_data = {{24{byte_data[7]}}, byte_data[7:0]};
            BYTEU: load_data = {24'b0, byte_data[7:0]};
            HALF:  load_data = {{16{half_data[15]}}, half_data[15:0]};
            HALFU: load_data = {16'b0, half_data[15:0]};
            default: load_data = wbm_dmem_data_read;
        endcase
    end

    
    // -------------------------------------------
    // Pipeline Registers
    // -------------------------------------------
    wire use_reg_values = memory_op_active;

    // Flag to cleanly identify the exact cycle a memory operation fiinishes
    wire is_completing_mem = (state == REQUEST && wbm_dmem_ack);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_out       <= 32'h00000013;
            pc_out          <= {ADDR_WIDTH{1'b0}};
            pc_plus_4_out   <= 0;
            mem_result_out  <= 0;
            alu_result_out  <= 0;
            rd_out          <= 0;
            reg_write_out   <= 0;
            mem_to_reg_out  <= 0;
            valid_out       <= 0;
        end 
        // We update the output registers if the pipeline is NOT stalled,
        // OR if we are forcing an update because a memory op just finished
        else if (!stall || is_completing_mem) begin
            
            if (memory_op_active) begin
                // PATH 1: Completing a Memory Operation
                // Use the safe snapshot context we took in IDLE state
                instr_out       <= instr_reg;
                pc_out          <= pc_reg;
                pc_plus_4_out   <= pc_plus_4_reg;
                rd_out          <= rd_reg;
                mem_to_reg_out  <= mem_to_reg_reg;

                alu_result_out  <= mem_addr_reg;
                mem_result_out  <= load_data;

                // Signal to the writeback stage that this data is ready
                valid_out       <= 1'b1;
                reg_write_out   <= reg_write_reg;
            end 
            else begin
                // PATH 2: Normal Pss-Through (ALU, Branch, etc.)
                // Pass the fresh inputs straight through
                instr_out       <= instr_in;
                pc_out          <= pc_in;
                pc_plus_4_out   <= pc_plus_4_in;
                rd_out          <= rd_in;
                mem_to_reg_out  <= mem_to_reg_in;
                alu_result_out  <= alu_result_in;
                mem_result_out  <= 32'b0;

                // Only assert valid if it's NOT a new memory operation
                // (New memory ops will assert valid later when they complete via Path 1)
                valid_out       <= valid_in && !is_mem_op;
                reg_write_out   <= reg_write_in;
            end 
        end
        else begin
            // PATH 3: Pipeline is Stalled (and no memory op is completing right now)
            // Inject a bubble to prevent the next stage from processing the same instrcution
            valid_out       <= 1'b0;
            reg_write_out   <= 1'b0;
        end
    end
endmodule