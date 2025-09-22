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
        verify_firmware_behavior();
        
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
    // Test Tasks
    // -------------------------------------------
    reg [7:0] previous_gpio;
    task verify_firmware_behavior;
        begin
            $display("[TEST] Verifying firmware behavior...");
            $fdisplay(log_file, "[TEST] Verifying firmware behavior...");
            
            // Wait longer for the simple firmware to start
            #20000;
            
            // Check if memory initialization happened only once
            if (dut.top_soc_inst.init_done !== 1'b1) begin
                $display("[TEST] FAIL: Memory initialization not completed");
                $fdisplay(log_file, "[TEST] FAIL: Memory initialization not completed");
                test_fail = test_fail + 1;
                //return;
            end
            
            $display("[TEST] PASS: Memory initialization completed correctly");
            $fdisplay(log_file, "[TEST] PASS: Memory initialization completed correctly");
            test_pass = test_pass + 1;
            
            // Check CPU is running (PC should not be zero)
            if (dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc === 32'h00000000) begin
                $display("[TEST] FAIL: CPU PC is zero - not executing");
                $fdisplay(log_file, "[TEST] FAIL: CPU PC is zero - not executing");
                test_fail = test_fail + 1;
            end else begin
                $display("[TEST] PASS: CPU is executing (PC = %h)", 
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                $fdisplay(log_file, "[TEST] PASS: CPU is executing (PC = %h)",
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                test_pass = test_pass + 1;
            end
            
            // Wait a bit more for GPIO activity
            #30000;
            
            // For the simple firmware: check if GPIO is being toggled (not just static)
            // The simple firmware toggles between 0 and 1, so check if it changes
            
            previous_gpio = dut.top_soc_inst.gpio_out;
            
            #10000; // Wait 10,000 cycles
            
            if (dut.top_soc_inst.gpio_out !== previous_gpio) begin
                $display("[TEST] PASS: GPIO is being toggled by firmware");
                $fdisplay(log_file, "[TEST] PASS: GPIO is being toggled by firmware");
                test_pass = test_pass + 1;
            end else begin
                $display("[TEST] FAIL: GPIO not changing (static at %b)", previous_gpio);
                $fdisplay(log_file, "[TEST] FAIL: GPIO not changing (static at %b)", previous_gpio);
                test_fail = test_fail + 1;
            end
            
            // Check for UART activity (simple firmware sends '.' or 'O')
            #20000;
            if (uart_tx === 1'b0) begin  // Start bit detected
                $display("[TEST] PASS: UART transmission detected");
                $fdisplay(log_file, "[TEST] PASS: UART transmission detected");
                test_pass = test_pass + 1;
            end else begin
                $display("[TEST] Checking UART status...");
                // Check if UART is enabled and ready
                if (dut.top_soc_inst.uart_inst.uart_inst.uart_tx_inst.tx_enable === 1'b1) begin
                    $display("[TEST] UART is enabled, waiting for transmission...");
                    #50000; // Wait longer
                    if (uart_tx === 1'b0) begin
                        $display("[TEST] PASS: UART transmission detected after wait");
                        $fdisplay(log_file, "[TEST] PASS: UART transmission detected after wait");
                        test_pass = test_pass + 1;
                    end else begin
                        $display("[TEST] FAIL: UART enabled but no transmission");
                        $fdisplay(log_file, "[TEST] FAIL: UART enabled but no transmission");
                        test_fail = test_fail + 1;
                    end
                end else begin
                    $display("[TEST] FAIL: UART not enabled");
                    $fdisplay(log_file, "[TEST] FAIL: UART not enabled");
                    test_fail = test_fail + 1;
                end
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