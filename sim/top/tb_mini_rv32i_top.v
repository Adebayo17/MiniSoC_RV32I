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
    integer cpu_trace_log;
    
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

        gpio_selected   = 0;
        uart_selected   = 0;
        dmem_selected   = 0;
        timer_selected  = 0; 

        is_gpio_selected = 0;
        is_uart_selected = 0;

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

        cpu_trace_log = $fopen("mini_rv32i_top_cpu_trace.log", "w");
        $fdisplay(cpu_trace_log, "Mini RV32I Top CPU instruction trace Log - %t", $time);
        $fdisplay(cpu_trace_log,
            "===============================================================================================================================================");
        $fdisplay(cpu_trace_log,
            "  CYCLE        |   IF_PC    IF_INSTR   |   ID_PC    ID_INSTR   |   EX_PC    EX_INSTR   |   MEM_PC   MEM_INSTR      |   WB_PC    WB_INSTR");
        $fdisplay(cpu_trace_log,
            "===============================================================================================================================================");
        
        // Create VCD dump
        $dumpfile("mini_rv32i_top_tb.vcd");
        $dumpvars(0, tb_mini_rv32i_top);

        $display("\n=== TOP-LEVEL Testbench Started ===");
        $fdisplay(log_file, "\n=== TOP-LEVEL Testbench Started ===");

        
        test_num = 0;

        // ===== TEST 1: Memory Initialization =====
        test_num = test_num + 1;
        $display("\n[TESTBENCH TOP-LEVEL][TEST %0d] Memory Initialization: Starting", test_num);
        $fdisplay(log_file, "\n[TESTBENCH TOP-LEVEL][TEST %0d] Memory Initialization: Starting", test_num);

        test_memory_initialization();

        $display("[TESTBENCH TOP-LEVEL][TEST %0d] Memory Initialization: ✅ PASS", test_num);
        $fdisplay(log_file, "[TESTBENCH TOP-LEVEL][TEST %0d] Memory Initialization: ✅ PASS", test_num);

        // ===== TEST 2: CPU Reset =====
        test_num = test_num + 1;
        $display("\n[TESTBENCH TOP-LEVEL][TEST %0d] CPU Reset: Starting", test_num);
        $fdisplay(log_file, "\n[TESTBENCH TOP-LEVEL][TEST %0d] CPU Reset: Starting", test_num);

        test_cpu_reset();

        $display("[TESTBENCH TOP-LEVEL][TEST %0d] CPU Reset: ✅ PASS", test_num);
        $fdisplay(log_file, "[TESTBENCH TOP-LEVEL][TEST %0d] CPU Reset: ✅ PASS", test_num);


        // ===== TEST 3: Instruction Fetching =====
        test_num = test_num + 1;
        $display("\n[TESTBENCH TOP-LEVEL][TEST %0d] Instruction Fetching: Starting", test_num);
        $fdisplay(log_file, "\n[TESTBENCH TOP-LEVEL][TEST %0d] Instruction Fetching: Starting", test_num);

        // Wait for CPU to start fetching
        #(CLK_PERIOD * 20);
        
        // Monitor instruction fetch progression
        monitor_instruction_fetch();

        $display("[TESTBENCH TOP-LEVEL][TEST %0d] Instruction Fetching: ✅ PASS", test_num);
        $fdisplay(log_file, "[TESTBENCH TOP-LEVEL][TEST %0d] Instruction Fetching: ✅ PASS", test_num);


        // ===== TEST 4: Peripheral Access =====
        test_num = test_num + 1;
        $display("\n[TESTBENCH TOP-LEVEL][TEST %0d] Peripheral Access: Starting", test_num);
        $fdisplay(log_file, "\n[TESTBENCH TOP-LEVEL][TEST %0d] Peripheral Access: Starting", test_num);

        // Wait for firmware to initialize peripherals
        #(CLK_PERIOD * 100);
        
        // Check that peripherals are being accessed
        verify_peripheral_access();

        $display("[TESTBENCH TOP-LEVEL][TEST %0d] Peripheral Access: ✅ PASS", test_num);
        $fdisplay(log_file, "[TESTBENCH TOP-LEVEL][TEST %0d] Peripheral Access: ✅ PASS", test_num);


        // ===== TEST 5: Pipeline Progression =====
        test_num = test_num + 1;
        $display("\n[TESTBENCH TOP-LEVEL][TEST %0d] Pipeline Progression: Starting", test_num);
        $fdisplay(log_file, "\n[TESTBENCH TOP-LEVEL][TEST %0d] Pipeline Progression: Starting", test_num);

        // Monitor PC progression through pipeline stages
        monitor_pipeline_progression();

        $display("[TESTBENCH TOP-LEVEL][TEST %0d] Pipeline Progression: ✅ PASS", test_num);
        $fdisplay(log_file, "[TESTBENCH TOP-LEVEL][TEST %0d] Pipeline Progression: ✅ PASS", test_num);
        

        // ===== FINAL SUMMARY =====
        #1000000;
        $display("\n=== TOP-LEVEL Testbench Completed ===");
        $fdisplay(log_file, "\n=== TOP-LEVEL Testbench Completed ===");
        
        $display("Tests Passed: %0d, Tests Failed: %0d", test_pass, test_fail);
        $fdisplay(log_file, "Tests Passed: %0d, Tests Failed: %0d", test_pass, test_fail);
        
        if (test_fail == 0) begin
            $display("✅ ALL TESTS PASSED!");
            $fdisplay(log_file, "✅ ALL TESTS PASSED!");
        end else begin
            $display("❌ %0d TESTS FAILED!", test_fail);
            $fdisplay(log_file, "❌ %0d TESTS FAILED!", test_fail);
        end
        
        $fclose(log_file);
        $finish;
    end


    // -------------------------------------------
    // Tests Tasks
    // -------------------------------------------
    task test_memory_initialization;
        begin
            $display("  - Waiting for memory reset...");
            $fdisplay(log_file, "  - Waiting for memory reset...");
            
            // Wait for memory reset to complete
            wait(dut.top_soc_inst.memory_rst_n);
            $display("  - Memory reset released at %t", $time);
            $fdisplay(log_file, "  - Memory reset released at %t", $time);
            test_pass = test_pass + 1;
            
            // Wait for initialization to complete
            wait(dut.top_soc_inst.init_done == 1);
            $display("  - Memory initialization complete at %t", $time);
            $fdisplay(log_file, "  - Memory initialization complete at %t", $time);
            test_pass = test_pass + 1;
            
            // Verify firmware loaded correctly
            verify_firmware_loaded();
            
            $display("  ✅ Memory initialization test passed");
            $fdisplay(log_file, "  ✅ Memory initialization test passed");
        end
    endtask

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
                $display("[FIRMWARE_VERIFY] ERROR: ❌ IMEM[0] is uninitialized!");
                $fdisplay(log_file, "[FIRMWARE_VERIFY] ERROR: ❌ IMEM[0] is uninitialized!");
                test_fail = test_fail + 1;
            end else begin
                $display("[FIRMWARE_VERIFY] ✅ IMEM appears to be initialized");
                $fdisplay(log_file, "[FIRMWARE_VERIFY] ✅ IMEM appears to be initialized");
                test_pass = test_pass + 1;
            end
        end
    endtask
    
    task test_cpu_reset;
        begin
            $display("  - Waiting for CPU reset release...");
            $fdisplay(log_file, "  - Waiting for CPU reset release...");
            
            // Wait for CPU reset to be released
            wait(dut.top_soc_inst.cpu_rst_n);
            $display("  - CPU reset released at %t", $time);
            $fdisplay(log_file, "  - CPU reset released at %t", $time);
            test_pass = test_pass + 1;

            // Verify CPU starts at reset PC
            if (dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc === 32'h00000000) begin
                $display("  - CPU PC at reset vector: ✅ 0x00000000");
                $fdisplay(log_file, "  - CPU PC at reset vector: ✅ 0x00000000");
                test_pass = test_pass + 1;
            end else begin
                $display("  - CPU PC incorrect: ❌ Expected 0x00000000, Got %h", 
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                $fdisplay(log_file, "  - CPU PC incorrect: ❌ Expected 0x00000000, Got %h", 
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                test_fail = test_fail + 1;
            end
            
            
            $display("  ✅ CPU reset test passed");
            $fdisplay(log_file, "  ✅ CPU reset test passed");
        end
    endtask

    task monitor_instruction_fetch;
        integer fetch_cycles;
        begin
            $display("  [FETCH] Monitoring instruction fetch...");
            $fdisplay(log_file, "  [FETCH] Monitoring instruction fetch...");
            
            fetch_cycles = 0;
            while (fetch_cycles < 50 && dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc < 32'h00000010) begin
                @(posedge clk);
                fetch_cycles = fetch_cycles + 1;
                
                if (dut.top_soc_inst.wbs_imem_if_cyc && dut.top_soc_inst.wbs_imem_if_stb) begin
                    $display("  [FETCH] Cycle %0d: Fetching PC=%h", cycle_count,
                            dut.top_soc_inst.wbs_imem_if_addr);
                    $fdisplay(log_file, "  [FETCH] Cycle %0d: Fetching PC=%h", cycle_count,
                            dut.top_soc_inst.wbs_imem_if_addr);
                end
            end
            
            if (dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc > 32'h00000000) begin
                $display("  [FETCH] ✅ CPU is fetching instructions");
                $fdisplay(log_file, "  [FETCH] ✅ CPU is fetching instructions");
                test_pass = test_pass + 1;
            end else begin
                $display("  [FETCH] ❌ CPU not fetching instructions");
                $fdisplay(log_file, "  [FETCH] ❌ CPU not fetching instructions");
                test_fail = test_fail + 1;
            end
        end
    endtask


    task verify_peripheral_access;
        begin
            $display("  [PERIPHERAL] Checking peripheral access...");
            $fdisplay(log_file, "  [PERIPHERAL] Checking peripheral access...");
            
            // Monitor for peripheral select signals
            #(CLK_PERIOD * 50);

            if (is_gpio_selected) begin
                $display("  [PERIPHERAL] ✅ GPIO select activity detected");
                $fdisplay(log_file, "  [PERIPHERAL] ✅ GPIO select activity detected");
                test_pass = test_pass + 1;
            end else begin
                $display("  [PERIPHERAL] ❌ GPIO not accessed");
                $fdisplay(log_file, "  [PERIPHERAL] ❌ GPIO not accessed");
                test_fail = test_fail + 1;
            end

            if (is_uart_selected) begin
                $display("  [PERIPHERAL] ✅ UART select activity detected"); 
                $fdisplay(log_file, "  [PERIPHERAL] ✅ UART select activity detected");
                test_pass = test_pass + 1;
            end else begin
                $display("  [PERIPHERAL] ❌ UART not accessed");
                $fdisplay(log_file, "  [PERIPHERAL] ❌ UART not accessed");
                test_fail = test_fail + 1;
            end
        end
    endtask


    task monitor_pipeline_progression;
        integer monitor_cycles;
        reg [31:0] last_pc;
        begin
            $display("  [PIPELINE] Monitoring PC progression...");
            $fdisplay(log_file, "  [PIPELINE] Monitoring PC progression...");
            
            monitor_cycles = 0;
            last_pc = dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc;
            
            while (monitor_cycles < 20) begin
                @(posedge clk);
                monitor_cycles = monitor_cycles + 1;
                
                // Check if PC is advancing
                if (dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc !== last_pc) begin
                    $display("  [PIPELINE] Cycle %0d: PC advanced %h -> %h", cycle_count,
                            last_pc, dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                    $fdisplay(log_file, "  [PIPELINE] Cycle %0d: PC advanced %h -> %h", cycle_count,
                            last_pc, dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                    last_pc = dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc;
                end
            end
            
            if (last_pc > 32'h00000008) begin
                $display("  [PIPELINE] ✅ PC is progressing through pipeline");
                $fdisplay(log_file, "  [PIPELINE] ✅ PC is progressing through pipeline");
            end else begin
                $display("  [PIPELINE] ❌ PC stalled at %h", last_pc);
                $fdisplay(log_file, "  [PIPELINE] ❌ PC stalled at %h", last_pc);
                test_fail = test_fail + 1;
            end
        end
    endtask


    // -------------------------------------------
    // Monitoring Process
    // -------------------------------------------

    // Cycle counter
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
    end
    
    // ===== TEST 4: Monitor Peripheral Access =====
    reg dmem_selected;
    reg gpio_selected;
    reg uart_selected;
    reg timer_selected;

    reg is_gpio_selected;
    reg is_uart_selected;
    always @(*) begin
        dmem_selected   = 0;
        gpio_selected   = 0;
        uart_selected   = 0;
        timer_selected  = 0;

        if (dut.top_soc_inst.dmem_inst.mem_select) begin
            dmem_selected = 1'b1;
            // $display("[MONITOR][PIPELINE] ✅ DMEM select activity detected at Cycle %0d", cycle_count);
            // $fdisplay(log_file, "[MONITOR][PIPELINE] ✅ DMEM select activity detected at Cycle %0d", cycle_count);
        end

        if (dut.top_soc_inst.uart_inst.uart_select) begin
            uart_selected = 1'b1;
            is_uart_selected = 1'b1;
            // $display("[MONITOR][PIPELINE] ✅ UART select activity detected at Cycle %0d", cycle_count);
            // $fdisplay(log_file, "[MONITOR][PIPELINE] ✅ UART select activity detected at Cycle %0d", cycle_count);
        end

        if (dut.top_soc_inst.timer_inst.timer_select) begin
            timer_selected = 1'b1;
            // $display("[MONITOR][PIPELINE] ✅ TIMER select activity detected at Cycle %0d", cycle_count);
            // $fdisplay(log_file, "[MONITOR][PIPELINE] ✅ TIMER select activity detected at Cycle %0d", cycle_count);
        end

        if (dut.top_soc_inst.gpio_inst.gpio_select) begin
            gpio_selected = 1'b1;
            is_gpio_selected = 1'b1;
            // $display("[MONITOR][PIPELINE] ✅ GPIO select activity detected at Cycle %0d", cycle_count);
            // $fdisplay(log_file, "[MONITOR][PIPELINE] ✅ GPIO select activity detected at Cycle %0d", cycle_count);
        end
    end


    // ===== TEST 5: Monitor Pipeline Progression =====
    reg [31:0] fetch_pc;
    reg [31:0] decode_pc;
    reg [31:0] execute_pc;
    reg [31:0] mem_pc;
    reg [31:0] writeback_pc;

    reg [31:0] fetch_instr;
    reg [31:0] decode_instr;
    reg [31:0] execute_instr;
    reg [31:0] mem_instr;
    reg [31:0] writeback_instr;
    always @(*) begin
        fetch_pc        = dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc;
        decode_pc       = dut.top_soc_inst.rv32i_core.decode_stage_inst.pc_in;
        execute_pc      = dut.top_soc_inst.rv32i_core.execute_stage_inst.pc_in;
        mem_pc          = dut.top_soc_inst.rv32i_core.mem_stage_inst.pc_in;
        writeback_pc    = dut.top_soc_inst.rv32i_core.writeback_stage_inst.pc_in;

        fetch_instr        = dut.top_soc_inst.rv32i_core.fetch_stage_inst.wbm_imem_data_read;
        decode_instr       = dut.top_soc_inst.rv32i_core.decode_stage_inst.instr_in;
        execute_instr      = dut.top_soc_inst.rv32i_core.execute_stage_inst.instr_in;
        mem_instr          = dut.top_soc_inst.rv32i_core.mem_stage_inst.instr_in;
        writeback_instr    = dut.top_soc_inst.rv32i_core.writeback_stage_inst.instr_in;
    end

    always @(posedge clk) begin
        if (cpu_trace_log && dut.top_soc_inst.cpu_rst_n) begin
            $fdisplay(cpu_trace_log,
                "%8d        | %08h  %08h | %08h  %08h | %08h  %08h | %08h  %08h | %08h  %08h",
                cycle_count,
                fetch_pc    , fetch_instr     ,
                decode_pc   , decode_instr    ,
                execute_pc  , execute_instr   ,
                mem_pc      , mem_instr       ,
                writeback_pc, writeback_instr ,
            );
            $fdisplay(cpu_trace_log,
                "-------------------------------------------------------------------------------------------------------------------------------------");
        end
    end


    // Check Firmware stage reached
    // always @(*) begin
    //     if (fetch_pc == 32'h00000000) begin
    //         $display("[FIRMWARE] Reached : <_start>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <_start>");
    //     end

    //     if (fetch_pc == 32'h00000030) begin
    //         $display("[FIRMWARE] Reached : <main_loop>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <main_loop>");
    //     end

    //     if (fetch_pc == 32'h00000044) begin
    //         $display("[FIRMWARE] Reached : <skip_uart>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <skip_uart>");
    //     end

    //     if (fetch_pc == 32'h0000004C) begin
    //         $display("[FIRMWARE] Reached : <delay_loop>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <delay_loop>");
    //     end

    //     if (fetch_pc == 32'h00000070) begin
    //         $display("[FIRMWARE] Reached : <uart_send_boot_msg>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <uart_send_boot_msg>");
    //     end

    //     if (fetch_pc == 32'h00000090) begin
    //         $display("[FIRMWARE] Reached : <uart_send_string>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <uart_send_string>");
    //     end

    //     if (fetch_pc == 32'h000000A8) begin
    //         $display("[FIRMWARE] Reached : <uart_string_loop>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <uart_string_loop>");
    //     end

    //     if (fetch_pc == 32'h000000BC) begin
    //         $display("[FIRMWARE] Reached : <uart_string_done>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <uart_string_done>");
    //     end

    //     if (fetch_pc == 32'h000000D0) begin
    //         $display("[FIRMWARE] Reached : <uart_send_char>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <uart_send_char>");
    //     end

    //     if (fetch_pc == 32'h000000E0) begin
    //         $display("[FIRMWARE] Reached : <uart_wait_tx>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <uart_wait_tx>");
    //     end

    //     if (fetch_pc == 32'h00000100) begin
    //         $display("[FIRMWARE] Reached : <uart_send_hex>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <uart_send_hex>");
    //     end

    //     if (decode_pc == 32'h00000128) begin
    //         $display("[FIRMWARE] Reached : <hex_loop>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <hex_loop>");
    //     end

    //     if (decode_pc == 32'h00000140) begin
    //         $display("[FIRMWARE] Reached : <hex_digit>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <hex_digit>");
    //     end

    //     if (decode_pc == 32'h00000144) begin
    //         $display("[FIRMWARE] Reached : <hex_send>");
    //         $fdisplay(log_file, "[FIRMWARE] Reached : <hex_send>");
    //     end
    // end

    // Add to testbench
    // always @(posedge clk) begin
    //     if (cycle_count >= 3250 && cycle_count <= 3300) begin
    //         $display("[VALID_TRACE] Cycle %0d: IF_valid=%b, ID_valid=%b, EX_valid=%b, MEM_valid=%b, WB_valid=%b",
    //                 cycle_count,
    //                 dut.top_soc_inst.rv32i_core.fetch_stage_inst.valid_out,
    //                 dut.top_soc_inst.rv32i_core.decode_stage_inst.valid_out,
    //                 dut.top_soc_inst.rv32i_core.execute_stage_inst.valid_out,
    //                 dut.top_soc_inst.rv32i_core.mem_stage_inst.valid_out,
    //                 dut.top_soc_inst.rv32i_core.writeback_stage_inst.valid_out);
    //     end
    // end

    // Add to testbench
    // always @(posedge clk) begin
    //     if (dut.top_soc_inst.rv32i_core.mem_stage_inst.mem_read_in && 
    //         dut.top_soc_inst.rv32i_core.mem_stage_inst.valid_in) begin
    //         $display("[MEM_READ] Cycle %0d: addr=%h, data=%h, valid_out=%b",
    //                 cycle_count,
    //                 dut.top_soc_inst.rv32i_core.mem_stage_inst.wbm_dmem_addr,
    //                 dut.top_soc_inst.rv32i_core.mem_stage_inst.wbm_dmem_data_read,
    //                 dut.top_soc_inst.rv32i_core.mem_stage_inst.valid_out);
    //     end
    // end


endmodule