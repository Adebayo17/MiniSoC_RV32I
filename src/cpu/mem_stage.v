module mem_stage #(
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 32,
    parameter REGFILE_ADDR_WIDTH = 5
)(
    // Clock and reset
    input wire                                  clk,
    input wire                                  rst_n,

    // Pipeline inputs from execute stage
    input wire [DATA_WIDTH-1:0]                 pc_plus_4_in,
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
    output reg [ADDR_WIDTH-1:0]                 wbm_dmem_addr,
    output reg [DATA_WIDTH-1:0]                 wbm_dmem_data_write,
    output reg [3:0]                            wbm_dmem_sel,
    input wire [DATA_WIDTH-1:0]                 wbm_dmem_data_read,
    input wire                                  wbm_dmem_ack,

    // Pipeline outputs
    output reg [DATA_WIDTH-1:0]                 pc_plus_4_out,
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
    localparam [1:0]  WAIT     = 2'b10;
    
    reg [1:0] state, next_state;

    // Memory access size encoding
    localparam [2:0]  BYTE  = 3'b000;
    localparam [2:0]  HALF  = 3'b001;
    localparam [2:0]  WORD  = 3'b010;
    localparam [2:0]  BYTEU = 3'b100;
    localparam [2:0]  HALFU = 3'b101;

    // Internal signals
    wire is_mem_op = (mem_read_in || mem_write_in) && valid_in;
    wire mem_op_complete = (state == REQUEST && wbm_dmem_ack) || !is_mem_op;

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
        next_state = state;
        wbm_dmem_cyc = 1'b0;
        wbm_dmem_stb = 1'b0;
        wbm_dmem_we  = 1'b0;

        case (state)
            IDLE: begin
                if (valid_in && is_mem_op && !load_misaligned && !store_misaligned) begin
                    wbm_dmem_cyc = 1'b1;
                    wbm_dmem_stb = 1'b1;
                    wbm_dmem_we  = mem_write_in;
                    next_state = REQUEST;
                end
            end

            REQUEST: begin
                wbm_dmem_cyc = 1'b1;
                if (wbm_dmem_ack) begin
                    next_state = IDLE;
                end else begin
                    wbm_dmem_stb = 1'b1;
                    wbm_dmem_we  = mem_write_in;
                end
            end

            default: next_state = IDLE;
        endcase
    end


    // -------------------------------------------
    // Byte Select Generation
    // -------------------------------------------
    always @(*) begin
        case (funct3_in)
            BYTE, BYTEU:  wbm_dmem_sel = 4'b0001 << alu_result_in[1:0];
            HALF, HALFU:  wbm_dmem_sel = 4'b0011 << {alu_result_in[1],1'b0};
            WORD:         wbm_dmem_sel = 4'b1111;
            default:      wbm_dmem_sel = 4'b0000;
        endcase
    end

    // -------------------------------------------
    // Store Data Preparation
    // -------------------------------------------
    always @(*) begin
        wbm_dmem_addr = alu_result_in;

        case (funct3_in)
            BYTE:  wbm_dmem_data_write = {4{mem_data_in[7:0]}};
            HALF:  wbm_dmem_data_write = {2{mem_data_in[15:0]}};
            default: wbm_dmem_data_write = mem_data_in;
        endcase
    end

    // -------------------------------------------
    // Load Data Processing
    // -------------------------------------------
    reg [DATA_WIDTH-1:0] load_data;
    wire [7:0]  byte_data;
    wire [15:0] half_data;

    // Extract the relevant bytes based on address alignment
    assign byte_data = wbm_dmem_data_read >> (8 * alu_result_in[1:0]);
    assign half_data = wbm_dmem_data_read >> (8 * {alu_result_in[1], 1'b0});

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
            pc_plus_4_out  <= 0;
            mem_result_out <= 0;
            alu_result_out <= 0;
            rd_out         <= 0;
            reg_write_out  <= 0;
            mem_to_reg_out <= 0;
            valid_out      <= 0;
        end else begin
            // Normal pipeline operation
            pc_plus_4_out  <= pc_plus_4_in;
            alu_result_out <= alu_result_in;
            rd_out         <= rd_in;
            reg_write_out  <= reg_write_in && valid_in && !load_misaligned;
            mem_to_reg_out <= mem_to_reg_in;
            
            // Memory result selection
            case (mem_to_reg_in)
                2'b00:   mem_result_out <= alu_result_in;    // ALU result
                2'b01:   mem_result_out <= load_data;        // Memory load
                2'b10:   mem_result_out <= pc_plus_4_in;     // JAL/JALR
                default: mem_result_out <= alu_result_in;
            endcase
            
            // Valid output: memory ops complete when ack received or not a memory op
            valid_out <= valid_in && (mem_op_complete || !is_mem_op);
        end
    end
endmodule