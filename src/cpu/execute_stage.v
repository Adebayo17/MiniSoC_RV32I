module execute_stage #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,

    // From Decode Stage
    input wire [DATA_WIDTH-1:0] instr_in,
    input wire [ADDR_WIDTH-1:0] pc_in,
    input wire [4:0]            rs1_in,
    input wire [4:0]            rs2_in,
    input wire [4:0]            rd_in,
    input wire [DATA_WIDTH-1:0] imm_in,
    input wire [6:0]            opcode_in,
    input wire [2:0]            funct3_in,
    input wire [6:0]            funct7_in,
    input wire                  valid_in,

    // From register file
    input wire [DATA_WIDTH-1:0] rs1_data,
    input wire [DATA_WIDTH-1:0] rs2_data,

    // To memory stage
    output reg [DATA_WIDTH-1:0] alu_result_out,
    output reg [DATA_WIDTH-1:0] rs2_data_out,
    output reg [4:0]            rd_out,
    output reg                  mem_we_out,
    output reg                  valid_out,

    // Branch/jump signals
    output reg                  branch_taken_out,
    output reg [DATA_WIDTH-1:0] branch_target_out
);

    // -------------------------------------------
    // Parameters and Wire/Reg
    // -------------------------------------------

    localparam R_TYPE_OPCODE = 7'b0110011; 
    localparam I_TYPE_OPCODE = 7'b0010011; 
    localparam LOAD_OPCODE   = 7'b0000011; 
    localparam STORE_OPCODE  = 7'b0100011; 
    localparam BRANCH_OPCODE = 7'b1100011; 
    localparam JAL_OPCODE    = 7'b1101111; 
    localparam JALR_OPCODE   = 7'b1100111; 

    localparam [3:0] ALU_ADD = 4'b0000;
    localparam [3:0] ALU_SUB = 4'b0001;
    localparam [3:0] ALU_AND = 4'b0010;
    localparam [3:0] ALU_OR  = 4'b0011;
    localparam [3:0] ALU_XOR = 4'b0100;
    localparam [3:0] ALU_SLL = 4'b0101;
    localparam [3:0] ALU_SRL = 4'b0110;
    localparam [3:0] ALU_SRA = 4'b0111;
    
    
    reg  [3:0]            alu_op;
    reg  [DATA_WIDTH-1:0] alu_in1;
    reg  [DATA_WIDTH-1:0] alu_in2;
    wire [DATA_WIDTH-1:0] alu_result;

    // -------------------------------------------
    // ALU Operation Selection
    // -------------------------------------------
    always @(*) begin
        case (opcode_in)
            R_TYPE_OPCODE: begin
                case (funct3_in)
                    3'b000: alu_op = funct7_in[5] ? ALU_SUB : ALU_ADD;
                    3'b001: 
                    default: 
                endcase
            end
            default: 
        endcase
    end
    
endmodule