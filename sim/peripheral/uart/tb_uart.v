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

    // Status register bits
    localparam STATUS_TX_READY      = 0;
    localparam STATUS_TX_BUSY       = 1;
    localparam STATUS_RX_READY      = 2;
    localparam STATUS_RX_OVERRUN    = 3;
    localparam STATUS_RX_FRAME_ERR  = 4;

    // Control register bits
    localparam CTRL_TX_ENABLE       = 0;
    localparam CTRL_RX_ENABLE       = 1;

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

    reg                     wbs_cyc2;
    reg                     wbs_stb2;
    reg                     wbs_we2;
    reg [ADDR_WIDTH-1:0]    wbs_addr2;
    reg [DATA_WIDTH-1:0]    wbs_data_write2;
    reg [3:0]               wbs_sel2;
    wire [DATA_WIDTH-1:0]   wbs_data_read2;
    wire                    wbs_ack2;

    // UART Physical Interface
    wire uart_tx;
    reg  uart_rx;

    wire uart_tx2;
    reg  uart_rx2;

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

    uart_wrapper #(
        .BASE_ADDR(BASE_ADDR),
        .SIZE_KB(SIZE_KB),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BAUD_DIV_RST(BAUD_DIV_RST)
    ) dut2 (
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .wbs_cyc        (wbs_cyc2       ),
        .wbs_stb        (wbs_stb2       ),
        .wbs_we         (wbs_we2        ),
        .wbs_addr       (wbs_addr2      ),
        .wbs_data_write (wbs_data_write2),
        .wbs_sel        (wbs_sel2       ),
        .wbs_data_read  (wbs_data_read2 ),
        .wbs_ack        (wbs_ack2       ),
        .uart_tx        (uart_tx2       ),
        .uart_rx        (uart_rx2       )
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
        test_num = 3;
        $display("\n[TEST %0d] UART Loopback Test: Starting", test_num);
        task_error_count = 0;
        test_loopback(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] UART Loopback Test: Completed\n", test_num);

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

            // Check initial status - should be TX_READY=1 TX_BUSY=0
            wb_read(32'h2000_0010, read_data);
            if (read_data[STATUS_TX_READY] !== 1'b1) begin
                $display("ERROR: TX_READY not set initially");
                error_count = error_count + 1;
            end
            if (read_data[STATUS_TX_BUSY] !== 1'b0) begin
                $display("ERROR: TX_BUSY set initially");
                error_count = error_count + 1;
            end

            // Send data 
            wb_write(32'h2000_0000, test_data, 4'b0001);

            // Check status immediately after write - should be TX_BUSY=1 TX_READY=0
            // Small delay to allow status update
            #(CLK_PERIOD*2); 
            wb_read(32'h2000_0010, read_data);
            if (read_data[STATUS_TX_BUSY] !== 1'b1) begin
                $display("ERROR: TX_BUSY not set after transmission start");
                error_count = error_count + 1;
            end
            if (read_data[STATUS_TX_READY] !== 1'b0) begin 
                $display("ERROR: TX_READY not cleared after transmission start");
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

            
            // Check status after transmission - should be TX_READY
            wb_read(32'h2000_0010, read_data);
            if (read_data[STATUS_TX_READY] !== 1'b1) begin // TX_READY should be set
                $display("ERROR: TX_READY status not set after transmission");
                $display("  Expected: 1, Got: %b", read_data[0]);
                error_count = error_count + 1;
            end
            if (read_data[STATUS_TX_BUSY] !== 1'b0) begin // TX_BUSY should be clear
                $display("ERROR: TX_BUSY status not cleared after transmission");
                error_count = error_count + 1;
            end

            $display("Transmitter test completed with %0d errors", error_count);
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
            
            $display("Receiver test completed with %0d errors", error_count);
        end
    endtask

    always @(*) begin
        if (test_num == 3) begin
            uart_rx2 = uart_tx;
            uart_rx  = uart_tx2;
        end
    end

    task test_loopback;
        output [31:0] error_count;
        reg [DATA_WIDTH-1:0] read_data;
        reg [7:0] test_data;
        integer bit_time;
        begin
            error_count = 0;
            read_data = 0;
            bit_time = (CLK_PERIOD * BAUD_DIV);
            test_data = 8'hBB;
            
            $display("\n=== Dual UART Loopback Test ===");
            $display("Using DUT2 for transmission, DUT1 for reception");
            
            // Configure both UARTs with same settings
            // Configure DUT1 (receiver)
            wb_write(32'h2000_0008, BAUD_DIV, 4'b1111);
            wb_write(32'h2000_000C, 32'h0000_0003, 4'b1111); // Enable TX and RX
            
            // Configure DUT2 (transmitter) - use different base address if needed
            // Note: You may need to adjust the address for DUT2 if it has different base
            wb_write2(32'h2000_0008, BAUD_DIV, 4'b1111);
            wb_write2(32'h2000_000C, 32'h0000_0003, 4'b1111); // Enable TX and RX
            
            // Connect DUT2 TX to DUT1 RX
            // uart_rx = uart_tx2;
            $display("Connected DUT2_TX -> DUT1_RX");
            
            // Send data using DUT2
            $display("Sending data via DUT2: %h", test_data);
            wb_write2(32'h2000_0000, test_data, 4'b0001);
            
            // Wait for transmission to complete (check DUT2 status)
            $display("Waiting for DUT2 transmission to complete...");
            #(bit_time * 12); // Wait for full transmission
            
            // Check DUT2 status to confirm transmission completed
            wb_read2(32'h2000_0010, read_data);
            if (read_data[STATUS_TX_READY] !== 1'b1) begin
                $display("ERROR: DUT2 TX_READY not set after transmission");
                error_count = error_count + 1;
            end
            
            // Wait a bit for reception by DUT1
            #(bit_time * 2);
            
            // Check if data was received by DUT1
            wb_read(32'h2000_0010, read_data);
            $display("DUT1 Status: TX_READY=%b, TX_BUSY=%b, RX_READY=%b, RX_OVERRUN=%b, RX_FRAME_ERR=%b",
                    read_data[STATUS_TX_READY], read_data[STATUS_TX_BUSY], 
                    read_data[STATUS_RX_READY], read_data[STATUS_RX_OVERRUN], 
                    read_data[STATUS_RX_FRAME_ERR]);
            
            if (read_data[STATUS_RX_READY] !== 1'b1) begin
                $display("ERROR: DUT1 RX_READY not set");
                if (read_data[STATUS_RX_FRAME_ERR]) begin
                    $display("Frame error detected - check stop bits");
                end
                error_count = error_count + 1;
            end
            
            // Read received data from DUT1
            wb_read(32'h2000_0004, read_data);
            $display("DUT1 Received data: %h", read_data[7:0]);
            
            if (read_data[7:0] !== test_data) begin
                $display("ERROR: Data mismatch: expected %h, got %h", 
                        test_data, read_data[7:0]);
                error_count = error_count + 1;
            end else begin
                $display("SUCCESS: Data correctly received by DUT1");
            end
            
            // Test multiple bytes
            $display("\nTesting multiple bytes...");
            for (integer j = 0; j < 3; j = j + 1) begin
                test_data = 8'hA0 + j;
                
                // Send from DUT2
                wb_write2(32'h2000_0000, test_data, 4'b0001);
                
                // Wait for transmission and reception
                #(bit_time * 14);
                
                // Read from DUT1
                wb_read(32'h2000_0004, read_data);
                if (read_data[7:0] !== test_data) begin
                    $display("ERROR: Byte %0d mismatch: expected %h, got %h", 
                            j, test_data, read_data[7:0]);
                    error_count = error_count + 1;
                end else begin
                    $display("Byte %0d: %h -> %h ✓", j, test_data, read_data[7:0]);
                end
            end
            
            // Disconnect
            uart_rx = 1'b1;
            
            if (error_count == 0) begin
                $display("Dual UART loopback test PASSED");
            end else begin
                $display("Dual UART loopback test FAILED with %0d errors", error_count);
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

    // Wishbone tasks for DUT2
    task wb_write2;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [3:0] sel;
        begin
            @(posedge clk);
            wbs_cyc2 = 1;
            wbs_stb2 = 1;
            wbs_we2 = 1;
            wbs_addr2 = addr;
            wbs_data_write2 = data;
            wbs_sel2 = sel;
            
            @(posedge clk);
            while (!wbs_ack2) @(posedge clk);
            
            wbs_cyc2 = 0;
            wbs_stb2 = 0;
            wbs_we2 = 0;
            @(posedge clk);
        end
    endtask

    task wb_read2;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            wbs_cyc2 = 1;
            wbs_stb2 = 1;
            wbs_we2 = 0;
            wbs_addr2 = addr;
            
            @(posedge clk);
            while (!wbs_ack2) @(posedge clk);
            data = wbs_data_read2;
            
            wbs_cyc2 = 0;
            wbs_stb2 = 0;
            @(posedge clk);
        end
    endtask
endmodule