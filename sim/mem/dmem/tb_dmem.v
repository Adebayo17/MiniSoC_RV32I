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
    reg [31:0]   test_num;
    reg [8*40:1] test_name;
    reg [31:0]   task_error_count;
    reg [31:0]   total_errors;

    // Wishbone Interface
    reg                     wbs_cyc;
    reg                     wbs_stb;
    reg                     wbs_we;
    reg [ADDR_WIDTH-1:0]    wbs_addr;
    reg [DATA_WIDTH-1:0]    wbs_data_write;
    reg [3:0]               wbs_sel;
    wire [DATA_WIDTH-1:0]   wbs_data_read;
    wire                    wbs_ack;

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

        // Init signals to safe values
        wbs_cyc         = 0; 
        wbs_stb         = 0; 
        wbs_we          = 0;
        wbs_addr        = 0; 
        wbs_data_write  = 0; 
        wbs_sel         = 0;
        init_en         = 0; 
        init_addr       = 0; 
        init_data       = 0;

        #100 rst_n = 1;
    end

    // Main Test Sequence
    initial begin
        total_errors = 0;
        task_error_count = 0;

        $dumpfile("dmem_tb.vcd");
        $dumpvars(0, tb_dmem);

        wait(rst_n);
        #(CLK_PERIOD*2);

        $display("\n=== DMEM Testbench Started ===");

        $display("\n[TEST 1] BASIC READ/WRITE: Starting");
        task_error_count = 0;
        test_basic_rw(task_error_count);
        total_errors += task_error_count;
        $display("[TEST 1] Completed\n");

        $display("\n[TEST 2] BYTE ACCESS: Starting");
        task_error_count = 0;
        test_byte_access(task_error_count);
        total_errors += task_error_count;
        $display("[TEST 2] Completed\n");

        $display("\n[TEST 3] INITIALIZATION: Starting");
        task_error_count = 0;
        test_initialization(task_error_count);
        total_errors += task_error_count;
        $display("[TEST 3] Completed\n");


        // Summary
        $display("\n=== DMEM Testbench Completed ===");
        $display("\nTotal errors: %0d", total_errors);
        if (total_errors == 0) begin
            $display("✅ All tests PASSED!");
        end else begin
            $display("❌ Some tests FAILED");
        end
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
            for (i = 0; i < 4; i++) begin
                write_data = 32'hA5A5_A5A5 + i;
                wb_write(BASE_ADDR + (i * 4), write_data, 4'b1111);
                wb_read(BASE_ADDR + (i * 4), read_data);
                if (read_data !== write_data) begin
                    $display("ERROR: @%h Wrote %h, Read %h", 
                              BASE_ADDR + (i * 4), write_data, read_data);
                    error_count++;
                end
            end
        end
    endtask

    task test_byte_access;
        output [31:0] error_count;
        reg [DATA_WIDTH-1:0] current_value, write_data, read_data, expected;
        integer i;
        begin
            error_count = 0;

            // First, clear the memory location
            wb_write(BASE_ADDR, 32'h00000000, 4'b1111);
            wb_read(BASE_ADDR, read_data);
            if (read_data != write_data) begin
                $display("Memory at @%h not cleared properly", BASE_ADDR);
            end else begin
                $display("Memory at @%h cleared", BASE_ADDR);
            end
            
            // Test each byte lane with read-modify-write approach
            for (i = 0; i < 4; i = i + 1) begin
                // First read the current value
                wb_read(BASE_ADDR, current_value);
                
                // Prepare write data - set only the target byte to A5
                write_data = current_value; // Start with current value
                write_data[i*8 +: 8] = 8'hA5; // Modify only the target byte
                
                // Write with byte select - only modify the target byte
                wb_write(BASE_ADDR, write_data, (1 << i));
                
                // Read back to verify
                wb_read(BASE_ADDR, read_data);
                
                // Expected value should be the original with only the target byte changed
                expected = current_value;
                expected[i*8 +: 8] = 8'hA5;
                
                if (read_data !== expected) begin
                    $display("ERROR: Byte access failed for byte %0d:", i);
                    $display("  Original: %h", current_value);
                    $display("  Expected: %h", expected);
                    $display("  Got:      %h", read_data);
                    error_count = error_count + 1;
                end
            end
            
            // Test reading individual bytes from a known pattern
            $display("\nTesting byte reading from known pattern...");
            
            // Write a known pattern
            wb_write(BASE_ADDR + 4, 32'hAABBCCDD, 4'b1111);
            
            for (i = 0; i < 4; i = i + 1) begin
                // Read back the full word
                wb_read(BASE_ADDR + 4, read_data);
                
                // Extract and verify each byte
                case (i)
                    0: expected = 8'hDD;
                    1: expected = 8'hCC;
                    2: expected = 8'hBB;
                    3: expected = 8'hAA;
                endcase
                
                if (read_data[i*8 +: 8] !== expected) begin
                    $display("ERROR: Byte read failed for byte %0d: Expected %h, Got %h", 
                            i, expected, read_data[i*8 +: 8]);
                    error_count = error_count + 1;
                end
            end
            
            // Additional test: verify that unwritten bytes are preserved
            $display("\nTesting that unwritten bytes are preserved...");
            
            // Write initial pattern
            wb_write(BASE_ADDR + 8, 32'h12345678, 4'b1111);
            
            // Read current value
            wb_read(BASE_ADDR + 8, current_value);
            
            // Modify only byte 1 (keep others unchanged)
            write_data = current_value;
            write_data[15:8] = 8'hAA; // Modify byte 1
            
            wb_write(BASE_ADDR + 8, write_data, 4'b0010); // Only write byte 1
            
            // Read back and verify
            wb_read(BASE_ADDR + 8, read_data);
            
            expected = 32'h1234AA78; // Only byte 1 should change
            
            if (read_data !== expected) begin
                $display("ERROR: Byte preservation failed:");
                $display("  Original: %h", current_value);
                $display("  Expected: %h", expected);
                $display("  Got:      %h", read_data);
                error_count = error_count + 1;
            end
        end
    endtask

    task test_initialization;
        output [31:0] error_count;
        reg [DATA_WIDTH-1:0] read_data;
        integer i;
        begin
            error_count = 0;
            
            // Initialize memory with single-cycle pulses
            for (i = 0; i < 8; i = i + 1) begin
                init_write(BASE_ADDR + (i * 4), 32'h12345678 + i);
            end

            // Wait a couple cycles
            @(posedge clk);
            @(posedge clk);

            // Verify initialization
            for (i = 0; i < 8; i = i + 1) begin
                @(posedge clk);
                wb_read(BASE_ADDR + (i * 4), read_data);
                
                if (read_data !== (32'h12345678 + i)) begin
                    $display("ERROR: Init failed @%h Exp=%h Got=%h", 
                            BASE_ADDR + (i * 4), 32'h12345678 + i, read_data);
                    error_count = error_count + 1;
                end
            end
        end
    endtask

    // Helper task for initialization writes
    task init_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            init_en = 1;
            init_addr = addr;
            init_data = data;
            $display("[INFO]: Testbench Initialization @%h Data=%h", addr, data);
            
            // Wait for the clock edge to ensure memory captures the values
            @(posedge clk);
            
            // Keep signals stable for a small delay after clock edge
            #1;

            // The deassert
            init_en = 0;
            init_addr = 0;
            init_data = 0;
            
            // Wait a bit before next initialization
            #(CLK_PERIOD/4);
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
            wbs_cyc = 1; wbs_stb = 1; wbs_we = 1;
            wbs_addr = addr; wbs_data_write = data; wbs_sel = sel;
            wait (wbs_ack);
            @(posedge clk);
            wbs_cyc = 0; wbs_stb = 0; wbs_we = 0;
            @(posedge clk);
        end
    endtask

    task wb_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            wbs_cyc = 1; wbs_stb = 1; wbs_we = 0;
            wbs_addr = addr; wbs_sel = 4'b1111;
            wait (wbs_ack);
            data = wbs_data_read;
            @(posedge clk);
            wbs_cyc = 0; wbs_stb = 0;
            @(posedge clk);
        end
    endtask
endmodule

