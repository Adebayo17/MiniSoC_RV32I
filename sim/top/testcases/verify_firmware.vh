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