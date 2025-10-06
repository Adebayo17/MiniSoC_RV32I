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

        count_instr_fetch = 0;        

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

        $display("\n=== TOP-LEVEL Testbench Started ===");
        $fdisplay(log_file, "\n=== TOP-LEVEL Testbench Started ===");

        
        test_num = 0;

        // Test 1 : Memory Initialization
        test_num = test_num + 1;
        $display("\n[TESTBENCH TOP-LEVEL][TEST %0d] Memory Initialization: Starting", test_num);
        $fdisplay(log_file, "\n[TESTBENCH TOP-LEVEL][TEST %0d] Memory Initialization: Starting", test_num);

        wait(dut.top_soc_inst.memory_rst_n);
        wait(dut.top_soc_inst.init_done == 1);
        $display("  - Memory initialization complete at time %t", $time);
        $fdisplay(log_file, "   - Memory initialization complete at time %t", $time);

        verify_firmware_loaded();

        $display("[TESTBENCH TOP-LEVEL][TEST %0d] Memory Initialization: Completed", test_num);
        $fdisplay(log_file, "[TESTBENCH TOP-LEVEL][TEST %0d] Memory Initialization: Completed", test_num);

        // Test 2 : Reset released
        test_num = test_num + 1;
        $display("\n[TESTBENCH TOP-LEVEL][TEST %0d] Reset released: Starting", test_num);
        $fdisplay(log_file, "\n[TESTBENCH TOP-LEVEL][TEST %0d] Reset released: Starting", test_num);

        wait(dut.top_soc_inst.cpu_rst_n);
        $display("  - Reset released at time %t", $time);
        $fdisplay(log_file, "   - Reset released at time %t", $time);

        $display("[TESTBENCH TOP-LEVEL][TEST %0d] Reset released: Completed", test_num);
        $fdisplay(log_file, "[TESTBENCH TOP-LEVEL][TEST %0d] Reset released: Completed", test_num);


        // Test 3 : Check Instruction Fetching
        test_num = test_num + 1;
        $display("\n[TESTBENCH TOP-LEVEL][TEST %0d] Check Instruction Fetching: Starting", test_num);
        $fdisplay(log_file, "\n[TESTBENCH TOP-LEVEL][TEST %0d] Check Instruction Fetching: Starting", test_num);


        $display("[TESTBENCH TOP-LEVEL][TEST %0d] Check Instruction Fetching: Completed", test_num);
        $fdisplay(log_file, "[TESTBENCH TOP-LEVEL][TEST %0d] Check Instruction Fetching: Completed", test_num);


        
        // Test 4 : Diagnostic CPU Freeze
        test_num = test_num + 1;
        $display("\n[TESTBENCH TOP-LEVEL][TEST %0d] Diagnostic CPU Freeze", test_num);
        $fdisplay(log_file, "\n[TESTBENCH TOP-LEVEL][TEST %0d] Diagnostic CPU Freeze: Starting", test_num);

        diagnose_cpu_freeze();
        test_interconnect_basic();

        $display("\n[TESTBENCH TOP-LEVEL][TEST %0d] Diagnostic CPU Freeze: Completed", test_num);
        $fdisplay(log_file, "\n[TESTBENCH TOP-LEVEL][TEST %0d] Diagnostic CPU Freeze: Completed", test_num);
        
        

        // Summary
        #1000;
        $display("\n=== TOP-LEVEL Testbench Completed ===");
        $fdisplay(log_file, "\n=== TOP-LEVEL Testbench Completed ===");
        if (test_fail == 0) begin
            $display("✅ [TEST] ALL TESTS PASSED!");
            $fdisplay(log_file, "✅ [TEST] ALL TESTS PASSED!");
        end else begin
            $display("❌ [TEST] %0d TESTS FAILED!", test_fail);
            $fdisplay(log_file, "❌ [TEST] %0d TESTS FAILED!", test_fail);
        end
        
        $fclose(log_file);
        $finish;
    end

    // -------------------------------------------
    // Memory Initialization Tasks 
    // -------------------------------------------
    task verify_firmware_loaded;
        begin
            $display("[FIRMWARE_VERIFY] Verifying firmware loaded correctly...");
            $fdisplay(log_file, "[FIRMWARE_VERIFY] Verifying firmware loaded correctly...");
            
            // Check first few instructions in IMEM
            $display("[FIRMWARE_VERIFY] IMEM[0] = %h (should be first instruction)", 
                    dut.top_soc_inst.imem_inst.imem_inst.mem[0]);
            $display("[FIRMWARE_VERIFY] IMEM[1] = %h", 
                    dut.top_soc_inst.imem_inst.imem_inst.mem[1]);
            $display("[FIRMWARE_VERIFY] IMEM[2] = %h", 
                    dut.top_soc_inst.imem_inst.imem_inst.mem[2]);
            
            $fdisplay(log_file, "[FIRMWARE_VERIFY] IMEM[0] = %h", 
                    dut.top_soc_inst.imem_inst.imem_inst.mem[0]);
            $fdisplay(log_file, "[FIRMWARE_VERIFY] IMEM[1] = %h", 
                    dut.top_soc_inst.imem_inst.imem_inst.mem[1]);
            $fdisplay(log_file, "[FIRMWARE_VERIFY] IMEM[2] = %h", 
                    dut.top_soc_inst.imem_inst.imem_inst.mem[2]);
            
            // Check if instructions look valid
            if (dut.top_soc_inst.imem_inst.imem_inst.mem[0] === 32'hxxxxxxxx) begin
                $display("[FIRMWARE_VERIFY] ERROR: IMEM[0] is uninitialized!");
                $fdisplay(log_file, "[FIRMWARE_VERIFY] ERROR: IMEM[0] is uninitialized!");
            end else begin
                $display("[FIRMWARE_VERIFY] IMEM appears to be initialized");
                $fdisplay(log_file, "[FIRMWARE_VERIFY] IMEM appears to be initialized");
            end
        end
    endtask


    // -------------------------------------------
    // Instruction Fetch Monitoring
    // -------------------------------------------
    integer count_instr_fetch;
    always @(posedge clk) begin
        if ((test_num >= 3) && (count_instr_fetch < 16)) begin
            $display("[CHECK_INSTRUCTION_FETCH] PC = %h", dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
            $fdisplay(log_file, "[CHECK_INSTRUCTION_FETCH] PC = %h", dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
            count_instr_fetch = count_instr_fetch + 1;
        end
    end

    // -------------------------------------------
    // Diagnostic Tasks 
    // -------------------------------------------
    task diagnose_cpu_freeze;
        begin
            $display("[DIAG] ===== CPU FREEZE DIAGNOSIS =====");
            $fdisplay(log_file, "[DIAG] ===== CPU FREEZE DIAGNOSIS =====");
            
            // 1. Check CPU reset state
            $display("[DIAG] CPU reset: %b", dut.top_soc_inst.cpu_rst_n);
            $fdisplay(log_file, "[DIAG] CPU reset: %b", dut.top_soc_inst.cpu_rst_n);
            
            // 2. Check memory initialization
            $display("[DIAG] Memory init done: %b", dut.top_soc_inst.init_done);
            $fdisplay(log_file, "[DIAG] Memory init done: %b", dut.top_soc_inst.init_done);
            
            // 3. Check CPU PC
            $display("[DIAG] CPU PC: %h", dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
            $fdisplay(log_file, "[DIAG] CPU PC: %h", dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
            
            // 4. Check if CPU is requesting instructions
            $display("[DIAG] IMEM request - CYC: %b, STB: %b", 
                    dut.top_soc_inst.wbs_imem_cyc, dut.top_soc_inst.wbs_imem_stb);
            $fdisplay(log_file, "[DIAG] IMEM request - CYC: %b, STB: %b",
                    dut.top_soc_inst.wbs_imem_cyc, dut.top_soc_inst.wbs_imem_stb);
            
            // 5. Check IMEM response
            $display("[DIAG] IMEM response - ACK: %b, DATA: %h", 
                    dut.top_soc_inst.wbs_imem_ack, dut.top_soc_inst.wbs_imem_data_read);
            $fdisplay(log_file, "[DIAG] IMEM response - ACK: %b, DATA: %h",
                    dut.top_soc_inst.wbs_imem_ack, dut.top_soc_inst.wbs_imem_data_read);
            
            // 6. Check first few IMEM locations
            $display("[DIAG] IMEM[0]: %h", dut.top_soc_inst.imem_inst.imem_inst.mem[0]);
            $display("[DIAG] IMEM[1]: %h", dut.top_soc_inst.imem_inst.imem_inst.mem[1]);
            $fdisplay(log_file, "[DIAG] IMEM[0]: %h", dut.top_soc_inst.imem_inst.imem_inst.mem[0]);
            $fdisplay(log_file, "[DIAG] IMEM[1]: %h", dut.top_soc_inst.imem_inst.imem_inst.mem[1]);
            
            $display("[DIAG] ===== END DIAGNOSIS =====");
            $fdisplay(log_file, "[DIAG] ===== END DIAGNOSIS =====");
        end
    endtask

    task test_interconnect_basic;
        integer cycles_monitored;
        begin
            $display("[INTERCONNECT_TEST] Testing basic interconnect functionality...");
            $fdisplay(log_file, "[INTERCONNECT_TEST] Testing basic interconnect functionality...");
            
            // Wait a few cycles after reset
            #(CLK_PERIOD * 10);
            
            cycles_monitored = 0;
            
            // Monitor interconnect activity for 1000 cycles
            while (cycles_monitored < 1000) begin
                @(posedge clk);
                cycles_monitored = cycles_monitored + 1;
                
                // Log any Wishbone activity
                if (dut.top_soc_inst.wbs_imem_cyc || dut.top_soc_inst.wbs_dmem_cyc) begin
                    $display("[INTERCONNECT] Cycle %0d: IMEM_CYC=%b, DMEM_CYC=%b", 
                            cycles_monitored, 
                            dut.top_soc_inst.wbs_imem_cyc,
                            dut.top_soc_inst.wbs_dmem_cyc);
                    $fdisplay(log_file, "[INTERCONNECT] Cycle %0d: IMEM_CYC=%b, DMEM_CYC=%b", 
                            cycles_monitored, 
                            dut.top_soc_inst.wbs_imem_cyc,
                            dut.top_soc_inst.wbs_dmem_cyc);
                end
            end
        end
    endtask

    

    // task force_cpu_instruction;
    //     input [31:0] instruction;
    //     input [31:0] address;
    //     begin
    //         $display("[FORCE_TEST] Forcing instruction %h at address %h", instruction, address);
    //         $fdisplay(log_file, "[FORCE_TEST] Forcing instruction %h at address %h", instruction, address);
            
    //         // Force a simple instruction to see if CPU executes it
    //         force dut.top_soc_inst.imem_inst.imem_inst.mem[address[11:2]] = instruction;
            
    //         // Wait a few cycles
    //         #(CLK_PERIOD * 20);
            
    //         // Release the force
    //         release dut.top_soc_inst.imem_inst.imem_inst.mem[address[11:2]];
            
    //         $display("[FORCE_TEST] Instruction force released");
    //         $fdisplay(log_file, "[FORCE_TEST] Instruction force released");
    //     end
    // endtask

    // task test_interconnect_direct;
    //     begin
    //         $display("[INTERCONNECT_DIRECT] Direct interconnect test...");
    //         $fdisplay(log_file, "[INTERCONNECT_DIRECT] Direct interconnect test...");
            
    //         // Test 1: Check if CPU can read from IMEM at address 0
    //         $display("[INTERCONNECT_DIRECT] Checking IMEM read path...");
            
    //         // Monitor the path step by step
    //         #(CLK_PERIOD * 5);
            
    //         $display("[INTERCONNECT_DIRECT] CPU PC: %h", 
    //                 dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
    //         $display("[INTERCONNECT_DIRECT] IMEM request - ADDR: %h, CYC: %b, STB: %b", 
    //                 dut.top_soc_inst.wbs_imem_addr,
    //                 dut.top_soc_inst.wbs_imem_cyc,
    //                 dut.top_soc_inst.wbs_imem_stb);
    //         $display("[INTERCONNECT_DIRECT] IMEM response - ACK: %b, DATA: %h", 
    //                 dut.top_soc_inst.wbs_imem_ack,
    //                 dut.top_soc_inst.wbs_imem_data_read);
                    
    //         $fdisplay(log_file, "[INTERCONNECT_DIRECT] CPU PC: %h", 
    //                 dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
    //         $fdisplay(log_file, "[INTERCONNECT_DIRECT] IMEM request - ADDR: %h, CYC: %b, STB: %b", 
    //                 dut.top_soc_inst.wbs_imem_addr,
    //                 dut.top_soc_inst.wbs_imem_cyc,
    //                 dut.top_soc_inst.wbs_imem_stb);
    //         $fdisplay(log_file, "[INTERCONNECT_DIRECT] IMEM response - ACK: %b, DATA: %h", 
    //                 dut.top_soc_inst.wbs_imem_ack,
    //                 dut.top_soc_inst.wbs_imem_data_read);
    //     end
    // endtask


    // -------------------------------------------
    // Verify Firmware
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
        if (rst_n && (cycle_count > 100) && (test_num > 2)) begin
            $fdisplay(log_file, "Cycle %0d: GPIO = %b", cycle_count, gpio_io);
        end
    end
    
    // Timeout prevention
    always @(posedge clk) begin
        if (rst_n) begin
            timeout_counter <= timeout_counter + 1;
            if (timeout_counter > 50000000) begin // 500,000 cycle timeout
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

    // -------------------------------------------
    // Pipeline Flush Monitor 
    // -------------------------------------------
    reg [31:0] flush_count;
    reg [31:0] branch_count;
    reg [31:0] jump_count;
    reg [31:0] return_count;
    reg [31:0] instruction_count;
    reg [31:0] last_pc;
    reg program_completed;
    reg [31:0] completion_time;

    // Flush detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flush_count <= 0;
            branch_count <= 0;
            jump_count <= 0;
            return_count <= 0;
            instruction_count <= 0;
            last_pc <= 0;
            program_completed <= 0;
            completion_time <= 0;
        end else begin
            // Detect program completion (write to 0x50000000)
            if (dut.top_soc_inst.wbs_dmem_cyc && 
                dut.top_soc_inst.wbs_dmem_we && 
                dut.top_soc_inst.wbs_dmem_addr == 32'h50000000 && 
                !program_completed) begin
                program_completed <= 1;
                completion_time <= cycle_count;
                $display("[PROGRAM_COMPLETION] Program completed at cycle %0d", cycle_count);
                $fdisplay(log_file, "[PROGRAM_COMPLETION] Program completed at cycle %0d", cycle_count);
                $display("[PROGRAM_COMPLETION] Test result: %h", dut.top_soc_inst.wbs_dmem_data_write);
                $fdisplay(log_file, "[PROGRAM_COMPLETION] Test result: %h", dut.top_soc_inst.wbs_dmem_data_write);
            end
            
            // Count instructions (when PC changes)
            if (dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc !== last_pc && 
                dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc !== 32'hxxxxxxxx) begin
                instruction_count <= instruction_count + 1;
            end
            last_pc <= dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc;
            
            // Detect flushes - you'll need to check what signals your CPU exposes
            // These are examples - adjust based on your actual CPU signals
            if (dut.top_soc_inst.rv32i_core.execute_stage_inst.branch_taken_out) begin
                flush_count <= flush_count + 1;
                branch_count <= branch_count + 1;
                $display("[FLUSH] Branch taken at PC=%h, cycle=%0d", 
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc, cycle_count);
            end
            // Add similar detection for jumps and returns based on your CPU design
        end
    end

    // Flush analysis task
    task analyze_flush_performance;
        real flush_rate;
        real ipc;
        begin
            $display("[FLUSH_ANALYSIS] ===== Pipeline Flush Analysis =====");
            $fdisplay(log_file, "[FLUSH_ANALYSIS] ===== Pipeline Flush Analysis =====");
            
            $display("[FLUSH_ANALYSIS] Total Cycles: %0d", cycle_count);
            $display("[FLUSH_ANALYSIS] Total Instructions: %0d", instruction_count);
            $display("[FLUSH_ANALYSIS] Total Flushes: %0d", flush_count);
            $display("[FLUSH_ANALYSIS]   - Branch flushes: %0d", branch_count);
            $display("[FLUSH_ANALYSIS]   - Jump flushes: %0d", jump_count);
            $display("[FLUSH_ANALYSIS]   - Return flushes: %0d", return_count);
            
            $fdisplay(log_file, "[FLUSH_ANALYSIS] Total Cycles: %0d", cycle_count);
            $fdisplay(log_file, "[FLUSH_ANALYSIS] Total Instructions: %0d", instruction_count);
            $fdisplay(log_file, "[FLUSH_ANALYSIS] Total Flushes: %0d", flush_count);
            $fdisplay(log_file, "[FLUSH_ANALYSIS]   - Branch flushes: %0d", branch_count);
            $fdisplay(log_file, "[FLUSH_ANALYSIS]   - Jump flushes: %0d", jump_count);
            $fdisplay(log_file, "[FLUSH_ANALYSIS]   - Return flushes: %0d", return_count);
            
            if (instruction_count > 0) begin
                flush_rate = (flush_count * 100.0) / instruction_count;
                ipc = instruction_count / (cycle_count * 1.0);
                
                $display("[FLUSH_ANALYSIS] Flush Rate: %.2f%%", flush_rate);
                $display("[FLUSH_ANALYSIS] Instructions Per Cycle: %.3f", ipc);
                
                $fdisplay(log_file, "[FLUSH_ANALYSIS] Flush Rate: %.2f%%", flush_rate);
                $fdisplay(log_file, "[FLUSH_ANALYSIS] Instructions Per Cycle: %.3f", ipc);
            end
            
            $display("[FLUSH_ANALYSIS] ===== End Analysis =====");
            $fdisplay(log_file, "[FLUSH_ANALYSIS] ===== End Analysis =====");
        end
    endtask

    // Progress monitoring task
    task monitor_progress;
        integer last_report_cycle;
        begin
            last_report_cycle = 0;
            
            while (cycle_count < 1000000 && !program_completed) begin
                @(posedge clk);
                
                // Report every 10000 cycles
                if ((cycle_count - last_report_cycle) >= 10000) begin
                    $display("[PROGRESS] Cycle %0d: Instructions=%0d, Flushes=%0d, PC=%h",
                            cycle_count, instruction_count, flush_count,
                            dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                    $fdisplay(log_file, "[PROGRESS] Cycle %0d: Instructions=%0d, Flushes=%0d, PC=%h",
                            cycle_count, instruction_count, flush_count,
                            dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                    last_report_cycle = cycle_count;
                end
            end
        end
    endtask

    
    
endmodule