`timescale 1ns/1ps

module tb_cpu;
    // Parameters
    parameter CLK_PERIOD = 10;  // 100 MHz
    parameter RESET_PC = 32'h0000_0000;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Wishbone interfaces
    wire wbm_imem_cyc;
    wire wbm_imem_stb;
    wire wbm_imem_we;
    wire [ADDR_WIDTH-1:0] wbm_imem_addr;
    wire [DATA_WIDTH-1:0] wbm_imem_data_write;
    wire [3:0] wbm_imem_sel;
    wire [DATA_WIDTH-1:0] wbm_imem_data_read;
    wire wbm_imem_ack;
    
    wire wbm_dmem_cyc;
    wire wbm_dmem_stb;
    wire wbm_dmem_we;
    wire [ADDR_WIDTH-1:0] wbm_dmem_addr;
    wire [DATA_WIDTH-1:0] wbm_dmem_data_write;
    wire [3:0] wbm_dmem_sel;
    wire [DATA_WIDTH-1:0] wbm_dmem_data_read;
    wire wbm_dmem_ack;
    
    // Memory initialization signals
    wire mem_init_start;
    wire mem_init_done;
    wire imem_init_en;
    wire [ADDR_WIDTH-1:0] imem_init_addr;
    wire [DATA_WIDTH-1:0] imem_init_data;
    wire dmem_init_en;
    wire [ADDR_WIDTH-1:0] dmem_init_addr;
    wire [DATA_WIDTH-1:0] dmem_init_data;
    
    // Testbench control
    integer test_num;
    integer error_count;
    integer cycle_count;
    reg test_complete;
    reg mem_initialized;
    
    // Instantiate the RISC-V core
    cpu #(
        .RESET_PC(RESET_PC),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .REGFILE_ADDR_WIDTH(5)
    ) u_core (
        .clk(clk),
        .rst_n(rst_n),
        
        // Instruction memory interface
        .wbm_imem_cyc(wbm_imem_cyc),
        .wbm_imem_stb(wbm_imem_stb),
        .wbm_imem_we(wbm_imem_we),
        .wbm_imem_addr(wbm_imem_addr),
        .wbm_imem_data_write(wbm_imem_data_write),
        .wbm_imem_sel(wbm_imem_sel),
        .wbm_imem_data_read(wbm_imem_data_read),
        .wbm_imem_ack(wbm_imem_ack),
        
        // Data memory interface
        .wbm_dmem_cyc(wbm_dmem_cyc),
        .wbm_dmem_stb(wbm_dmem_stb),
        .wbm_dmem_we(wbm_dmem_we),
        .wbm_dmem_addr(wbm_dmem_addr),
        .wbm_dmem_data_write(wbm_dmem_data_write),
        .wbm_dmem_sel(wbm_dmem_sel),
        .wbm_dmem_data_read(wbm_dmem_data_read),
        .wbm_dmem_ack(wbm_dmem_ack)
    );
    
    // Instantiate memory initialization
    mem_init #(
        .IMEM_BASE(32'h0000_0000),
        .DMEM_BASE(32'h1000_0000),
        .INIT_FILE("firmware.hex"),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) mem_init_inst (
        .clk(clk),
        .rst_n(rst_n),
        .init_start(mem_init_start),
        .init_done(mem_init_done),
        .imem_init_en(imem_init_en),
        .imem_init_addr(imem_init_addr),
        .imem_init_data(imem_init_data),
        .dmem_init_en(dmem_init_en),
        .dmem_init_addr(dmem_init_addr),
        .dmem_init_data(dmem_init_data)
    );
    
    // Instantiate instruction memory
    imem_wrapper #(
        .BASE_ADDR(32'h0000_0000),
        .SIZE_KB(16),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) imem_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wbs_cyc(wbm_imem_cyc),
        .wbs_stb(wbm_imem_stb),
        .wbs_we(wbm_imem_we),
        .wbs_addr(wbm_imem_addr),
        .wbs_data_write(wbm_imem_data_write),
        .wbs_sel(wbm_imem_sel),
        .wbs_data_read(wbm_imem_data_read),
        .wbs_ack(wbm_imem_ack),
        .init_en(imem_init_en),
        .init_addr(imem_init_addr),
        .init_data(imem_init_data)
    );
    
    // Instantiate data memory
    dmem_wrapper #(
        .BASE_ADDR(32'h1000_0000),
        .SIZE_KB(16),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dmem_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wbs_cyc(wbm_dmem_cyc),
        .wbs_stb(wbm_dmem_stb),
        .wbs_we(wbm_dmem_we),
        .wbs_addr(wbm_dmem_addr),
        .wbs_data_write(wbm_dmem_data_write),
        .wbs_sel(wbm_dmem_sel),
        .wbs_data_read(wbm_dmem_data_read),
        .wbs_ack(wbm_dmem_ack),
        .init_en(dmem_init_en),
        .init_addr(dmem_init_addr),
        .init_data(dmem_init_data)
    );
    
    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Memory initialization control
    assign mem_init_start = rst_n && !mem_initialized;
    
    // Create firmware.hex file with test program
    initial begin
        // Create a simple test program
        integer f;
        f = $fopen("firmware.hex", "w");
        // Test program: add two numbers and store result
        $fdisplay(f, "00500113"); // li sp, 5
        $fdisplay(f, "00600193"); // li gp, 6
        $fdisplay(f, "00310233"); // add tp, sp, gp  (5 + 6 = 11)
        $fdisplay(f, "004102b3"); // add t0, sp, gp  (another add)
        $fdisplay(f, "00510333"); // add t1, sp, gp  (another add)
        $fdisplay(f, "10002423"); // sw zero, 8(tp) Store result
        $fdisplay(f, "00802503"); // lw a0, 8(zero) Load result
        $fdisplay(f, "00000063"); // beq zero, zero, 0 (infinite loop)
        // Fill rest with NOPs
        for (integer i = 8; i < 1024; i = i + 1) begin
            $fdisplay(f, "00000013"); // NOP
        end
        $fclose(f);
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
    
    // Memory initialization tracking
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_initialized <= 1'b0;
        end else if (mem_init_done) begin
            mem_initialized <= 1'b1;
            $display("Memory initialization completed");
        end
    end
    
    // Main test sequence
    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        test_num = 0;
        error_count = 0;
        cycle_count = 0;
        test_complete = 0;
        mem_initialized = 0;
        
        $display("=== RISC-V CPU Testbench Started ===");
        $display("Time\tTest\tDescription");
        $display("-----------------------------------");
        
        // Apply reset
        #20;
        rst_n = 1;
        #10;
        
        $display("%0t\t%0d\tReset released", $time, test_num);
        test_num = test_num + 1;
        
        // Wait for memory initialization
        wait(mem_initialized);
        $display("%0t\t%0d\tMemory initialized", $time, test_num);
        test_num = test_num + 1;
        
        // Wait for test completion or timeout
        wait(test_complete || (error_count > 0));
        
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
    
    // Waveform dumping
    initial begin
        $dumpfile("tb_cpu.vcd");
        $dumpvars(0, tb_cpu);
        // Add signals from submodules for better debugging
        $dumpvars(1, imem_inst);
        $dumpvars(1, dmem_inst);
        $dumpvars(1, mem_init_inst);
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