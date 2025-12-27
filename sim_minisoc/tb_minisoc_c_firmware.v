`timescale 1ns/1ps

// ============================================================================
// MiniSoC Complete System Testbench
// ============================================================================
// This testbench simulates the complete MiniSoC with C-generated firmware
// Firmware is automatically loaded from: ../../build/minisoc/firmware.mem
// ============================================================================

module tb_minisoc_c_firmware;
    // ------------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------------
    parameter CLK_PERIOD    = 10;      // 100 MHz clock
    parameter BAUD_RATE     = 115200;  // UART baud rate
    parameter SIM_TIME_US   = 1000;    // Simulation time in microseconds
    parameter MAX_CYCLES    = 1000000; // Safety timeout
    parameter FIRMWARE_FILE = "firmware.mem";
    

    // ------------------------------------------------------------------------
    // Clock and Reset
    // ------------------------------------------------------------------------
    reg clk;
    reg rst_n;


    // ------------------------------------------------------------------------
    // UART Interface (tie RX high by default)
    // ------------------------------------------------------------------------
    wire uart_tx;
    reg  uart_rx;
    
    // ------------------------------------------------------------------------
    // GPIO Interface (all bidirectional)
    // ------------------------------------------------------------------------
    wire gpio0_io, gpio1_io, gpio2_io, gpio3_io;
    wire gpio4_io, gpio5_io, gpio6_io, gpio7_io;


    // ------------------------------------------------------------------------
    // MiniSoC Instance
    // ------------------------------------------------------------------------
    mini_rv32i_top #(
        .FIRMWARE_FILE  (FIRMWARE_FILE )
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx),
        .gpio0_io   (gpio0_io),
        .gpio1_io   (gpio1_io),
        .gpio2_io   (gpio2_io),
        .gpio3_io   (gpio3_io),
        .gpio4_io   (gpio4_io),
        .gpio5_io   (gpio5_io),
        .gpio6_io   (gpio6_io),
        .gpio7_io   (gpio7_io)
    );
    
    // ------------------------------------------------------------------------
    // Testbench Variables
    // ------------------------------------------------------------------------
    integer     i,j;
    integer     log_file;
    integer     cycle_count;
    integer     timeout_counter;
    reg         simulation_complete;
    
    integer     uart_char_count;
    reg [7:0]   uart_output [0:1023];


    // ------------------------------------------------------------------------
    // Waveform Dump
    // ------------------------------------------------------------------------
    initial begin
        $dumpfile("minisoc_c_firmware.vcd");
        $dumpvars(0, tb_minisoc_c_firmware);
        // Dump all hierarchy levels
        $dumpvars(1, dut);
        $dumpvars(2, dut.top_soc_inst);
        $dumpvars(3, dut.top_soc_inst.rv32i_core);
        $dumpvars(3, dut.top_soc_inst.imem_inst);
        $dumpvars(3, dut.top_soc_inst.dmem_inst);
        $dumpvars(3, dut.top_soc_inst.uart_inst);
        $dumpvars(3, dut.top_soc_inst.gpio_inst);
        $dumpvars(3, dut.top_soc_inst.timer_inst);
        $display("[TB] Waveform dumping enabled: minisoc_c_firmware.vcd");
    end

    
    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end


    // ------------------------------------------------------------------------
    // Reset and Initialization
    // ------------------------------------------------------------------------
    initial begin
        rst_n                   = 0;
        cycle_count             = 0;
        timeout_counter         = 0;
        simulation_complete     = 0;
        uart_char_count         = 0;

        for (i = 0; i < 1024; i = i + 1) begin
            uart_output[i]      = 8'h0;
        end

        #(CLK_PERIOD*10) rst_n  = 1;
    end
    
    // ------------------------------------------------------------------------
    // Initialization and Firmware Loading
    // ------------------------------------------------------------------------
    initial begin
        // Open Log file
        log_file = $fopen("minisoc_firmware.log", "w");


        $display("==================================================");
        $display("MINISOC COMPLETE SYSTEM SIMULATION");
        $display("==================================================");
        $display("Date: %t", $time);
        $display("Firmware Type: C-Generated from sw/ folder");
        $display("Firmware File: ../../build/minisoc/firmware.mem");
        $display("==================================================");

        $fdisplay(log_file, "==================================================");
        $fdisplay(log_file, "MINISOC COMPLETE SYSTEM SIMULATION");
        $fdisplay(log_file, "==================================================");
        $fdisplay(log_file, "Date: %t", $time);
        $fdisplay(log_file, "Firmware Type: C-Generated from sw/ folder");
        $fdisplay(log_file, "Firmware File: ../../build/minisoc/firmware.mem");
        $fdisplay(log_file, "==================================================");

        
        // Start monitoring
        
        $display("\n[TB] Starting C firmware execution...");
        $display("==================================================\n");

        // TEST INIT : Check Memory Initialization and CPU Reset
        $display("==================================================");
        $fdisplay(log_file, "==================================================");
        $display("[TB][TEST_INIT] Check Memory Initialization and CPU Reset: Starting\n");
        $fdisplay(log_file, "[TB][TEST_INIT] Check Memory Initialization and CPU Reset: Starting\n");
        test_init();
        $display("\n[TB][TEST_INIT] Check Memory Initialization and CPU Reset: ✅ Completed");
        $fdisplay(log_file, "\n[TB][TEST_INIT] Check Memory Initialization and CPU Reset: ✅ Completed");
        $display("==================================================\n");
        $fdisplay(log_file, "==================================================\n");

    end

    // ------------------------------------------------------------------------
    // Cycle counter Process
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
    end


    // ------------------------------------------------------------------------
    // Timeout Check
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (cycle_count > MAX_CYCLES) begin
            $display("\n==================================================");
            $display("ERROR: Simulation timeout!");
            $display("Reached %d cycles without completion", MAX_CYCLES);
            $display("\n==================================================");

            $fdisplay(log_file, "\n==================================================");
            $fdisplay(log_file, "ERROR: Simulation timeout!");
            $fdisplay(log_file, "Reached %d cycles without completion", MAX_CYCLES);
            $fdisplay(log_file, "\n==================================================");
            $finish;
        end
    end


    // ------------------------------------------------------------------------
    // CPU State Monitor
    // ------------------------------------------------------------------------
    reg [31:0] fetch_pc,        fetch_instr;
    reg [31:0] decode_pc,       decode_instr;
    reg [31:0] execute_pc,      execute_instr;
    reg [31:0] mem_pc,          mem_instr;
    reg [31:0] writeback_pc,    writeback_instr;

    always @(*) begin
        fetch_pc            = dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc;
        decode_pc           = dut.top_soc_inst.rv32i_core.decode_stage_inst.pc_in;
        execute_pc          = dut.top_soc_inst.rv32i_core.execute_stage_inst.pc_in;
        mem_pc              = dut.top_soc_inst.rv32i_core.mem_stage_inst.pc_in;
        writeback_pc        = dut.top_soc_inst.rv32i_core.writeback_stage_inst.pc_in;

        fetch_instr         = dut.top_soc_inst.rv32i_core.fetch_stage_inst.wbm_imem_data_read;
        decode_instr        = dut.top_soc_inst.rv32i_core.decode_stage_inst.instr_in;
        execute_instr       = dut.top_soc_inst.rv32i_core.execute_stage_inst.instr_in;
        mem_instr           = dut.top_soc_inst.rv32i_core.mem_stage_inst.instr_in;
        writeback_instr     = dut.top_soc_inst.rv32i_core.writeback_stage_inst.instr_in;
    end


    // ------------------------------------------------------------------------
    // TEST INIT
    // ------------------------------------------------------------------------
    task test_init;
        begin
            $display("[TB][TEST_INIT] -- Waiting for memory reset...");
            $fdisplay(log_file, "[TB][TEST_INIT] -- Waiting for memory reset...");

            // Wait for memory reset to complete
            wait(dut.top_soc_inst.memory_rst_n);
            $display("[TB][TEST_INIT] -- Memory reset released at %t", $time);
            $fdisplay(log_file, "[TB][TEST_INIT] -- Memory reset released at %t", $time);

            // Wait for initialization to complete
            wait(dut.top_soc_inst.init_done == 1);
            $display("[TB][TEST_INIT] -- Memory initialization complete at %t", $time);
            $fdisplay(log_file, "[TB][TEST_INIT] -- Memory initialization complete at %t", $time);

            // Verify firmware loaded correctly
            $display("[TB][TEST_INIT] -- Verifying firmware loaded correctly...");
            $fdisplay(log_file, "[TB][TEST_INIT] -- Verifying firmware loaded correctly...");
            verify_firmware_loaded();

            // Wait for CPU reset to be released
            wait(dut.top_soc_inst.cpu_rst_n);
            $display("[TB][TEST_INIT] -- CPU reset released at %t", $time);
            $fdisplay(log_file, "[TB][TEST_INIT] -- CPU reset released at %t", $time);

            // Verify CPU starts at reset PC
            if (dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc === 32'h00000000) begin
                $display("[TB][TEST_INIT] -- CPU PC at reset vector: ✅ 0x00000000");
                $fdisplay(log_file, "[TB][TEST_INIT] -- CPU PC at reset vector: ✅ 0x00000000");
            end else begin
                $display("[TB][TEST_INIT] -- CPU PC incorrect: ❌ Expected 0x00000000, Got %h", 
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                $fdisplay(log_file, "[TB][TEST_INIT] -- CPU PC incorrect: ❌ Expected 0x00000000, Got %h", 
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
            end
        end
    endtask

    task verify_firmware_loaded;
        begin
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
            end else begin
                $display("[FIRMWARE_VERIFY] ✅ IMEM appears to be initialized");
                $fdisplay(log_file, "[FIRMWARE_VERIFY] ✅ IMEM appears to be initialized");
            end
        end
    endtask
    
endmodule