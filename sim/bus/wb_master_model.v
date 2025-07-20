module wb_master_model #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,

    // Wishbone Interface
    output reg                      wb_cyc_o,
    output reg                      wb_stb_o,
    output reg                      wb_we_o,
    output reg [ADDR_WIDTH-1:0]     wb_addr_o,
    output reg [DATA_WIDTH-1:0]     wb_data_o,
    output reg [3:0]                wb_sel_o,
    input wire [DATA_WIDTH-1:0]     wb_data_i,
    input wire                      wb_ack_i
);

    // -------------------------------------------
    // State machine for bus operations
    // -------------------------------------------
    reg [1:0] state;
    reg [ADDR_WIDTH-1:0] addr_reg;
    reg [DATA_WIDTH-1:0] data_reg;
    reg [3:0] sel_reg;
    reg operation_type; // 0=read, 1=write

    parameter IDLE      = 2'b00;
    parameter START     = 2'b01;
    parameter WAIT_ACK  = 2'b10;
    parameter DONE      = 2'b11;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            wb_cyc_o    <= 0;
            wb_stb_o    <= 0;
            wb_we_o     <= 0;
            wb_addr_o   <= 0;
            wb_data_o   <= 0;
            wb_sel_o    <= 0;
        end else begin
            case (state)
                IDLE: begin
                    wb_cyc_o <= 0;
                    wb_stb_o <= 0;
                    wb_we_o  <= 0;
                end 

                START: begin
                    wb_cyc_o    <= 1;
                    wb_stb_o    <= 1;
                    wb_we_o     <= operation_type;
                    wb_addr_o   <= addr_reg;
                    wb_sel_o    <= sel_reg;
                    if (operation_type) wb_data_o <= data_reg;
                    state       <= WAIT_ACK;
                end

                WAIT_ACK: begin
                    if (wb_ack_i) begin
                        wb_cyc_o <= 0;
                        wb_stb_o <= 0;
                        wb_we_o <= 0;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // -------------------------------------------
    // Task for write operation with SEL
    // -------------------------------------------
    reg write_req;
    wire write_done = (state == DONE) && operation_type;

    // Call this task from testbench to initiate write
    task wb_write_sel;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [3:0] sel; // Byte select

        begin
            @(posedge clk);
            addr_reg = addr;
            data_reg = data;
            sel_reg  = sel;
            operation_type = 1;
            write_req = 1;
            @(posedge clk);
            write_req = 0;
            wait(write_done);
        end
    endtask

    // Overload for default SEL (all bytes)
    task wb_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        
        begin
            wb_write_sel(addr, data, 4'b1111); // Default to all bytes selected
        end
    endtask

    // -------------------------------------------
    // Function for read operation
    // -------------------------------------------
    reg read_req;
    wire [DATA_WIDTH-1:0] read_data = wb_data_i;
    wire read_done = (state == DONE) && !operation_type;
    
    // Call this task from testbench to initiate read
    task wb_read_sel;
        input [ADDR_WIDTH-1:0] addr;
        input [3:0] sel; // Byte select
        output [DATA_WIDTH-1:0] read_data_out;
        
        begin
            @(posedge clk);
            addr_reg = addr;
            sel_reg = sel; 
            operation_type = 0;
            read_req = 1;
            @(posedge clk);
            read_req = 0;
            wait(read_done);
            read_data_out = read_data;
        end
    endtask

    // Overload for default SEL
    task wb_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        
        begin
            wb_read_sel(addr, 4'b1111, data); // Default to all bytes
        end
    endtask

    // Trigger operations when requested
    always @(posedge clk) begin
        if (state == IDLE) begin
            if (write_req) begin
                state <= START;
            end
            else if (read_req) begin
                state <= START;
            end
        end
    end
endmodule

// To comment CTRL+K then CTRL+C 
// To uncomment CTRL+K then CTRL+U