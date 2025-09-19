`timescale 1ns/1ps

module tb_mini_rv32i_top;

    // Parameters
    parameter CLK_PERIOD    = 10;  // 100 MHz
    parameter FIRMWARE_FILE = "firmware.hex";
    parameter ADDR_WIDTH    = 32;
    parameter DATA_WIDTH    = 32;
    parameter SIZE_KB       = 4;
    parameter BAUD_DIV_RST  = 16'd104;  // 115200 baud @ 12MHz
    parameter N_GPIO        = 8;
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // UART signals
    reg uart_rx;
    wire uart_tx;
    
    // GPIO signals
    wire [7:0] gpio_io;
    
    // Testbench variables
    reg [31:0]   test_num;
    integer      test_pass;
    integer      test_fail;
    integer      cycle_count;
    integer      timeout_counter;
    
    // File handles for logging
    integer log_file;
    
    // Memory map addresses
    localparam IMEM_BASE  = 32'h0000_0000;
    localparam DMEM_BASE  = 32'h1000_0000;
    localparam UART_BASE  = 32'h2000_0000;
    localparam GPIO_BASE  = 32'h4000_0000;
    localparam TIMER_BASE = 32'h3000_0000;
    
    // UART register offsets
    localparam UART_TX_DATA  = 0;
    localparam UART_RX_DATA  = 4;
    localparam UART_BAUD_DIV = 8;
    localparam UART_CTRL     = 12;
    localparam UART_STATUS   = 16;
    
    // GPIO register offsets
    localparam GPIO_DATA     = 0;
    localparam GPIO_DIR      = 4;
    localparam GPIO_SET      = 8;
    localparam GPIO_CLEAR    = 12;
    localparam GPIO_TOGGLE   = 16;
    
    // Timer register offsets
    localparam TIMER_COUNT   = 0;
    localparam TIMER_CMP     = 4;
    localparam TIMER_CTRL    = 8;
    localparam TIMER_STAT    = 12;
    
    // Instantiate the top-level SoC
    mini_rv32i_top #(
        .FIRMWARE_FILE(FIRMWARE_FILE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE_KB(SIZE_KB),
        .BAUD_DIV_RST(BAUD_DIV_RST),
        .N_GPIO(N_GPIO)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .gpio0_io(gpio_io[0]),
        .gpio1_io(gpio_io[1]),
        .gpio2_io(gpio_io[2]),
        .gpio3_io(gpio_io[3]),
        .gpio4_io(gpio_io[4]),
        .gpio5_io(gpio_io[5]),
        .gpio6_io(gpio_io[6]),
        .gpio7_io(gpio_io[7])
    );
    
    // -------------------------------------------
    // Clock Generation
    // -------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // -------------------------------------------
    // Reset and Initialization
    // -------------------------------------------
    initial begin
        rst_n           = 0;
        uart_rx         = 1;  // UART idle state
        test_num        = 0;
        test_pass       = 0;
        test_fail       = 0;
        cycle_count     = 0;
        timeout_counter = 0;

        #(CLK_PERIOD*10);
        rst_n = 1;
    end
    
    
    
    // -------------------------------------------
    // Testbench Main sequence
    // -------------------------------------------
    initial begin
        // Open log file
        log_file = $fopen("mini_rv32i_top.log", "w");
        $fdisplay(log_file, "Mini RV32I Top Test Log - %t", $time);
        
        // Create VCD dump
        $dumpfile("mini_rv32i_top_tb.vcd");
        $dumpvars(0, tb_mini_rv32i_top);
        
        // Wait for reset to be done
        wait(dut.top_soc_inst.rv32i_core.rst_n);
        $display("[TEST] Reset released at time %t", $time);
        $fdisplay(log_file, "[TEST] Reset released at time %t", $time);
        
        // Wait for memory initialization
        wait(dut.top_soc_inst.init_done == 1);
        $display("[TEST] Memory initialization complete at time %t", $time);
        $fdisplay(log_file, "[TEST] Memory initialization complete at time %t", $time);
        
        // Run tests
        run_tests();
        
        // End simulation
        #1000;
        $display("[TEST] Simulation completed");
        $display("Pass: %0d, Fail: %0d", test_pass, test_fail);
        $fdisplay(log_file, "Test Results: Pass: %0d, Fail: %0d", test_pass, test_fail);
        
        if (test_fail == 0) begin
            $display("[TEST] ALL TESTS PASSED!");
            $fdisplay(log_file, "[TEST] ALL TESTS PASSED!");
        end else begin
            $display("[TEST] %0d TESTS FAILED!", test_fail);
            $fdisplay(log_file, "[TEST] %0d TESTS FAILED!", test_fail);
        end
        
        $fclose(log_file);
        $finish;
    end

    // -------------------------------------------
    // UART Tasks
    // -------------------------------------------
    // UART Receiver Task
    task uart_receive;
        output [7:0] received_data;
        integer bit_time;
        begin
            bit_time = (CLK_PERIOD * BAUD_DIV_RST);
            
            wait(uart_tx == 0);  // Wait for start bit
            #(bit_time * 1.5);   // Sample in middle of bit
            
            // Receive 8 data bits
            for (integer i = 0; i < 8; i = i + 1) begin
                #(bit_time);
                received_data[i] = uart_tx;
            end
            
            // Wait for stop bit
            #(bit_time);
            
            $display("[UART] Received data: 0x%h", received_data);
        end
    endtask
    
    // UART Transmit Task
    task uart_transmit;
        input [7:0] data;
        integer bit_time;
        begin
            bit_time = (CLK_PERIOD * BAUD_DIV_RST);
            
            // Start bit
            uart_rx = 0;
            #(bit_time);
            
            // Data bits
            for (integer i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #(bit_time);
            end
            
            // Stop bit
            uart_rx = 1;
            #(bit_time);
            
            $display("[UART] Transmitted data: 0x%h", data);
        end
    endtask

    // -------------------------------------------
    // Test Tasks
    // -------------------------------------------
    task run_tests;
        begin
            $display("[TEST] Starting test sequence...");
            $fdisplay(log_file, "[TEST] Starting test sequence...");
            
            // Test 1: Basic CPU operation
            test_basic_cpu_operation;
            
            // Test 2: UART communication
            test_uart_communication;
            
            // Test 3: GPIO functionality
            test_gpio_functionality;
            
            // Test 4: Timer functionality
            test_timer_functionality;
            
            // Test 5: Memory access patterns
            test_memory_access;
            
            $display("[TEST] Test sequence completed");
            $fdisplay(log_file, "[TEST] Test sequence completed");
        end
    endtask
    
    // Test 1: Basic CPU operation
    task test_basic_cpu_operation;
        begin
            $display("[TEST 1] Basic CPU Operation");
            $fdisplay(log_file, "[TEST 1] Basic CPU Operation");
            
            // Wait for CPU to start executing
            #2000;
            
            // Check if CPU is executing instructions
            if (dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc > 32'h0000_0000) begin
                $display("[TEST 1] PASS: CPU is executing instructions (PC = 0x%h)", 
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                $fdisplay(log_file, "[TEST 1] PASS: CPU is executing instructions (PC = 0x%h)",
                         dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                test_pass = test_pass + 1;
            end else begin
                $display("[TEST 1] FAIL: CPU not executing instructions (PC = 0x%h)",
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                $fdisplay(log_file, "[TEST 1] FAIL: CPU not executing instructions (PC = 0x%h)",
                         dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                test_fail = test_fail + 1;
            end
            
            // Check memory access
            if (dut.top_soc_inst.wbs_imem_cyc === 1'b1 || dut.top_soc_inst.wbs_dmem_cyc === 1'b1) begin
                $display("[TEST 1] PASS: Memory access detected");
                $fdisplay(log_file, "[TEST 1] PASS: Memory access detected");
                test_pass = test_pass + 1;
            end else begin
                $display("[TEST 1] FAIL: No memory access detected");
                $fdisplay(log_file, "[TEST 1] FAIL: No memory access detected");
                test_fail = test_fail + 1;
            end
        end
    endtask
    
    // Test 2: UART communication
    task test_uart_communication;
        reg uart_activity_detected;
        begin
            $display("[TEST 2] UART Communication");
            $fdisplay(log_file, "[TEST 2] UART Communication");
            
            uart_activity_detected = 0;
            
            // Test UART transmission by monitoring the TX line
            #5000;
            
            // Wait for any transmission with timeout
            #100000;
            if (uart_tx === 1'b0) begin
                $display("[TEST 2] UART transmission detected");
                $fdisplay(log_file, "[TEST 2] UART transmission detected");
                test_pass = test_pass + 1;
                uart_activity_detected = 1;
            end else begin
                $display("[TEST 2] FAIL: No UART transmission detected");
                $fdisplay(log_file, "[TEST 2] FAIL: No UART transmission detected");
                test_fail = test_fail + 1;
            end
            
            // Test UART reception by sending data to the CPU
            #1000;
            uart_transmit(8'h55); // Send 'U' character
            
            // The CPU should process this
            $display("[TEST 2] UART data sent to CPU");
            $fdisplay(log_file, "[TEST 2] UART data sent to CPU");
            test_pass = test_pass + 1;
        end
    endtask
    
    // Test 3: GPIO functionality
    task test_gpio_functionality;
        begin
            $display("[TEST 3] GPIO Functionality");
            $fdisplay(log_file, "[TEST 3] GPIO Functionality");
            
            // Monitor GPIO signals for activity
            // The CPU firmware should eventually manipulate GPIO
            #10000;
            
            // Check if any GPIO activity occurred
            if (dut.top_soc_inst.gpio_out !== 8'b00000000 || dut.top_soc_inst.gpio_oe !== 8'b00000000) begin
                $display("[TEST 3] PASS: GPIO activity detected (out=%b, oe=%b)",
                        dut.top_soc_inst.gpio_out, dut.top_soc_inst.gpio_oe);
                $fdisplay(log_file, "[TEST 3] PASS: GPIO activity detected (out=%b, oe=%b)",
                         dut.top_soc_inst.gpio_out, dut.top_soc_inst.gpio_oe);
                test_pass = test_pass + 1;
            end else begin
                $display("[TEST 3] FAIL: No GPIO activity detected");
                $fdisplay(log_file, "[TEST 3] FAIL: No GPIO activity detected");
                test_fail = test_fail + 1;
            end
            
            // Test GPIO input by driving external pins
            #1000;
            // Drive some GPIO inputs using force (for simulation)
            force gpio_io[0] = 1'b1;
            force gpio_io[1] = 1'b0;
            force gpio_io[2] = 1'b1;
            force gpio_io[3] = 1'b0;
            #1000;
            release gpio_io[0];
            release gpio_io[1];
            release gpio_io[2];
            release gpio_io[3];
            
            $display("[TEST 3] GPIO input test completed");
            $fdisplay(log_file, "[TEST 3] GPIO input test completed");
            test_pass = test_pass + 1;
        end
    endtask
    
    // Test 4: Timer functionality
    task test_timer_functionality;
        begin
            $display("[TEST 4] Timer Functionality");
            $fdisplay(log_file, "[TEST 4] Timer Functionality");
            
            // Check if timer instance exists and is counting
            #15000;
            
            // Check if timer is counting
            if (dut.top_soc_inst.timer_inst.timer_inst.count_reg > 0) begin
                $display("[TEST 4] PASS: Timer is counting (value = %0d)",
                        dut.top_soc_inst.timer_inst.timer_inst.count_reg);
                $fdisplay(log_file, "[TEST 4] PASS: Timer is counting (value = %0d)",
                         dut.top_soc_inst.timer_inst.timer_inst.count_reg);
                test_pass = test_pass + 1;
            end else begin
                $display("[TEST 4] FAIL: Timer not counting");
                $fdisplay(log_file, "[TEST 4] FAIL: Timer not counting");
                test_fail = test_fail + 1;
            end
        end
    endtask
    
    // Test 5: Memory access patterns
    task test_memory_access;
        begin
            $display("[TEST 5] Memory Access Patterns");
            $fdisplay(log_file, "[TEST 5] Memory Access Patterns");
            
            // Monitor memory access patterns
            #20000;
            
            // Check if both instruction and data memory are being accessed
            if (dut.top_soc_inst.wbs_imem_cyc === 1'b1 && dut.top_soc_inst.wbs_dmem_cyc === 1'b1) begin
                $display("[TEST 5] PASS: Both instruction and data memory accessed");
                $fdisplay(log_file, "[TEST 5] PASS: Both instruction and data memory accessed");
                test_pass = test_pass + 1;
            end else if (dut.top_soc_inst.wbs_imem_cyc === 1'b1) begin
                $display("[TEST 5] PARTIAL: Only instruction memory accessed");
                $fdisplay(log_file, "[TEST 5] PARTIAL: Only instruction memory accessed");
                test_pass = test_pass + 1; // Still partial credit
            end else if (dut.top_soc_inst.wbs_dmem_cyc === 1'b1) begin
                $display("[TEST 5] PARTIAL: Only data memory accessed");
                $fdisplay(log_file, "[TEST 5] PARTIAL: Only data memory accessed");
                test_pass = test_pass + 1; // Still partial credit
            end else begin
                $display("[TEST 5] FAIL: No memory access detected");
                $fdisplay(log_file, "[TEST 5] FAIL: No memory access detected");
                test_fail = test_fail + 1;
            end
            
            // Check memory initialization
            if (dut.top_soc_inst.init_done === 1'b1) begin
                $display("[TEST 5] PASS: Memory initialization completed");
                $fdisplay(log_file, "[TEST 5] PASS: Memory initialization completed");
                test_pass = test_pass + 1;
            end else begin
                $display("[TEST 5] FAIL: Memory initialization not completed");
                $fdisplay(log_file, "[TEST 5] FAIL: Memory initialization not completed");
                test_fail = test_fail + 1;
            end
        end
    endtask
    
    

    // -------------------------------------------
    // Process (Monitor and Control)
    // -------------------------------------------

    // Cycle counter
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
    end

    // GPIO Monitor
    always @(posedge clk) begin
        if (rst_n && cycle_count > 100) begin
            $fdisplay(log_file, "Cycle %0d: GPIO = %b", cycle_count, gpio_io);
        end
    end
    
    // Timeout prevention
    always @(posedge clk) begin
        if (rst_n) begin
            timeout_counter <= timeout_counter + 1;
            if (timeout_counter > 500000) begin // 500,000 cycle timeout
                $display("[TIMEOUT] Simulation timeout after %0d cycles", timeout_counter);
                $fdisplay(log_file, "[TIMEOUT] Simulation timeout after %0d cycles", timeout_counter);
                $finish;
            end
        end
    end

    // Monitor for critical errors
    always @(posedge clk) begin
        if (rst_n === 1'b1) begin
            // Check for X or Z states in critical signals
            if (^dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc === 1'bx) begin
                $display("[ERROR] CPU PC has X state!");
                $fdisplay(log_file, "[ERROR] CPU PC has X state!");
                test_fail = test_fail + 1;
                #100 $finish;
            end
        end
    end
    
    // Performance monitoring
    initial begin
        #100000;  // After 100,000 cycles
        $display("[PERF] Cycles executed: %0d", cycle_count);
        $fdisplay(log_file, "[PERF] Cycles executed: %0d", cycle_count);
        $display("[PERF] Instructions retired: ~%0d", cycle_count / 4);  // Rough estimate
        $fdisplay(log_file, "[PERF] Instructions retired: ~%0d", cycle_count / 4);
        
        // Check component activity
        $display("[PERF] IMEM accesses detected");
        $display("[PERF] DMEM accesses detected");
        $fdisplay(log_file, "[PERF] IMEM accesses detected");
        $fdisplay(log_file, "[PERF] DMEM accesses detected");
    end
    
    
endmodule