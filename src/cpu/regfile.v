module regfile #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5
)(
    input   wire                    clk,
    input   wire                    rst_n,

    // Read ports
    input   wire [ADDR_WIDTH-1:0]   rs1_addr,
    input   wire [ADDR_WIDTH-1:0]   rs2_addr,
    output  wire [DATA_WIDTH-1:0]   rs1_data,
    output  wire [DATA_WIDTH-1:0]   rs2_data,

    // Write port
    input   wire                    wr_en,
    input   wire [ADDR_WIDTH-1:0]   wr_addr,
    input   wire [DATA_WIDTH-1:0]   wr_data
);

    // Register storage
    reg [DATA_WIDTH-1:0] registers [0:(1<<ADDR_WIDTH)-1];   // 32 Registers (x0...x31)

    // -------------------------------------------
    // Read Logic (combinational)
    // -------------------------------------------
    assign rs1_data = (rs1_addr == 0) ? {DATA_WIDTH{1'b0}} :
                    ((wr_en && (rs1_addr == wr_addr)) ? wr_data : registers[rs1_addr]);

    assign rs2_data = (rs2_addr == 0) ? {DATA_WIDTH{1'b0}} :
                    ((wr_en && (rs2_addr == wr_addr)) ? wr_data : registers[rs2_addr]);

    // -------------------------------------------
    // Write Logic (synchronous)
    // -------------------------------------------
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers to 0 except x0
            for (i = 1; i < (1<<ADDR_WIDTH); i = i + 1) begin
                registers[i] <= 0;
            end
        end else if (wr_en && wr_addr != 0) begin
            registers[wr_addr] <= wr_data;
        end
    end


    // synthesis translate_off

    // -------------------------------------------
    // Debug Access
    // -------------------------------------------
    function [DATA_WIDTH-1:0] get_register;
        input [ADDR_WIDTH-1:0] addr;
        get_register = registers[addr];
    endfunction

    // -------------------------------------------
    // Debug assignments
    // -------------------------------------------

    // Zero register
    wire [DATA_WIDTH-1:0] debug_zero = registers[0];  // x0 = zero

    // Return address
    wire [DATA_WIDTH-1:0] debug_ra   = registers[1];  // x1 = ra

    // Special pointers
    wire [DATA_WIDTH-1:0] debug_sp   = registers[2];  // x2 = sp
    wire [DATA_WIDTH-1:0] debug_gp   = registers[3];  // x3 = gp
    wire [DATA_WIDTH-1:0] debug_tp   = registers[4];  // x4 = tp

    // Temporaries t0–t2
    wire [DATA_WIDTH-1:0] debug_t0   = registers[5];  // x5 = t0
    wire [DATA_WIDTH-1:0] debug_t1   = registers[6];  // x6 = t1
    wire [DATA_WIDTH-1:0] debug_t2   = registers[7];  // x7 = t2

    // Saved registers s0–s1
    wire [DATA_WIDTH-1:0] debug_s0   = registers[8];  // x8  = s0/fp
    wire [DATA_WIDTH-1:0] debug_s1   = registers[9];  // x9  = s1

    // Function arguments / return regs a0–a7
    wire [DATA_WIDTH-1:0] debug_a0   = registers[10]; // x10 = a0
    wire [DATA_WIDTH-1:0] debug_a1   = registers[11]; // x11 = a1
    wire [DATA_WIDTH-1:0] debug_a2   = registers[12]; // x12 = a2
    wire [DATA_WIDTH-1:0] debug_a3   = registers[13]; // x13 = a3
    wire [DATA_WIDTH-1:0] debug_a4   = registers[14]; // x14 = a4
    wire [DATA_WIDTH-1:0] debug_a5   = registers[15]; // x15 = a5
    wire [DATA_WIDTH-1:0] debug_a6   = registers[16]; // x16 = a6
    wire [DATA_WIDTH-1:0] debug_a7   = registers[17]; // x17 = a7

    // Saved registers s2–s11
    wire [DATA_WIDTH-1:0] debug_s2   = registers[18]; // x18 = s2
    wire [DATA_WIDTH-1:0] debug_s3   = registers[19]; // x19 = s3
    wire [DATA_WIDTH-1:0] debug_s4   = registers[20]; // x20 = s4
    wire [DATA_WIDTH-1:0] debug_s5   = registers[21]; // x21 = s5
    wire [DATA_WIDTH-1:0] debug_s6   = registers[22]; // x22 = s6
    wire [DATA_WIDTH-1:0] debug_s7   = registers[23]; // x23 = s7
    wire [DATA_WIDTH-1:0] debug_s8   = registers[24]; // x24 = s8
    wire [DATA_WIDTH-1:0] debug_s9   = registers[25]; // x25 = s9
    wire [DATA_WIDTH-1:0] debug_s10  = registers[26]; // x26 = s10
    wire [DATA_WIDTH-1:0] debug_s11  = registers[27]; // x27 = s11

    // Temporaries t3–t6
    wire [DATA_WIDTH-1:0] debug_t3   = registers[28]; // x28 = t3
    wire [DATA_WIDTH-1:0] debug_t4   = registers[29]; // x29 = t4
    wire [DATA_WIDTH-1:0] debug_t5   = registers[30]; // x30 = t5
    wire [DATA_WIDTH-1:0] debug_t6   = registers[31]; // x31 = t6
    
    // synthesis translate_on

endmodule