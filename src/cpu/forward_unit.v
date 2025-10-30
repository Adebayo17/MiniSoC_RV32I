module forward_unit #(
    parameter REGFILE_ADDR_WIDTH = 5
)  (
    // Decode stage inputs
    input wire [REGFILE_ADDR_WIDTH-1:0] decode_rs1,
    input wire [REGFILE_ADDR_WIDTH-1:0] decode_rs2,
    
    // Execute stage inputs
    input wire [REGFILE_ADDR_WIDTH-1:0] execute_rd,
    input wire                          execute_reg_write,
    input wire                          execute_valid,
    
    // Memory stage inputs
    input wire [REGFILE_ADDR_WIDTH-1:0] memory_rd,
    input wire                          memory_reg_write,
    input wire                          memory_valid,
    
    // Writeback stage inputs
    input wire [REGFILE_ADDR_WIDTH-1:0] writeback_rd,
    input wire                          writeback_reg_write,
    input wire                          writeback_valid,
    
    // Outputs
    output reg [1:0]                    forward_rs1,
    output reg [1:0]                    forward_rs2
    // output reg                          forward_to_decode_rs1,  // NEW: Forward to decode stage
    // output reg                          forward_to_decode_rs2,  // NEW: Forward to decode stage
    // output reg [1:0]                    forward_to_decode_sel   // NEW: Which stage to forward from
);

    // Forwarding selection codes
    localparam [1:0] FROM_REG  = 2'b00;
    localparam [1:0] FROM_MEM  = 2'b01;
    localparam [1:0] FROM_WB   = 2'b10;

    // // NEW: Forward-to-decode selection codes
    // localparam [1:0] FD_NONE   = 2'b00;
    // localparam [1:0] FD_EX     = 2'b01;  // Forward from execute stage to decode
    // localparam [1:0] FD_MEM    = 2'b10;  // Forward from memory stage to decode

    always @(*) begin
        // Default to register file values
        forward_rs1 = FROM_REG;
        forward_rs2 = FROM_REG;

        // forward_to_decode_rs1 = 1'b0;
        // forward_to_decode_rs2 = 1'b0;
        // forward_to_decode_sel = FD_NONE;
        
        // // --------------------------------------------------
        // // DECODE STAGE FORWARDING (NEW)
        // // Handle auipc->addi case: instruction in decode needs result from execute
        // // --------------------------------------------------
        
        // // Check if decode stage needs result from execute stage
        // if (execute_reg_write && execute_valid) begin
        //     if (decode_rs1 == execute_rd && decode_rs1 != 0) begin
        //         forward_to_decode_rs1 = 1'b1;
        //         forward_to_decode_sel = FD_EX;
        //     end
        //     if (decode_rs2 == execute_rd && decode_rs2 != 0) begin
        //         forward_to_decode_rs2 = 1'b1;
        //         forward_to_decode_sel = FD_EX;
        //     end
        // end
        // // Also check memory stage for decode forwarding
        // else if (memory_reg_write && memory_valid) begin
        //     if (decode_rs1 == memory_rd && decode_rs1 != 0) begin
        //         forward_to_decode_rs1 = 1'b1;
        //         forward_to_decode_sel = FD_MEM;
        //     end
        //     if (decode_rs2 == memory_rd && decode_rs2 != 0) begin
        //         forward_to_decode_rs2 = 1'b1;
        //         forward_to_decode_sel = FD_MEM;
        //     end
        // end
        
        // Priority: MEM > WB (MEM has the most recent data)
        
        // RS1 Forwarding
        if (decode_rs1 != 0) begin
            if (memory_reg_write && memory_valid && (memory_rd == decode_rs1)) begin
                forward_rs1 = FROM_MEM;
            end
            else if (writeback_reg_write && writeback_valid && (writeback_rd == decode_rs1)) begin
                forward_rs1 = FROM_WB;
            end
        end
        
        // RS2 Forwarding - same priority order
        if (decode_rs2 != 0) begin
            if (memory_reg_write && memory_valid && (memory_rd == decode_rs2)) begin
                forward_rs2 = FROM_MEM;
            end
            else if (writeback_reg_write && writeback_valid && (writeback_rd == decode_rs2)) begin
                forward_rs2 = FROM_WB;
            end
        end
    end
endmodule