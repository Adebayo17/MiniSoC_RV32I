`timescale 1ns/1ps

module tb_mem_init;
    // Parameters
    parameter CLK_PERIOD = 10;  // 100 MHz
    parameter IMEM_BASE = 32'h0000_0000;
    parameter DMEM_BASE = 32'h1000_0000;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter INIT_FILE = "firmware.hex";

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Test Control
    reg [31:0] test_num;
    reg [8*40:1] test_name;
    reg [31:0] task_error_count;
    reg [31:0] total_errors;

    // DUT Interface
    reg init_start;
    wire init_done;

    // Memory Interfaces
    wire imem_init_en;
    wire [ADDR_WIDTH-1:0] imem_init_addr;
    wire [DATA_WIDTH-1:0] imem_init_data;

    wire dmem_init_en;
    wire [ADDR_WIDTH-1:0] dmem_init_addr;
    wire [DATA_WIDTH-1:0] dmem_init_data;

    // Instantiate DUT
    mem_init #(
        .IMEM_BASE(IMEM_BASE),
        .DMEM_BASE(DMEM_BASE),
        .INIT_FILE(INIT_FILE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .init_start(init_start),
        .init_done(init_done),
        .imem_init_en(imem_init_en),
        .imem_init_addr(imem_init_addr),
        .imem_init_data(imem_init_data),
        .dmem_init_en(dmem_init_en),
        .dmem_init_addr(dmem_init_addr),
        .dmem_init_data(dmem_init_data)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset Generation
    initial begin
        rst_n = 0;
        #100 rst_n = 1;
    end

    // Main Test Sequence
    initial begin
        // Initialize
        test_num = 0;
        test_name = "";
        total_errors = 0;
        task_error_count = 0;

        // Open waveform file
        $dumpfile("mem_init_tb.vcd");
        $dumpvars(0, tb_mem_init);

        // Create test firmware file
        create_test_firmware();

        // Wait for reset to complete
        @(posedge rst_n);
        #(CLK_PERIOD*2);

        // Run test cases
        $display("\n[TESTBENCH MEM_INIT][TEST 1] INITIALIZATION SEQUENCE: Starting");
        test_num = 1;
        test_name = "Initialization Sequence";
        test_init_sequence(task_error_count);
        total_errors = total_errors + task_error_count;
        $display("\n[TESTBENCH MEM_INIT][TEST 1] INITIALIZATION SEQUENCE: Completed");

        // Summary
        $display("\nTestbench completed with %0d total errors", total_errors);
        $finish;
    end

    // -------------------------------------------
    // Test Tasks
    // -------------------------------------------

    task create_test_firmware;
        integer file;
        integer i;
        begin
            file = $fopen(INIT_FILE, "w");
            if (!file) begin
                $display("ERROR: Could not create firmware file");
                $finish;
            end
            
            // Write test patterns to file
            for (i = 0; i < 256; i = i + 1) begin
                $fdisplay(file, "%h", 32'hA5A5_A5A5 + i);
            end
            
            $fclose(file);
        end
    endtask

    task test_init_sequence;
        output [31:0] error_count;
        integer i;
        begin
            error_count = 0;
            
            // Start initialization
            init_start = 1;
            @(posedge clk);
            init_start = 0;
            
            // Wait for completion
            wait(init_done);
            
            // Verify IMEM was initialized
            for (i = 0; i < 4; i = i + 1) begin
                if (!dut.imem_init_en || 
                    dut.imem_init_addr !== (IMEM_BASE + (i * 4)) || 
                    dut.imem_init_data !== (32'hA5A5_A5A5 + i)) begin
                    $display("ERROR: IMEM initialization failed at step %0d", i);
                    error_count = error_count + 1;
                end
                @(posedge clk);
            end
            
            // Verify DMEM was zeroed
            for (i = 0; i < 4; i = i + 1) begin
                if (!dut.dmem_init_en || 
                    dut.dmem_init_addr !== (DMEM_BASE + (i * 4)) || 
                    dut.dmem_init_data !== 32'h0) begin
                    $display("ERROR: DMEM initialization failed at step %0d", i);
                    error_count = error_count + 1;
                end
                @(posedge clk);
            end
        end
    endtask

endmodule