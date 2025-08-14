module mem_stage #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input wire                  clk,
    input wire                  rst_n,

    // Pipeline inputs from execute stage
    input wire [DATA_WIDTH-1:0] alu_result_in,
    input wire [DATA_WIDTH-1:0] mem_data_in,  // Store data
    input wire [4:0]            rd_in,
    input wire                  reg_write_in,
    input wire                  mem_write_in,
    input wire                  mem_read_in,
    input wire [1:0]            mem_to_reg_in,
    input wire [2:0]            funct3_in,    // Size/type info
    input wire                  valid_in,

    // Wishbone Master Data Interface (DMEM and Peripheral)
    output reg                  wbm_dmem_cyc,
    output reg                  wbm_dmem_stb,
    output reg                  wbm_dmem_we,
    output reg [ADDR_WIDTH-1:0] wbm_dmem_addr,
    output reg [DATA_WIDTH-1:0] wbm_dmem_data_write,
    output reg [3:0]            wbm_dmem_sel,
    input wire [DATA_WIDTH-1:0] wbm_dmem_data_read,
    input wire                  wbm_dmem_ack,

    // Pipeline outputs
    output reg [DATA_WIDTH-1:0] mem_result_out,
    output reg [DATA_WIDTH-1:0] alu_result_out,
    output reg [4:0]            rd_out,
    output reg                  reg_write_out,
    output reg [1:0]            mem_to_reg_out,
    output reg                  valid_out,

    // Exception signals
    output reg                  load_misaligned,
    output reg                  store_misaligned
);

    // -------------------------------------------
    // Memory Access FSM
    // -------------------------------------------
    localparam [1:0]  IDLE;
    localparam [1:0]  READ;
    localparam [1:0]  WRITE;
    localparam [1:0]  DONE;
    
    reg [1:0] state;

    // Memory access size encoding
    localparam BYTE  = 3'b000;
    localparam HALF  = 3'b001;
    localparam WORD  = 3'b010;
    localparam BYTEU = 3'b100;
    localparam HALFU = 3'b101;

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
            wbm_dmem_cyc <= 1'b0;
            wbm_dmem_stb <= 1'b0;
            wbm_dmem_we  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (valid_in && !load_misaligned && !store_misaligned) begin
                        wbm_dmem_cyc <= 1'b1;
                        wbm_dmem_stb <= 1'b1;
                        wbm_dmem_we  <= mem_write_in;
                        wbm_dmem_addr <= alu_result_in;
                        state    <= mem_write_in ? WRITE : READ;
                    end
                end

                READ, WRITE: begin
                    if (wbm_dmem_ack) begin
                        wbm_dmem_stb <= 1'b0;
                        state <= DONE;
                    end
                end

                DONE: begin
                    wbm_dmem_cyc <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
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
        case (funct3_in)
            BYTE:  wbm_dmem_data_write = {4{mem_data_in[7:0]}};
            HALF:  wbm_dmem_data_write = {2{mem_data_in[15:0]}};
            default: wbm_dmem_data_write = mem_data_in;
        endcase
    end

    // -------------------------------------------
    // Load Data Processing
    // -------------------------------------------
    reg [DATA_WIDTH-1:0] load_data, tmp_mem_result_out;

    always @(*) begin
        case (funct3_in)
            BYTE:  load_data = {{24{wbm_dmem_data_read[7]}}, wbm_dmem_data_read[7:0]};
            BYTEU: load_data = {24'b0, wbm_dmem_data_read[7:0]};
            HALF:  load_data = {{16{wbm_dmem_data_read[15]}}, wbm_dmem_data_read[15:0]};
            HALFU: load_data = {16'b0, wbm_dmem_data_read[15:0]};
            default: load_data = wbm_dmem_data_read;
        endcase

        tmp_mem_result_out = (mem_to_reg_in == 2'b01) ? load_data : alu_result_in;
    end

    // -------------------------------------------
    // Pipeline Registers
    // -------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_result_out <= 0;
            alu_result_out <= 0;
            rd_out         <= 0;
            reg_write_out  <= 0;
            mem_to_reg_out <= 0;
            valid_out      <= 0;
        end else begin
            alu_result_out <= alu_result_in;
            rd_out         <= rd_in;
            reg_write_out  <= reg_write_in && valid_in && !load_misaligned;
            mem_to_reg_out <= mem_to_reg_in;
            valid_out      <= valid_in && (state == DONE || !(mem_read_in || mem_write_in));
            mem_result_out <= tmp_mem_result_out;

            // if (wbm_dmem_ack && mem_read_in) begin
            //     mem_result_out <= load_data;
            // end else begin
            //     mem_result_out <= alu_result_in; // For non-load operations
            // end
        end
    end
endmodule