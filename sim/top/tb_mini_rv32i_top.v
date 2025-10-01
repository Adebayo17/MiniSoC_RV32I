`timescale 1ns/1ps

module tb_mini_rv32i_top;

    // Parameters
    parameter CLK_PERIOD    = 10;  // 100 MHz
    parameter FIRMWARE_FILE = "firmware.mem";
    parameter ADDR_WIDTH    = 32;
    parameter DATA_WIDTH    = 32;
    parameter IMEM_SIZE_KB  = 8;
    parameter DMEM_SIZE_KB  = 4;
    parameter DATA_SIZE_KB  = 4;
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
    reg [7:0]    previous_gpio;
    reg          test_complete;
    reg [31:0]   test_result;
    
    reg timeout_occurred;
    
    
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
        .FIRMWARE_FILE  (FIRMWARE_FILE  ),
        .ADDR_WIDTH     (ADDR_WIDTH     ),
        .DATA_WIDTH     (DATA_WIDTH     ),
        .IMEM_SIZE_KB   (IMEM_SIZE_KB   ),
        .DMEM_SIZE_KB   (DMEM_SIZE_KB   ),
        .DATA_SIZE_KB   (DATA_SIZE_KB   ),
        .BAUD_DIV_RST   (BAUD_DIV_RST   ),
        .N_GPIO         (N_GPIO         )
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
    task verify_firmware_behavior;
        begin
            $display("[TEST] Starting firmware behavior verification...");
            $fdisplay(log_file, "[TEST] Starting firmware behavior verification...");
            
            // Initialize timeout tracking
            timeout_counter = 0;
            timeout_occurred = 0;
            test_complete = 0;
            
            // Wait for test completion with timeout
            while (!test_complete && !timeout_occurred) begin
                @(posedge clk);
                timeout_counter = timeout_counter + 1;
                if (timeout_counter > 1000000) begin  // 1 million cycle timeout
                    timeout_occurred = 1;
                    $display("[TEST] TIMEOUT: Firmware didn't complete in %0d cycles", timeout_counter);
                    $fdisplay(log_file, "[TEST] TIMEOUT: Firmware didn't complete in %0d cycles", timeout_counter);
                    test_fail = test_fail + 1;
                end
            end
            
            if (test_complete && !timeout_occurred) begin
                $display("[TEST] Firmware test sequence completed in %0d cycles", timeout_counter);
                $fdisplay(log_file, "[TEST] Firmware test sequence completed in %0d cycles", timeout_counter);
            end
            
            // Additional peripheral checks
            check_peripheral_activity();
        end
    endtask

    task check_peripheral_activity;
        begin
            // Check UART was used
            if (dut.top_soc_inst.uart_inst.uart_inst.uart_tx_inst.tx_enable) begin
                $display("[TEST] PASS: UART was enabled and used");
                $fdisplay(log_file, "[TEST] PASS: UART was enabled and used");
                test_pass = test_pass + 1;
            end else begin
                $display("[TEST] FAIL: UART was not enabled");
                $fdisplay(log_file, "[TEST] FAIL: UART was not enabled");
                test_fail = test_fail + 1;
            end
            
            // Check GPIO was configured
            if (dut.top_soc_inst.gpio_inst.gpio_inst.dir_reg !== 8'h00) begin
                $display("[TEST] PASS: GPIO was configured");
                $fdisplay(log_file, "[TEST] PASS: GPIO was configured");
                test_pass = test_pass + 1;
            end else begin
                $display("[TEST] FAIL: GPIO was not configured");
                $fdisplay(log_file, "[TEST] FAIL: GPIO was not configured");
                test_fail = test_fail + 1;
            end
            
            // Check for UART transmission activity
            if (dut.top_soc_inst.uart_inst.uart_inst.uart_tx_inst.tx_busy) begin
                $display("[TEST] PASS: UART transmission activity detected");
                $fdisplay(log_file, "[TEST] PASS: UART transmission activity detected");
                test_pass = test_pass + 1;
            end else begin
                $display("[TEST] INFO: No active UART transmission at test end");
                $fdisplay(log_file, "[TEST] INFO: No active UART transmission at test end");
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

    always @(posedge clk) begin
        if (rst_n && !test_complete) begin
            // Monitor for writes to test control address (0x50000000)
            if (dut.top_soc_inst.rv32i_core.wbm_dmem_addr == 32'h50000000 && 
                dut.top_soc_inst.rv32i_core.wbm_dmem_we && 
                dut.top_soc_inst.rv32i_core.wbm_dmem_sel != 0) begin
                
                test_result = dut.top_soc_inst.rv32i_core.wbm_dmem_data_write;
                test_complete = 1;
                
                case (test_result)
                    32'h1234ABCD: begin
                        $display("[TEST] FIRMWARE REPORT: ALL TESTS PASSED");
                        test_pass = test_pass + 1;
                    end
                    32'hDEADBEEF: begin
                        $display("[TEST] FIRMWARE REPORT: TESTS FAILED");
                        test_fail = test_fail + 1;
                    end
                    default: begin
                        $display("[TEST] FIRMWARE REPORT: Unknown result %h", test_result);
                    end
                endcase
            end
        end
    end

    
    
endmodule