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
    assign mem_busy = (state != IDLE);
    assign mem_ack  = mem_ack_reg;

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
    // Signal Latching for Memory Operations
    // -------------------------------------------
    reg [DATA_WIDTH-1:0]    instr_latched;
    reg [ADDR_WIDTH-1:0]    pc_latched;
    reg [ADDR_WIDTH-1:0]    pc_plus_4_latched;
    reg [REGFILE_ADDR_WIDTH-1:0] rd_latched;
    reg                     reg_write_latched;
    reg [1:0]               mem_to_reg_latched;
    reg [2:0]               funct3_latched;
    reg                     mem_read_latched;
    reg                     mem_write_latched;
    reg [DATA_WIDTH-1:0]    store_data_latched;
    reg [ADDR_WIDTH-1:0]    mem_addr_latched;
    reg                     memory_op_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_latched       <= 32'h00000013;
            pc_latched          <= 0;
            pc_plus_4_latched   <= 0;
            rd_latched          <= 0;
            reg_write_latched   <= 0;
            mem_to_reg_latched  <= 0;
            funct3_latched      <= 0;
            mem_read_latched    <= 0;
            mem_write_latched   <= 0;
            store_data_latched  <= 0;
            mem_addr_latched    <= 0;
            memory_op_active    <= 0;
        end 
        else if (!stall) begin
            // Start new memory operation when valid and in IDLE state
            if (is_mem_op && state == IDLE && !load_misaligned && !store_misaligned) begin
                instr_latched       <= instr_in;
                pc_latched          <= pc_in;
                pc_plus_4_latched   <= pc_plus_4_in;
                rd_latched          <= rd_in;
                reg_write_latched   <= reg_write_in;
                mem_to_reg_latched  <= mem_to_reg_in;
                funct3_latched      <= funct3_in;
                mem_read_latched    <= mem_read_in;
                mem_write_latched   <= mem_write_in;
                mem_addr_latched    <= alu_result_in;
                memory_op_active    <= 1;

                // Prepare store data
                if (mem_write_in) begin
                    case (funct3_in)
                        BYTE:  store_data_latched <= {4{mem_data_in[7:0]}};
                        HALF:  store_data_latched <= {2{mem_data_in[15:0]}};
                        default: store_data_latched <= mem_data_in;
                    endcase
                end
            end else if (state == REQUEST && wbm_dmem_ack) begin
                // Memory operation completed
                memory_op_active <= 0;
            end
        end
        // During stall, keep current latched values
    end

    // -------------------------------------------
    // Wishbone Bus Interface
    // -------------------------------------------
    reg mem_ack_reg; 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mem_ack_reg <= 1'b0;
        else if (state == REQUEST && wbm_dmem_ack)
            mem_ack_reg <= 1'b1;       // ack for THIS instruction
        else if (state == IDLE)
            mem_ack_reg <= 1'b0;       // clear once instruction retires
    end


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else if (!stall) begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state   = state;
        wbm_dmem_cyc = 1'b0;
        wbm_dmem_stb = 1'b0;
        wbm_dmem_we  = mem_write_latched;  // Use latched WE signal

        case (state)
            IDLE: begin
                if (is_mem_op && !load_misaligned && !store_misaligned) begin
                    next_state   = REQUEST;
                end
            end

            REQUEST: begin
                if (wbm_dmem_ack) begin
                    next_state = IDLE;
                end else begin
                    wbm_dmem_cyc = 1'b1;
                    wbm_dmem_stb = 1'b1;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Always drive Wishbone outputs from registered values
    assign wbm_dmem_data_write = store_data_latched;
    assign wbm_dmem_addr       = mem_addr_latched;


    // -------------------------------------------
    // Byte Select Generation
    // -------------------------------------------
    always @(*) begin
        case (funct3_latched)
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
        case (funct3_latched)
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
    wire use_latched_values = memory_op_active;

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
            // FREEZE outputs during stall
            // But keep valid_out as is if we're completing a memory op
            if (!(state == REQUEST && wbm_dmem_ack)) begin
                valid_out <= 0;
            end
        end
        else begin

            // Select between fresh inputs and latched values
            instr_out       <= use_latched_values ? instr_latched : instr_in;
            pc_out          <= use_latched_values ? pc_latched : pc_in;
            pc_plus_4_out   <= use_latched_values ? pc_plus_4_latched : pc_plus_4_in;
            rd_out          <= use_latched_values ? rd_latched : rd_in;
            mem_to_reg_out  <= use_latched_values ? mem_to_reg_latched : mem_to_reg_in;

            if (use_latched_values && mem_read_latched) begin
                // For completed load instructions, output the loaded data
                alu_result_out <= load_data;
            end else begin
                // For other instructions, use the normal ALU result
                alu_result_out <= use_latched_values ? mem_addr_latched : alu_result_in;
            end

            // Memory result selection
            case (use_latched_values ? mem_to_reg_latched : mem_to_reg_in)
                2'b00:   mem_result_out <= use_latched_values ? mem_addr_latched : alu_result_in;
                2'b01:   mem_result_out <= load_data;
                2'b10:   mem_result_out <= use_latched_values ? pc_plus_4_latched : pc_plus_4_in;
                default: mem_result_out <= use_latched_values ? mem_addr_latched : alu_result_in;
            endcase

            // Valid output logic
            if (state == REQUEST && wbm_dmem_ack) begin
                // Memory operation completed this cycle
                valid_out <= 1;
                reg_write_out <= use_latched_values ? (reg_write_latched && mem_read_latched) : 
                                                     (reg_write_in && mem_read_in);
            end else if (valid_in && !is_mem_op) begin
                // Non-memory operation - valid immediately
                valid_out <= 1;
                reg_write_out <= reg_write_in;
            end else begin
                // Memory operation in progress or no valid input
                valid_out <= 0;
                reg_write_out <= 0;
            end
        end
    end
endmodule