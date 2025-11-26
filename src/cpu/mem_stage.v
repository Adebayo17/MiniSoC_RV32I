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
    wire is_mem_op          = (mem_read_in || mem_write_in) && valid_in;
    wire mem_op_complete    = (is_mem_op && wbm_dmem_ack) || (!is_mem_op);

    // Memory status assignments
    assign mem_busy = (state != IDLE);
    assign mem_ack  = wbm_dmem_ack;

    // -------------------------------------------
    // Address Alignment Checking
    // -------------------------------------------
    wire is_load  = mem_read_in && valid_in;
    wire is_store = mem_write_in && valid_in;

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
            endcase
        end
    end

    // -------------------------------------------
    // Wishbone Bus Interface
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state   = state;
        wbm_dmem_cyc = 1'b0;
        wbm_dmem_stb = 1'b0;
        wbm_dmem_we  = wbm_dmem_we_latched;

        case (state)
            IDLE: begin
                if (is_mem_op && !load_misaligned && !store_misaligned) begin
                    wbm_dmem_cyc = 1'b1;
                    wbm_dmem_stb = 1'b1;
                    // wbm_dmem_we  = wbm_dmem_we_latched;
                    next_state   = REQUEST;
                end
            end

            REQUEST: begin
                wbm_dmem_cyc = 1'b1;
                if (wbm_dmem_ack) begin
                    next_state = IDLE;
                end else begin
                    wbm_dmem_stb = 1'b1;
                    // wbm_dmem_we  = wbm_dmem_we_latched;
                end
            end

            default: next_state = IDLE;
        endcase
    end


    // -------------------------------------------
    // Store Data Preparation
    // -------------------------------------------
    reg [DATA_WIDTH-1:0]    store_data_latched;
    reg [ADDR_WIDTH-1:0]    mem_addr_latched;
    reg                     wbm_dmem_we_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            store_data_latched  <= 0;
            mem_addr_latched    <= 0;
            wbm_dmem_we_latched <= 0;
        end
        // Latch only when a new, valid op arrives and FSM is ready
        else if (is_mem_op && state == IDLE) begin
            // Latch address for both load and store
            mem_addr_latched <= alu_result_in;

            // Latch WE for entire memory transaction
            wbm_dmem_we_latched <= mem_write_in;

            // Prepare store data
            if (mem_write_in) begin
                case (funct3_in)
                    BYTE:  store_data_latched <= {4{mem_data_in[7:0]}};
                    HALF:  store_data_latched <= {2{mem_data_in[15:0]}};
                    default: store_data_latched <= mem_data_in;
                endcase
            end
        end 
    end

    // Always drive Wishbone outputs from registered values for timing
    assign wbm_dmem_data_write = store_data_latched;
    assign wbm_dmem_addr       = mem_addr_latched;


    // -------------------------------------------
    // Byte Select Generation
    // -------------------------------------------
    always @(*) begin
        case (funct3_in)
            BYTE, BYTEU:  wbm_dmem_sel = 4'b0001 << mem_addr_latched[1:0];
            HALF, HALFU:  wbm_dmem_sel = 4'b0011 << {mem_addr_latched[1],1'b0};
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
    assign byte_data = wbm_dmem_data_read >> (8 * mem_addr_latched[1:0]);
    assign half_data = wbm_dmem_data_read >> (8 * {mem_addr_latched[1], 1'b0});

    always @(*) begin
        case (funct3_in)
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
        end else if (stall) begin
            // FREEZE
        end
        else begin

            // Normal pipeline operation
            instr_out       <= instr_in;
            pc_out          <= pc_in;
            pc_plus_4_out   <= pc_plus_4_in;
            alu_result_out  <= alu_result_in;
            rd_out          <= rd_in;
            mem_to_reg_out  <= mem_to_reg_in;

            // Memory result selection
            case (mem_to_reg_in)
                2'b00:   mem_result_out <= alu_result_in;    // ALU result
                2'b01:   mem_result_out <= load_data;        // Memory load
                2'b10:   mem_result_out <= pc_plus_4_in;     // JAL/JALR
                default: mem_result_out <= alu_result_in;
            endcase

            // Valid output logic
            if (state == REQUEST && wbm_dmem_ack) begin
                // Memory operation just completed
                valid_out <= 1;
                reg_write_out <= reg_write_in && mem_read_in;  // Only for loads
            end else if (valid_in && !is_mem_op) begin
                // Non-memory operation
                valid_out <= 1;
                reg_write_out <= reg_write_in;
            end else begin
                // Memory operation in progress or no valid input
                valid_out <= 0;
                reg_write_out <= 0;
            end



            // reg_write_out   <= reg_write_in && valid_in && !load_misaligned && !store_misaligned;

            // if (is_load && !load_misaligned) begin
            //     // Load instruction - only write register when memory completes
            //     reg_write_out <= reg_write_in && mem_op_complete;
            // end else begin
            //     // Other instructions - use normal logic
            //     reg_write_out <= reg_write_in && valid_in && !load_misaligned && !store_misaligned;
            // end
            
            // // Valid output: memory ops complete when ack received or not a memory op
            // if (is_mem_op) begin
            //     valid_out <= valid_latched && wbm_dmem_ack;
            // end else begin
            //     valid_out <= valid_in;
            // end
        end
    end
endmodule