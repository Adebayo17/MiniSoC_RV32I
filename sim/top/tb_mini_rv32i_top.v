`timescale 1ns/1ps

// ============================================================================
// MiniSoC Testbench with Simple Firmware
// ============================================================================
// This testbench simulates the complete MiniSoC with a simple firmware
// Firmware is automatically loaded from: sim/top/firmware_program/firmware.mem
// ============================================================================


module tb_mini_rv32i_top;

    // =======================================================================
    // PARAMETERS
    // =======================================================================
    // DUT parameters
    parameter CLK_PERIOD            = 10;                           // 100 MHz
    parameter FIRMWARE_FILE         = "firmware.mem";
    parameter ADDR_WIDTH            = 32;
    parameter DATA_WIDTH            = 32;
    parameter IMEM_SIZE_KB          = 8;
    parameter DMEM_SIZE_KB          = 4;
    parameter DATA_SIZE_KB          = 4;
    parameter BAUD_DIV_RST          = 16'd104;                      // 115200 baud @ 12MHz
    parameter N_GPIO                = 8;

    // Simulation Control
    localparam RESET_TIME           = 200;
    localparam SIM_CTRL_BASE        = 32'h50000000;
    localparam TEST_PASS_CODE       = 32'h1234ABCD;
    localparam MAX_SIM_CYCLES       = 2000000; // 2M cycles (was 1M)

    // Log 
    parameter  MAX_MSG_LEN          = 128;


    // Memory map addresses
    localparam IMEM_BASE            = 32'h0000_0000;
    localparam DMEM_BASE            = 32'h1000_0000;
    localparam UART_BASE            = 32'h2000_0000;
    localparam GPIO_BASE            = 32'h4000_0000;
    localparam TIMER_BASE           = 32'h3000_0000;
    
    // UART register offsets
    localparam UART_TX_DATA         = 0;
    localparam UART_RX_DATA         = 4;
    localparam UART_BAUD_DIV        = 8;
    localparam UART_CTRL            = 12;
    localparam UART_STATUS          = 16;
    
    // GPIO register offsets
    localparam GPIO_DATA            = 0;
    localparam GPIO_DIR             = 4;
    localparam GPIO_SET             = 8;
    localparam GPIO_CLEAR           = 12;
    localparam GPIO_TOGGLE          = 16;
    
    // Timer register offsets
    localparam TIMER_COUNT          = 0;
    localparam TIMER_CMP            = 4;
    localparam TIMER_CTRL           = 8;
    localparam TIMER_STAT           = 12;

    // Testbench states
    parameter TB_RESET              = 0;
    parameter TB_MEM_INIT           = 1;
    parameter TB_CPU_RESET          = 2;
    parameter TB_FETCH              = 3;
    parameter TB_PIPELINE           = 4;
    parameter TB_PERIPH             = 5;
    parameter TB_FIRMWARE           = 6;
    parameter TB_PASS               = 7;
    parameter TB_FAIL               = 8;
    parameter TB_DONE               = 9;


    // =======================================================================
    // SIGNALS
    // =======================================================================
    
    // Clock and reset
    reg                     clk;
    reg                     rst_n;
    
    // Top-Level Check
    wire                    mem_init_done   = dut.top_soc_inst.init_done;
    wire                    soc_cpu_ready   = dut.top_soc_inst.cpu_rst_n;
    wire [ADDR_WIDTH-1:0]   fetch_pc        = dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc;
    wire [ADDR_WIDTH-1:0]   decode_pc       = dut.top_soc_inst.rv32i_core.decode_stage_inst.pc_in;
    wire [ADDR_WIDTH-1:0]   execute_pc      = dut.top_soc_inst.rv32i_core.execute_stage_inst.pc_in;
    wire [ADDR_WIDTH-1:0]   mem_pc          = dut.top_soc_inst.rv32i_core.mem_stage_inst.pc_in;
    wire [ADDR_WIDTH-1:0]   writeback_pc    = dut.top_soc_inst.rv32i_core.writeback_stage_inst.pc_in;
    wire [DATA_WIDTH-1:0]   fetch_instr     = dut.top_soc_inst.rv32i_core.fetch_stage_inst.wbm_imem_data_read;
    wire [DATA_WIDTH-1:0]   decode_instr    = dut.top_soc_inst.rv32i_core.decode_stage_inst.instr_in;
    wire [DATA_WIDTH-1:0]   execute_instr   = dut.top_soc_inst.rv32i_core.execute_stage_inst.instr_in;
    wire [DATA_WIDTH-1:0]   mem_instr       = dut.top_soc_inst.rv32i_core.mem_stage_inst.instr_in;
    wire [DATA_WIDTH-1:0]   writeback_instr = dut.top_soc_inst.rv32i_core.writeback_stage_inst.instr_in;
    
    // UART signals
    reg                     uart_rx;
    wire                    uart_tx;
    
    // GPIO signals
    wire [7:0]              gpio_io;

    // FSM registers
    integer                 tb_state;       
    integer                 state_timer;
    integer                 global_cycle;

    // Test stats
    integer                 test_pass_count;
    integer                 test_fail_count;
    integer                 tests_total;

    // Trace & Logs
    integer                 log_file;
    integer                 cpu_trace_log;
    reg [8*MAX_MSG_LEN:1]   log_buf;      // 128-char buffer for formatted strings

    // Flags (Detected events)
    reg                     flag_firmware_pass;
    integer                 flag_gpio_access;
    integer                 flag_uart_access;
    integer                 flag_timer_access;
    reg [ADDR_WIDTH-1:0]    pc_snapshot;

    // CPI Calculation
    integer                 instr_retired_count;
    integer                 cpu_start_cycle;
    real                    cpi_measure;
    
    // Testbench variables
    reg [31:0]   test_num;
    integer      test_pass;
    integer      test_fail;
    integer      cycle_count;
    integer      timeout_counter;
    reg [7:0]    previous_gpio;
    reg          test_complete;
    reg [31:0]   test_result;

    reg firmware_finished_pass; // Becomes 1 when pass code is seen
    reg test_timeout;           // Becomes 1 if the test takes too long
    
    reg timeout_occurred;
    
    
    // =======================================================================
    // DUT INSTANTIATION (Top-Level SoC)
    // =======================================================================
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
    
    // =======================================================================
    // CLOCK GENERATION
    // =======================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;


    // =======================================================================
    // RESET AND INITIALIZATION
    // =======================================================================
    initial begin
        // Log files
        log_file            = $fopen("mini_rv32i_top.log", "w");
        cpu_trace_log       = $fopen("mini_rv32i_top_cpu_trace.log", "w");
        print_log(log_file, "INFO", "=== MINI RISC-V SOC TESTBENCH STARTED ===");

        $fdisplay(cpu_trace_log, "Mini RV32I Top CPU instruction trace Log - %t", $time);
        $fdisplay(cpu_trace_log,
            "===============================================================================================================================================");
        $fdisplay(cpu_trace_log,
            "  CYCLE        |   IF_PC    IF_INSTR   |   ID_PC    ID_INSTR   |   EX_PC    EX_INSTR   |   MEM_PC   MEM_INSTR      |   WB_PC    WB_INSTR");
        $fdisplay(cpu_trace_log,
            "===============================================================================================================================================");

        // Init signals
        rst_n               = 0;
        uart_rx             = 1;  // UART idle state
        tb_state            = TB_RESET;
        state_timer         = 0;
        global_cycle        = 0;
        test_pass_count     = 0;
        test_fail_count     = 0;
        tests_total         = 0;
        
        // Init flags
        flag_firmware_pass  = 0;
        flag_gpio_access    = 0;
        flag_uart_access    = 0;
        flag_timer_access   = 0;

        // CPI 
        instr_retired_count = 0;

        // Release Reset
        #(RESET_TIME);
        rst_n               = 1;
        print_log(log_file, "INFO", "Reset Released");
    end


    // =======================================================================
    // Event Monitoring (Paralled Logic)
    // =======================================================================
    
    // 1. Pass Code Detection
    always @(posedge clk) begin
        if (rst_n && dut.top_soc_inst.wbs_cpu_cyc && 
            dut.top_soc_inst.wbs_cpu_stb &&
            dut.top_soc_inst.wbs_cpu_we  &&
            dut.top_soc_inst.wbs_cpu_addr == SIM_CTRL_BASE &&
            dut.top_soc_inst.wbs_cpu_data_write == TEST_PASS_CODE) begin
            flag_firmware_pass <= 1;
        end
    end 

    // 2. Peripheral Access Detection
    always @(posedge clk) begin
        if (rst_n) begin
            if (dut.top_soc_inst.gpio_inst.gpio_select)     flag_gpio_access  <= flag_gpio_access  + 1;
            if (dut.top_soc_inst.uart_inst.uart_select)     flag_uart_access  <= flag_uart_access  + 1;
            if (dut.top_soc_inst.timer_inst.timer_select)   flag_timer_access <= flag_timer_access + 1;
        end
    end

    // 3. Instruction Retired Count (for CPI)
    always @(posedge clk) begin
        if (rst_n) begin
            // An instruction is considered "Retired" if it reaches the Writeback stage 
            // with the VALID signal asserted, and the writeback stage is NOT stalled.
            if (dut.top_soc_inst.rv32i_core.MEM_to_WB_valid) begin
                instr_retired_count <= instr_retired_count + 1;
            end
        end
    end

    
    // =======================================================================
    // Cycle Counter
    // =======================================================================
    always @(posedge clk) begin
        global_cycle <= global_cycle + 1;
    end


    // =======================================================================
    // Main FSM
    // =======================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tb_state     <= TB_RESET;
            state_timer  <= 0;
        end else begin
            state_timer  <= state_timer + 1;
            
            // Global Timeout Check
            if (global_cycle > MAX_SIM_CYCLES) begin
                $sformat(log_buf, "Simulation Global Timeout (%0d cycles)", MAX_SIM_CYCLES);
                print_log(log_file, "FATAL", log_buf);
                tb_state <= TB_FAIL;
            end 
            // MAIN STATE MACHINE
            else begin
                case (tb_state)
                    TB_RESET: begin
                        if (rst_n) begin
                            tb_state    <= TB_MEM_INIT;
                            state_timer <= 0;
                            print_log(log_file, "INFO", "External Reset Released. Waiting for SoC Init...");
                        end
                    end

                    // ----------------------------------------------------
                    TB_MEM_INIT: begin
                        if (state_timer == 0) begin
                            print_log(log_file, "INFO", "[TEST 1] Waiting for Memory Initialization");
                        end

                        if (mem_init_done) begin
                            print_log(log_file, "PASS", "Memory Initialized.");
                            verify_firmware_loaded();
                            test_pass_count = test_pass_count + 1;
                            tb_state        <= TB_CPU_RESET;
                            state_timer     <= 0;
                        end
                        else if ((global_cycle - state_timer) > 100_000) begin
                            print_log(log_file, "FAIL", "TIMEOUT: Memory Init failed.");
                            test_fail_count = test_fail_count + 1;
                            tb_state        <= TB_FAIL;
                        end
                    end

                    // ----------------------------------------------------
                    TB_CPU_RESET: begin
                        if (state_timer == 0) begin
                            print_log(log_file, "INFO", "[TEST 2] Checking CPU Reset Vector...");
                        end

                        if (soc_cpu_ready) begin
                            if (fetch_pc === 32'h00000000) begin
                                print_log(log_file, "PASS", "CPU Reset Vector correct (0x00000000).");
                                test_pass_count = test_pass_count + 1;
                                tb_state    <= TB_FETCH;
                                state_timer <= 0;
                            end else begin
                                $sformat(log_buf, "CPU Reset Vector incorrect: %h", fetch_pc);
                                print_log(log_file, "FAIL", log_buf);
                                test_fail_count = test_fail_count + 1;
                                tb_state        <= TB_FAIL;
                            end
                        end
                    end

                    // ----------------------------------------------------
                    TB_FETCH: begin
                        if (state_timer == 0) begin
                            print_log(log_file, "INFO", "[TEST 3] Checking Instruction Fetch...");
                        end

                        if (fetch_pc > 32'h00000000) begin
                            print_log(log_file, "PASS", "CPU is fetching instructions.");
                            test_pass_count = test_pass_count + 1;
                            tb_state        <= TB_PIPELINE;
                            state_timer     <= 0;
                        end
                        else if (state_timer > 100) begin
                            print_log(log_file, "FAIL", "TIMEOUT: CPU stuck at 0x00000000.");
                            test_fail_count = test_fail_count + 1;
                            tb_state        <= TB_FAIL;
                        end
                    end

                    // ----------------------------------------------------
                    TB_PIPELINE: begin
                        if (state_timer == 0) begin 
                            print_log(log_file, "INFO", "[TEST 4] Checking Pipeline Progression...");
                            pc_snapshot <= fetch_pc;
                        end

                        if (state_timer == 50) begin
                            if (fetch_pc !== pc_snapshot) begin
                                print_log(log_file, "PASS", "PC is advancing (Pipeline OK).");
                                test_pass_count = test_pass_count + 1;
                                tb_state        <= TB_PERIPH;
                                state_timer     <= 0;
                            end else begin
                                $sformat(log_buf, "PC is stuck at %h (Pipeline Stall).", pc_snapshot);
                                print_log(log_file, "FAIL", log_buf);
                                test_fail_count = test_fail_count + 1;
                                tb_state        <= TB_FAIL;
                            end
                        end
                    end

                    // ----------------------------------------------------
                    TB_PERIPH: begin
                        if (state_timer == 0) begin 
                            print_log(log_file, "INFO", "[TEST 5] Checking Peripheral Access");
                        end

                        if (state_timer == 10_000) begin
                            if (flag_uart_access > 0)  print_log(log_file, "PASS", "UART Access detected.");
                            if (flag_gpio_access > 0)  print_log(log_file, "PASS", "GPIO Access detected.");
                            if (flag_timer_access > 0) print_log(log_file, "PASS", "Timer Access detected.");
                            tb_state <= TB_FIRMWARE;
                            state_timer <= 0;
                        end
                    end

                    // ----------------------------------------------------
                    TB_FIRMWARE: begin
                        if (state_timer == 0) begin 
                            print_log(log_file, "INFO", "[TEST 6] Running Firmware (Waiting for PASS Code)...");
                        end

                        // Success Condition
                        if (flag_firmware_pass) begin
                            print_log(log_file, "PASS", "[TESTBENCH] FIRMWARE PASS CODE RECEIVED!");
                            test_pass_count = test_pass_count + 1;
                            tb_state <= TB_PASS;
                        end
                    end

                    // ----------------------------------------------------
                    TB_PASS: begin
                        print_log(log_file, "PASS", "============================================");
                        print_log(log_file, "PASS", "           SIMULATION SUCCESSFUL            ");
                        print_log(log_file, "PASS", "============================================");
                        tb_state <= TB_DONE;
                    end

                    // ----------------------------------------------------
                    TB_FAIL: begin
                        print_log(log_file, "FAIL", "============================================");
                        print_log(log_file, "FAIL", "             SIMULATION FAILED              ");
                        print_log(log_file, "FAIL", "============================================");
                        tb_state <= TB_DONE;
                    end

                    // ----------------------------------------------------
                    TB_DONE: begin
                        // Calculate CPI
                        if (instr_retired_count > 0) begin
                            cpi_measure  = $itor(global_cycle) / $itor(instr_retired_count);
                        end else begin
                            cpi_measure = 0.0;
                        end

                        $sformat(log_buf, "Tests Passed: %0d", test_pass_count);
                        print_log(log_file, "INFO", log_buf);

                        $sformat(log_buf, "Tests Failed: %0d", test_fail_count);
                        print_log(log_file, "INFO", log_buf);

                        $sformat(log_buf, "Total Cycles: %0d", global_cycle);
                        print_log(log_file, "INFO", log_buf);

                        $sformat(log_buf, "Instr Retired: %0d", instr_retired_count);
                        print_log(log_file, "INFO", log_buf);

                        $sformat(log_buf, "CPI Average: %0.4f", cpi_measure);
                        print_log(log_file, "INFO", log_buf);
                        
                        $fclose(log_file);
                        $fclose(cpu_trace_log);
                        $finish;
                    end
                endcase
            end
        end
    end
    

    // =======================================================================
    // Test and Utility Tasks
    // =======================================================================
    // Check if firmware is loaded after MEM_INIT
    task verify_firmware_loaded;
        begin
            print_log(log_file, "INFO", "[FW] Verifying firmware loaded correctly...");
            
            // Check first few instructions in IMEM
            $sformat(log_buf, "[FW] IMEM[0] = %h (should be first instruction)", dut.top_soc_inst.imem_inst.imem_inst.mem[0]);
            print_log(log_file, "INFO", log_buf);
            
            $sformat(log_buf, "[FW] IMEM[1] = %h", dut.top_soc_inst.imem_inst.imem_inst.mem[1]);
            print_log(log_file, "INFO", log_buf);

            $sformat(log_buf, "[FW] IMEM[2] = %h", dut.top_soc_inst.imem_inst.imem_inst.mem[2]);
            print_log(log_file, "INFO", log_buf);
            

            // Check if instructions look valid
            if (dut.top_soc_inst.imem_inst.imem_inst.mem[0] === 32'hxxxxxxxx) begin
                print_log(log_file, "ERROR", "[FW] IMEM[0] is uninitialized!");
                test_fail_count = test_fail_count + 1;
            end else begin
                print_log(log_file, "PASS", "[FW] IMEM appears to be initialized");
                test_pass_count = test_pass_count + 1;
            end
        end
    endtask


    // Print lop 
    task print_log;
        input [31:0]            f_handle;           // File descriptor (log_file)
        input [8*5:1]           tag;                // Type: "INFO", "PASS", "FAIL", "WARN" (5 chars max)
        input [8*MAX_MSG_LEN:1] msg;                // Text message
        begin
            // Console display
            $display("[TB_TOP_LEVEL][%s] @%0t ns: %0s", tag, $time, msg);

            // File Writting
            if (f_handle != 0) begin
                $fdisplay(f_handle, "[TB_TOP_LEVEL][%s] @%0t ns: %s0", tag, $time, msg);
            end
        end
    endtask


    // =======================================================================
    // UART Monitor
    // =======================================================================
    localparam BAUD_PERIOD_NS = CLK_PERIOD * BAUD_DIV_RST;
    reg [7:0] rx_byte;
    integer bit_idx;

    initial begin
        // Wait for reset release
        wait(rst_n == 1);
        print_log(log_file, "INFO", "\n[UART TERMINAL] Listening...");
        
        forever begin
            // Detect Start Bit (Falling Edge)
            @(negedge uart_tx);
            
            // Wait 1.5 bit periods to sample middle of bit 0
            #(BAUD_PERIOD_NS * 1.5);
            
            rx_byte = 0;
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                rx_byte[bit_idx] = uart_tx;
                #(BAUD_PERIOD_NS);
            end
            
            // Stop bit check (optional, skipping for simulation speed)
            
            // Print char to console
            $write("\n[UART TERMINAL] %c", rx_byte);
            if (log_file) $fwrite(log_file, "\n[UART TERMINAL] %c", rx_byte);
        end
    end


    // =======================================================================
    // CPU Trace Logger
    // =======================================================================
    always @(posedge clk) begin
        if (cpu_trace_log && dut.top_soc_inst.cpu_rst_n) begin
            $fdisplay(cpu_trace_log,
                "%8d        | %08h  %08h | %08h  %08h | %08h  %08h | %08h  %08h | %08h  %08h",
                global_cycle,
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

endmodule