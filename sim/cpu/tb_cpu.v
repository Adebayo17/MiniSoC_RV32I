`timescale 1ns/1ps

module tb_cpu;
    // Parameters
    parameter CLK_PERIOD            = 10;  // 100 MHz
    parameter RESET_PC              = 32'h0000_0000;
    parameter ADDR_WIDTH            = 32;
    parameter DATA_WIDTH            = 32;
    parameter REGFILE_ADDR_WIDTH    = 5;
    parameter IMEM_BASE_ADDR        = 32'h0000_0000;
    parameter DMEM_BASE_ADDR        = 32'h0000_0000;
    parameter SIZE_KB               = 4;
    parameter INIT_FILE             = "firmware.mem"
    
    // Clock and reset
    reg clk;
    reg rst_n;

    // Test Control
    integer      test_num;
    integer      error_count;
    integer      cycle_count;
    reg          test_complete;
    integer      i;
    integer      f;
    integer      print_mem_init;
    
    // Wishbone interfaces
    wire                    wbm_imem_cyc;
    wire                    wbm_imem_stb;
    wire                    wbm_imem_we;
    wire [ADDR_WIDTH-1:0]   wbm_imem_addr;
    wire [DATA_WIDTH-1:0]   wbm_imem_data_write;
    wire [3:0]              wbm_imem_sel;
    wire [DATA_WIDTH-1:0]   wbm_imem_data_read;
    wire                    wbm_imem_ack;
    
    wire                    wbm_dmem_cyc;
    wire                    wbm_dmem_stb;
    wire                    wbm_dmem_we;
    wire [ADDR_WIDTH-1:0]   wbm_dmem_addr;
    wire [DATA_WIDTH-1:0]   wbm_dmem_data_write;
    wire [3:0]              wbm_dmem_sel;
    wire [DATA_WIDTH-1:0]   wbm_dmem_data_read;
    wire                    wbm_dmem_ack;
    
    // Memory initialization signals
    wire                    mem_init_start;
    wire                    mem_init_done;
    wire                    imem_init_en;
    wire [ADDR_WIDTH-1:0]   imem_init_addr;
    wire [DATA_WIDTH-1:0]   imem_init_data;
    wire                    dmem_init_en;
    wire [ADDR_WIDTH-1:0]   dmem_init_addr;
    wire [DATA_WIDTH-1:0]   dmem_init_data;
    

    // Mem_init control
    reg     mem_initialized;
    
    // Instantiate the RISC-V core
    cpu #(
        .RESET_PC           (RESET_PC           ),
        .ADDR_WIDTH         (ADDR_WIDTH         ),
        .DATA_WIDTH         (DATA_WIDTH         ),
        .REGFILE_ADDR_WIDTH (REGFILE_ADDR_WIDTH )
    ) dut (
        .clk                    (clk                    ),
        .rst_n                  (rst_n && mem_init_done ),
        .wbm_imem_cyc           (wbm_imem_cyc           ),
        .wbm_imem_stb           (wbm_imem_stb           ),
        .wbm_imem_we            (wbm_imem_we            ),
        .wbm_imem_addr          (wbm_imem_addr          ),
        .wbm_imem_data_write    (wbm_imem_data_write    ),
        .wbm_imem_sel           (wbm_imem_sel           ),
        .wbm_imem_data_read     (wbm_imem_data_read     ),
        .wbm_imem_ack           (wbm_imem_ack           ),
        .wbm_dmem_cyc           (wbm_dmem_cyc           ),
        .wbm_dmem_stb           (wbm_dmem_stb           ),
        .wbm_dmem_we            (wbm_dmem_we            ),
        .wbm_dmem_addr          (wbm_dmem_addr          ),
        .wbm_dmem_data_write    (wbm_dmem_data_write    ),
        .wbm_dmem_sel           (wbm_dmem_sel           ),
        .wbm_dmem_data_read     (wbm_dmem_data_read     ),
        .wbm_dmem_ack           (wbm_dmem_ack           )
    );
    
    // Instantiate memory initialization
    mem_init #(
        .IMEM_BASE(IMEM_BASE_ADDR),
        .DMEM_BASE(DMEM_BASE_ADDR),
        .INIT_FILE(INIT_FILE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) mem_init_inst (
        .clk                    (clk                    ),
        .rst_n                  (rst_n                  ),
        .init_start             (mem_init_start         ),
        .init_done              (mem_init_done          ),
        .imem_init_en           (imem_init_en           ),
        .imem_init_addr         (imem_init_addr         ),
        .imem_init_data         (imem_init_data         ),
        .dmem_init_en           (dmem_init_en           ),
        .dmem_init_addr         (dmem_init_addr         ),
        .dmem_init_data         (dmem_init_data         )
    );
    
    // Instantiate instruction memory
    imem_wrapper #(
        .BASE_ADDR(IMEM_BASE_ADDR),
        .SIZE_KB(SIZE_KB),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) imem_inst (
        .clk                    (clk                    ),
        .rst_n                  (rst_n                  ),
        .wbs_cyc                (wbm_imem_cyc           ),
        .wbs_stb                (wbm_imem_stb           ),
        .wbs_we                 (wbm_imem_we            ),
        .wbs_addr               (wbm_imem_addr          ),
        .wbs_data_write         (wbm_imem_data_write    ),
        .wbs_sel                (wbm_imem_sel           ),
        .wbs_data_read          (wbm_imem_data_read     ),
        .wbs_ack                (wbm_imem_ack           ),
        .init_en                (imem_init_en           ),
        .init_addr              (imem_init_addr         ),
        .init_data              (imem_init_data         )
    );
    
    // Instantiate data memory
    dmem_wrapper #(
        .BASE_ADDR(IMEM_BASE_ADDR),
        .SIZE_KB(SIZE_KB),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dmem_inst (
        .clk                    (clk                    ),
        .rst_n                  (rst_n                  ),
        .wbs_cyc                (wbm_dmem_cyc           ),
        .wbs_stb                (wbm_dmem_stb           ),
        .wbs_we                 (wbm_dmem_we            ),
        .wbs_addr               (wbm_dmem_addr          ),
        .wbs_data_write         (wbm_dmem_data_write    ),
        .wbs_sel                (wbm_dmem_sel           ),
        .wbs_data_read          (wbm_dmem_data_read     ),
        .wbs_ack                (wbm_dmem_ack           ),
        .init_en                (dmem_init_en           ),
        .init_addr              (dmem_init_addr         ),
        .init_data              (dmem_init_data         )
    );
    
    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset Generation
    initial begin
        rst_n           = 0;
        test_num        = 0;
        error_count     = 0;
        cycle_count     = 0;
        test_complete   = 0;
        mem_initialized = 0;
        print_mem_init  = 0;

        #(CLK_PERIOD*100) rst_n  = 1;
    end
    
    // Memory initialization control
    assign mem_init_start = rst_n && !mem_initialized;
    
    // Create firmware.hex file with test program
    initial begin
        // Create a simple test program
        f = $fopen(INIT_FILE, "w");

        // Load DMEM base address
        $fdisplay(f, "10000537"); // lui x10, 0x10000

        // Load constants
        $fdisplay(f, "00500093"); // addi x1, x0, 5
        $fdisplay(f, "00600113"); // addi x2, x0, 6

        // Add
        $fdisplay(f, "002081b3"); // add x3, x1, x2

        // Store result into dmem[0x1000_0000]
        $fdisplay(f, "00352023"); // sw x3, 0(x10)

        // Load result back
        $fdisplay(f, "00052283"); // lw x4, 0(x10)

        // Infinite loop
        $fdisplay(f, "00000063"); // beq x0, x0, 0
        
        // Fill rest with NOPs
        for (i = 8; i < 1024; i = i + 1) begin
            $fdisplay(f, "00000013"); // NOP
        end
        $fclose(f);
    end
    
    // Memory initialization tracking
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_initialized <= 1'b0;
        end else if (mem_init_done) begin
            mem_initialized <= 1'b1;
            if (!print_mem_init) begin
                $display("Memory initialization completed");
                print_mem_init  <= 1'b1;
            end
        end
    end
    
    // Main test sequence
    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, tb_cpu);
        // Add signals from submodules for better debugging
        $dumpvars(1, imem_inst);
        $dumpvars(1, dmem_inst);
        $dumpvars(1, mem_init_inst);
        
        $display("=== RISC-V CPU Testbench Started ===");
        
        // Test 1
        test_num = 1;
        $display("\n[TEST %0d] CPU Reset Released: Starting", test_num);
        $display("Time\tTest\tDescription");
        $display("-----------------------------------");
        wait(rst_n);
        #(CLK_PERIOD*2);
        $display("%0t\t%0d\tReset released", $time, test_num);
        $display("[TEST %0d] CPU Reset Released: Completed\n", test_num);
        
        // Test 2
        test_num = test_num + 1;
        $display("\n[TEST %0d] CPU Memory initialized: Starting", test_num);
        $display("Time\tTest\tDescription");
        $display("-----------------------------------");
        // Wait for memory initialization
        wait(mem_initialized);
        $display("%0t\t%0d\tMemory initialized", $time, test_num);
        $display("[TEST %0d] CPU Memory initialized: Completed\n", test_num);

        // Test 3
        test_num = test_num + 1;
        $display("\n[TEST %0d] CPU Execution: Starting", test_num);
        $display("Time\tTest\tDescription");
        $display("-----------------------------------");
        // Wait for test completion or timeout
        wait(test_complete || (error_count > 0));
        $display("%0t\t%0d\tMemory initialized", $time, test_num);
        $display("[TEST %0d] CPU Execution: Completed\n", test_num);
        
        // Summary
        $display("===================================");
        $display("Test Summary:");
        $display("Total cycles: %0d", cycle_count);
        $display("Errors: %0d", error_count);
        
        if (error_count == 0) begin
            $display("✅ TEST PASSED!");
        end else begin
            $display("❌ TEST FAILED!");
        end
        
        $finish;
    end

    // Monitor CPU activity
    always @(posedge clk) begin
        if (rst_n && mem_initialized) begin
            cycle_count <= cycle_count + 1;
            
            // Timeout detection
            if (cycle_count > 500 && !test_complete) begin
                $display("ERROR: Test timeout at cycle %0d", cycle_count);
                error_count = error_count + 1;
                $finish;
            end
            
            // Check for test completion (infinite loop)
            if (wbm_imem_addr == 32'h0000001C) begin // PC at instruction 7
                test_complete <= 1'b1;
                // Allow some time for the store to complete
                #(CLK_PERIOD * 5);
                
                // Verify the result by checking memory directly
                if (dmem_inst.dmem_inst.mem[2] == 32'h0000000B) begin
                    $display("✅ Test PASSED! Result is correct: 5 + 6 = 11");
                end else begin
                    $display("❌ Test FAILED! Expected 11, got %0d", dmem_inst.dmem_inst.mem[2]);
                    error_count = error_count + 1;
                end
                #100;
                $finish;
            end
        end
    end

    
    // Monitor interesting events
    always @(posedge clk) begin
        if (rst_n && mem_initialized) begin
            // Log instruction fetches
            if (wbm_imem_cyc && wbm_imem_stb && !wbm_imem_we) begin
                $display("IFetch: PC=%h, Instruction=%h", wbm_imem_addr, wbm_imem_data_read);
            end
            
            // Log memory accesses
            if (wbm_dmem_cyc && wbm_dmem_stb) begin
                if (wbm_dmem_we) begin
                    $display("MemWrite: Addr=%h, Data=%h, Sel=%b", wbm_dmem_addr, wbm_dmem_data_write, wbm_dmem_sel);
                end else begin
                    $display("MemRead: Addr=%h, Data=%h", wbm_dmem_addr, wbm_dmem_data_read);
                end
            end
        end
    end
    
endmodule