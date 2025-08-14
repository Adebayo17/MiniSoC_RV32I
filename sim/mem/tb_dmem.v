`timescale 1ns/1ps

module tb_dmem;
    // Parameters
    parameter CLK_PERIOD = 10;  // 100 MHz
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter BASE_ADDR  = 32'h1000_0000;
    parameter SIZE_KB    = 4;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Test Control
    reg [31:0] test_num;
    reg [8*40:1] test_name;
    reg [31:0] task_error_count;
    reg [31:0] total_errors;

    // Wishbone Interface
    reg wbs_cyc;
    reg wbs_stb;
    reg wbs_we;
    reg [ADDR_WIDTH-1:0] wbs_addr;
    reg [DATA_WIDTH-1:0] wbs_data_write;
    reg [3:0] wbs_sel;
    wire [DATA_WIDTH-1:0] wbs_data_read;
    wire wbs_ack;

    // Initialization Interface
    reg init_en;
    reg [ADDR_WIDTH-1:0] init_addr;
    reg [DATA_WIDTH-1:0] init_data;

    // Instantiate DUT
    dmem_wrapper #(
        .BASE_ADDR(BASE_ADDR),
        .SIZE_KB(SIZE_KB),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wbs_cyc(wbs_cyc),
        .wbs_stb(wbs_stb),
        .wbs_we(wbs_we),
        .wbs_addr(wbs_addr),
        .wbs_data_write(wbs_data_write),
        .wbs_sel(wbs_sel),
        .wbs_data_read(wbs_data_read),
        .wbs_ack(wbs_ack),
        .init_en(init_en),
        .init_addr(init_addr),
        .init_data(init_data)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset Generation
    initial begin
        rst_n = 0;
        #100 rst_n = 1;
    end

    // Main Test Sequence
    initial begin
        // Initialize
        test_num = 0;
        test_name = "";
        total_errors = 0;
        task_error_count = 0;

        // Open waveform file
        $dumpfile("dmem_tb.vcd");
        $dumpvars(0, tb_dmem);

        // Wait for reset to complete
        @(posedge rst_n);
        #(CLK_PERIOD*2);

        // Run test cases
        $display("\n[TESTBENCH DMEM][TEST 1] BASIC READ/WRITE: Starting");
        test_num = 1;
        test_name = "Basic Read/Write";
        test_basic_rw(task_error_count);
        total_errors = total_errors + task_error_count;
        $display("\n[TESTBENCH DMEM][TEST 1] BASIC READ/WRITE: Completed");

        $display("\n[TESTBENCH DMEM][TEST 2] BYTE ACCESS: Starting");
        test_num = 2;
        test_name = "Byte Access";
        test_byte_access(task_error_count);
        total_errors = total_errors + task_error_count;
        $display("\n[TESTBENCH DMEM][TEST 2] BYTE ACCESS: Completed");

        $display("\n[TESTBENCH DMEM][TEST 3] INITIALIZATION: Starting");
        test_num = 3;
        test_name = "Initialization";
        test_initialization(task_error_count);
        total_errors = total_errors + task_error_count;
        $display("\n[TESTBENCH DMEM][TEST 3] INITIALIZATION: Completed");

        // Summary
        $display("\nTestbench completed with %0d total errors", total_errors);
        $finish;
    end

    // -------------------------------------------
    // Test Tasks
    // -------------------------------------------

    task test_basic_rw;
        output [31:0] error_count;
        reg [DATA_WIDTH-1:0] write_data, read_data;
        integer i;
        begin
            error_count = 0;
            
            // Test full word writes and reads
            for (i = 0; i < 4; i = i + 1) begin
                write_data = 32'hA5A5_A5A5 + i;
                
                // Write operation
                wb_write(BASE_ADDR + (i * 4), write_data, 4'b1111);
                
                // Read operation
                wb_read(BASE_ADDR + (i * 4), read_data);
                
                if (read_data !== write_data) begin
                    $display("ERROR: Data mismatch at addr %h: Wrote %h, Read %h", 
                            BASE_ADDR + (i * 4), write_data, read_data);
                    error_count = error_count + 1;
                end
            end
        end
    endtask

    task test_byte_access;
        output [31:0] error_count;
        reg [DATA_WIDTH-1:0] write_data, read_data, expected;
        integer i;
        begin
            error_count = 0;
            
            // Test each byte lane
            for (i = 0; i < 4; i = i + 1) begin
                write_data = 32'h0000_00A5 << (i * 8);
                
                // Write with byte select
                wb_write(BASE_ADDR + (i * 4), write_data, (1 << i));
                
                // Read back full word
                wb_read(BASE_ADDR + (i * 4), read_data);
                
                expected = 32'h0;
                case (i)
                    0: expected[7:0]   = 8'hA5;
                    1: expected[15:8]  = 8'hA5;
                    2: expected[23:16] = 8'hA5;
                    3: expected[31:24] = 8'hA5;
                endcase
                
                if (read_data !== expected) begin
                    $display("ERROR: Byte access failed @ %h: Expected %h, Got %h", 
                            BASE_ADDR + (i * 4), expected, read_data);
                    error_count = error_count + 1;
                end
            end
        end
    endtask

    task test_initialization;
        output [31:0] error_count;
        reg [DATA_WIDTH-1:0] read_data;
        integer i;
        begin
            error_count = 0;
            
            // Initialize memory
            for (i = 0; i < 4; i = i + 1) begin
                init_en = 1;
                init_addr = BASE_ADDR + (i * 4);
                init_data = 32'h12345678 + i;
                @(posedge clk);
            end
            init_en = 0;
            
            // Verify initialization
            for (i = 0; i < 4; i = i + 1) begin
                wb_read(BASE_ADDR + (i * 4), read_data);
                
                if (read_data !== (32'h12345678 + i)) begin
                    $display("ERROR: Initialization failed @ %h: Expected %h, Got %h", 
                            BASE_ADDR + (i * 4), 32'h12345678 + i, read_data);
                    error_count = error_count + 1;
                end
            end
        end
    endtask

    // -------------------------------------------
    // Wishbone Bus Tasks
    // -------------------------------------------

    task wb_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [3:0] sel;
        begin
            @(posedge clk);
            wbs_cyc = 1;
            wbs_stb = 1;
            wbs_we = 1;
            wbs_addr = addr;
            wbs_data_write = data;
            wbs_sel = sel;
            
            @(posedge clk);
            while (!wbs_ack) @(posedge clk);
            
            wbs_cyc = 0;
            wbs_stb = 0;
            wbs_we = 0;
            @(posedge clk);
        end
    endtask

    task wb_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            wbs_cyc = 1;
            wbs_stb = 1;
            wbs_we = 0;
            wbs_addr = addr;
            
            @(posedge clk);
            while (!wbs_ack) @(posedge clk);
            data = wbs_data_read;
            
            wbs_cyc = 0;
            wbs_stb = 0;
            @(posedge clk);
        end
    endtask

endmodule