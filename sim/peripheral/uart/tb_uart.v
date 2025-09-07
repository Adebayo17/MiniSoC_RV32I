`timescale 1ns/1ps

module tb_uart;
    // Parameters
    parameter CLK_PERIOD    = 10; // 100MHz
    parameter BAUD_RATE     = 115200;
    parameter CLK_FREQ      = 100_000_000;
    parameter BAUD_DIV      = CLK_FREQ / BAUD_RATE;
    parameter ADDR_WIDTH    = 32;
    parameter DATA_WIDTH    = 32;
    parameter BASE_ADDR     = 32'h2000_0000;
    parameter SIZE_KB       = 4;
    parameter BAUD_DIV_RST  = 16'd104;

    // Clock and reset
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

    // UART Physical Interface
    wire uart_tx;
    reg  uart_rx;

    // Testbench Signals
    reg [7:0] tx_data;
    reg [7:0] rx_data;
    integer i;

    // Instantiate DUT
    uart_wrapper #(
        .BASE_ADDR(BASE_ADDR),
        .SIZE_KB(SIZE_KB),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BAUD_DIV_RST(BAUD_DIV_RST)
    ) dut (
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .wbs_cyc        (wbs_cyc        ),
        .wbs_stb        (wbs_stb        ),
        .wbs_we         (wbs_we         ),
        .wbs_addr       (wbs_addr       ),
        .wbs_data_write (wbs_data_write ),
        .wbs_sel        (wbs_sel        ),
        .wbs_data_read  (wbs_data_read  ),
        .wbs_ack        (wbs_ack        ),
        .uart_tx        (uart_tx        ),
        .uart_rx        (uart_rx        )
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset Generation 
    initial begin
        rst_n           = 0;
        
        uart_rx         = 1'b1;
        wbs_cyc         = 0; 
        wbs_stb         = 0; 
        wbs_we          = 0;
        wbs_addr        = 0; 
        wbs_data_write  = 0; 
        wbs_sel         = 0;

        test_num         = 0;
        total_errors     = 0;
        task_error_count = 0;

        #100 rst_n    = 1;   
    end

    // Main Test Sequence
    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, tb_uart);

        wait(rst_n);
        #(CLK_PERIOD*2);

        $display("\n=== UART Testbench Started ===");

        // Test 1: Basic Configuration
        test_num = 1;
        $display("\n[TEST %0d] UART Configuration: Starting", test_num);
        task_error_count = 0;
        test_uart_configuration(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] UART Configuration: Completed\n", test_num);

        #(CLK_PERIOD*2);
        // Test 2: Transmitter
        test_num = 2;
        $display("\n[TEST %0d] UART Transmitter Test: Starting", test_num);
        task_error_count = 0;
        test_uart_transmitter(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] UART Transmitter Test: Completed\n", test_num);

        // Test 3: Receiver
        test_num = 3;
        $display("\n[TEST %0d] UART Receiver Test: Starting", test_num);
        task_error_count = 0;
        test_uart_receiver(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] UART Receiver Test: Completed\n", test_num);

        // Test 4: Loopback (TX -> RX)
        // test_num = 3;
        // $display("\n[TEST %0d] UART Loopback Test: Starting", test_num);
        // task_error_count = 0;
        // test_loopback(task_error_count);
        // total_errors += task_error_count;
        // $display("[TEST %0d] UART Loopback Test: Completed\n", test_num);

        // Summary
        $display("\n=== UART Testbench Completed ===");
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
    task test_uart_configuration;
        output [31:0] error_count;
        reg [DATA_WIDTH-1:0] read_data;
        begin
            error_count = 0;
            read_data = 0;

            // Set baud rate
            wb_write(32'h2000_0008, BAUD_DIV, 4'b1111);

            // Enable TX and RX
            wb_write(32'h2000_000C, 32'h0000_0003, 4'b1111);

            // Read back Configuration
            wb_read(32'h2000_0008, read_data);
            if (read_data[15:0] !== BAUD_DIV) begin
                $display(":ERROR: Baud rate configuration failed");
                error_count = error_count + 1;
            end

            wb_read(32'h2000_000C, read_data);
            if (read_data[0] !== 1'b1 || read_data[1] !== 1'b1) begin
                $display("ERROR: Control register configuration failed");
                error_count = error_count + 1;
            end

            $display("Configuration test completed");
        end
    endtask

    task test_uart_transmitter;
        output [31:0] error_count;
        reg [7:0] test_data;
        reg [DATA_WIDTH-1:0] read_data;
        integer bit_time;
        begin
            error_count = 0;
            read_data = 0;

            bit_time = (CLK_PERIOD * BAUD_DIV);
            test_data = 8'hA5;

            // Check initial status - should be TX_EMPTY
            wb_read(32'h2000_0010, read_data);
            if (read_data[0] !== 1'b1) begin
                $display("ERROR: TX_EMPTY not set initially");
                error_count = error_count + 1;
            end

            // Send data 
            wb_write(32'h2000_0000, test_data, 4'b0001);

            // Check status immediately after write - should be TX_BUSY
            #10; // Small delay to allow status update
            wb_read(32'h2000_0010, read_data);
            if (read_data[1] !== 1'b1) begin // TX_BUSY should be set
                $display("ERROR: TX_BUSY not set after transmission start");
                error_count = error_count + 1;
            end
            if (read_data[0] !== 1'b0) begin // TX_EMPTY should be clear
                $display("ERROR: TX_EMPTY not cleared after transmission start");
                error_count = error_count + 1;
            end

            // Wait for transmission to start 
            #(bit_time * 0.5);

            // Verify start bit (should be low)
            if (uart_tx !== 0 ) begin
                $display("ERROR: Start bit not detected");
                error_count = error_count + 1;
            end

            // Verify data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                #(bit_time);
                if (uart_tx !== test_data[i]) begin
                    $display("ERROR: Data bit %0d incorrect: expected %b, got %b", i, test_data[i], uart_tx);
                    error_count = error_count + 1;
                end
            end

            // Verify stop bit (should be high)
            #(bit_time);
            if (uart_tx !== 1'b1) begin
                $display("ERROR: Stop bit not detected");
                error_count = error_count + 1;
            end 

            // // Wait for transmission to complete
            // #(bit_time * 10); // Wait for full transmission (start + 8 data + stop)
            
            Check status after transmission - should be TX_EMPTY
            wb_read(32'h2000_0010, read_data);
            if (read_data[0] !== 1'b1) begin // TX_EMPTY should be set
                $display("ERROR: TX_EMPTY status not set after transmission");
                $display("  Expected: 1, Got: %b", read_data[0]);
                error_count = error_count + 1;
            end
            if (read_data[1] !== 1'b0) begin // TX_BUSY should be clear
                $display("ERROR: TX_BUSY status not cleared after transmission");
                error_count = error_count + 1;
            end

            $display("Transmitter test completed");
        end
    endtask


    task test_uart_receiver;
        output [31:0] error_count;
        reg [7:0] test_data;
        reg [DATA_WIDTH-1:0] read_data;
        integer bit_time;
        begin
            error_count = 0;
            read_data = 0;

            bit_time = (CLK_PERIOD * BAUD_DIV);
            test_data = 8'h5A;
            
            // Send data to receiver (simulate external device)
            uart_rx = 1'b1; // Idle
            #(bit_time * 2);
            
            // Start bit
            uart_rx = 1'b0;
            #(bit_time);
            
            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = test_data[i];
                #(bit_time);
            end
            
            // Stop bit
            uart_rx = 1'b1;
            #(bit_time);
            
            // Check if data was received
            wb_read(32'h2000_0010, read_data);
            if (read_data[2] !== 1'b1) begin // RX_READY should be set
                $display("ERROR: RX_READY status not set after reception");
                error_count = error_count + 1;
            end
            
            // Read received data
            wb_read(32'h2000_0004, read_data);
            if (read_data[7:0] !== test_data) begin
                $display("ERROR: Received data incorrect: expected %h, got %h",
                        test_data, read_data[7:0]);
                error_count = error_count + 1;
            end
            
            // Check that RX_READY is cleared after read
            wb_read(32'h2000_0010, read_data);
            if (read_data[2] !== 1'b0) begin
                $display("ERROR: RX_READY status not cleared after read");
                error_count = error_count + 1;
            end
            
            $display("Receiver test completed");
        end
    endtask
    
    task test_loopback;
        output [31:0] error_count;
        reg [DATA_WIDTH-1:0] read_data;
        reg [7:0] test_data;
        begin
            error_count = 0;
            read_data = 0;

            test_data = 8'hAA;
            
            // Send data
            wb_write(32'h2000_0000, test_data, 4'b0001);
            
            // Wait for transmission to complete
            #(CLK_PERIOD * BAUD_DIV * 12); // 12 bit times (start + 8 data + stop + margin)
            
            // Feed TX output back to RX input (loopback)
            uart_rx = uart_tx;
            
            // Wait for reception
            #(CLK_PERIOD * BAUD_DIV * 12);
            
            // Read received data
            wb_read(32'h2000_0004, read_data);
            if (read_data[7:0] !== test_data) begin
                $display("ERROR: Loopback test failed: expected %h, got %h",
                        test_data, read_data[7:0]);
                error_count = error_count + 1;
            end else begin
                $display("Loopback test successful: TX -> RX works correctly");
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