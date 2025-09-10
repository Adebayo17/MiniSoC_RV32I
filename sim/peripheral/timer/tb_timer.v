`timescale 1ns/1ps

module tb_timer;
    // Parameters
    parameter CLK_PERIOD    = 10; // 100MHz
    parameter CLK_FREQ      = 100_000_000;
    parameter ADDR_WIDTH    = 32;
    parameter DATA_WIDTH    = 32;
    parameter BASE_ADDR     = 32'h3000_0000;
    parameter SIZE_KB       = 4;


    // Clock and reset
    reg clk;
    reg rst_n;

    // Test Control
    reg [31:0]   test_num;
    reg [8*40:1] test_name;
    reg [31:0]   task_error_count;
    reg [31:0]   total_errors;

    // Wishbone Interface
    reg                     wbs_cyc;
    reg                     wbs_stb;
    reg                     wbs_we;
    reg [ADDR_WIDTH-1:0]    wbs_addr;
    reg [DATA_WIDTH-1:0]    wbs_data_write;
    reg [3:0]               wbs_sel;
    wire [DATA_WIDTH-1:0]   wbs_data_read;
    wire                    wbs_ack;

    // Testbench Signals
    integer i;

    // Instantiate DUT
    timer_wrapper #(
        .BASE_ADDR(BASE_ADDR),
        .SIZE_KB(SIZE_KB),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk                (clk            ),
        .rst_n              (rst_n          ),
        .wbs_cyc            (wbs_cyc        ),
        .wbs_stb            (wbs_stb        ),
        .wbs_we             (wbs_we         ),
        .wbs_addr           (wbs_addr       ),
        .wbs_data_write     (wbs_data_write ),
        .wbs_sel            (wbs_sel        ),
        .wbs_data_read      (wbs_data_read  ),
        .wbs_ack            (wbs_ack        )
    );
    

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset Generation 
    initial begin
        rst_n           = 0;
        
        wbs_cyc         = 0; 
        wbs_stb         = 0; 
        wbs_we          = 0;
        wbs_addr        = 0; 
        wbs_data_write  = 0; 
        wbs_sel         = 0;

        test_num         = 0;
        total_errors     = 0;
        task_error_count = 0;

        #100 rst_n    = 1;   
    end

    // Main Test Sequence
    initial begin
        $dumpfile("timer_tb.vcd");
        $dumpvars(0, tb_timer);

        wait(rst_n);
        #(CLK_PERIOD*2);

        $display("\n=== TIMER Testbench Started ===");

        // Test 1: Reset Value
        test_num = 1;
        $display("\n[TEST %0d] TIMER Reset Value: Starting", test_num);
        task_error_count = 0;
        test_reset_values(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] TIMER Reset Value: Completed\n", test_num);

        // Test 2: Free Running
        test_num = 2;
        $display("\n[TEST %0d] TIMER Free Running: Starting", test_num);
        task_error_count = 0;
        test_free_running(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] TIMER Free Running: Completed\n", test_num);

        // Test 3: Compare Match
        test_num = 3;
        $display("\n[TEST %0d] TIMER Compare Match: Starting", test_num);
        task_error_count = 0;
        test_compare_match(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] TIMER Compare Match: Completed\n", test_num);

        // Test 4: One Shot Mode
        test_num = 4;
        $display("\n[TEST %0d] TIMER One Shot Mode: Starting", test_num);
        task_error_count = 0;
        test_one_shot_mode(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] TIMER One Shot Mode: Completed\n", test_num);

        // Test 5: Prescaler
        test_num = 5;
        $display("\n[TEST %0d] TIMER Prescaler: Starting", test_num);
        task_error_count = 0;
        test_prescaler(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] TIMER Prescaler: Completed\n", test_num);

        // Test 6: Status Register
        test_num = 6;
        $display("\n[TEST %0d] TIMER Status Register: Starting", test_num);
        task_error_count = 0;
        test_status_register(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] TIMER Status Register: Completed\n", test_num);


        // Summary
        $display("\n=== TIMER Testbench Completed ===");
        $display("\nTotal errors: %0d", total_errors);
        if (total_errors == 0) begin
            $display("✅ All tests PASSED!");
        end else begin
            $display("❌ Some tests FAILED");
        end
        $finish;
    end

    // -------------------------------------------
    // Test Tasks
    // -------------------------------------------

    task test_reset_values;
        output [31:0] error_count;
        reg [31:0] read_data;
        begin
            error_count = 0;

            // Test all registers after reset
            wb_read(BASE_ADDR + 12'h000, read_data); // COUNT
            if (read_data !== 32'h0000_0000) begin
                $display("ERROR: COUNT not zero after reset: %h", read_data);
                error_count++;
            end

            wb_read(BASE_ADDR + 12'h004, read_data); // CMP
            if (read_data !== 32'h0000_0000) begin
                $display("ERROR: CMP not zero after reset: %h", read_data);
                error_count++;
            end

            wb_read(BASE_ADDR + 12'h008, read_data); // CTRL
            if (read_data[3:0] !== 4'b0000) begin
                $display("ERROR: CTRL not zero after reset: %b", read_data[3:0]);
                error_count++;
            end

            wb_read(BASE_ADDR + 12'h00C, read_data); // STATUS
            if (read_data[1:0] !== 2'b00) begin
                $display("ERROR: STAT not zero after reset: %b", read_data[1:0]);
                error_count++;
            end

            $display("Reset values test completed with %0d errors", error_count);
        end
    endtask

    task test_free_running;
        output [31:0] error_count;
        reg [31:0] read_data1, read_data2;
        begin
            error_count = 0;

            // Enable timer, free-running, prescale=1
            wb_write(BASE_ADDR + 12'h008, 32'h0000_0001, 4'b0001); // CTRL = 0x01

            // Read counter twice to verify it's counting
            wb_read(BASE_ADDR + 12'h000, read_data1);
            #(CLK_PERIOD * 5);
            wb_read(BASE_ADDR + 12'h000, read_data2);

            if (read_data2 <= read_data1) begin
                $display("ERROR: Counter not incrementing: %d -> %d", read_data1, read_data2);
                error_count++;
            end else begin
                $display("[INFO]: read_data1 = %d ", read_data1);
                $display("[INFO]: read_data2 = %d ", read_data2);
            end

            // Disable timer and verify it stops
            wb_write(BASE_ADDR + 12'h008, 32'h0000_0000, 4'b0001); // CTRL = 0x00
            wb_read(BASE_ADDR + 12'h000, read_data1);
            #(CLK_PERIOD * 3);
            wb_read(BASE_ADDR + 12'h000, read_data2);

            if (read_data2 !== read_data1) begin
                $display("ERROR: Counter still incrementing when disabled: %d -> %d", read_data1, read_data2);
                error_count++;
            end

            $display("Free-running test completed with %0d errors", error_count);
        end
    endtask

    task test_compare_match;
        output [31:0] error_count;
        reg [31:0] read_data;
        begin
            error_count = 0;

            // Configure timer
            wb_write(BASE_ADDR + 12'h004, 32'h0000_000A, 4'b1111); // CMP = 10
            wb_write(BASE_ADDR + 12'h008, 32'h0000_0001, 4'b0001); // CTRL = 0x01

            // Wait for match
            #(CLK_PERIOD * 15);

            // Check status register
            wb_read(BASE_ADDR + 12'h00C, read_data);
            if (read_data[0] !== 1'b1) begin
                $display("ERROR: Match flag not set: %b", read_data[0]);
                error_count++;
            end

            // Clear flag
            wb_write(BASE_ADDR + 12'h00C, 32'h0000_0001, 4'b0001); // Clear match flag
            wb_read(BASE_ADDR + 12'h00C, read_data);
            if (read_data[0] !== 1'b0) begin
                $display("ERROR: Match flag not cleared: %b", read_data[0]);
                error_count++;
            end

            $display("Compare match test completed with %0d errors", error_count);
        end
    endtask

    task test_one_shot_mode;
        output [31:0] error_count;
        reg [31:0] read_data;
        begin
            error_count = 0;

            // Configure one-shot mode
            wb_write(BASE_ADDR + 12'h004, 32'h0000_0005, 4'b1111); // CMP = 5
            wb_write(BASE_ADDR + 12'h008, 32'h0000_0003, 4'b0001); // CTRL = 0x03 (enable + one-shot)

            // Wait for match
            #(CLK_PERIOD * 10);

            // Verify counter stopped at match value
            wb_read(BASE_ADDR + 12'h000, read_data);
            if (read_data !== 32'h0000_0005) begin
                $display("ERROR: Counter not stopped in one-shot mode: %d", read_data);
                error_count++;
            end

            // Check status
            wb_read(BASE_ADDR + 12'h00C, read_data);
            if (read_data[0] !== 1'b1) begin
                $display("ERROR: Match flag not set in one-shot: %b", read_data[0]);
                error_count++;
            end

            $display("One-shot test completed with %0d errors", error_count);
        end
    endtask

    task test_prescaler;
        output [31:0] error_count;
        reg [31:0] read_data1, read_data2;
        begin
            error_count = 0;

            // Test prescale=8
            wb_write(BASE_ADDR + 12'h008, 32'h0000_0005, 4'b0001); // CTRL = 0x05 (enable + prescale=8)
            
            // Read counter after some time
            wb_read(BASE_ADDR + 12'h000, read_data1);
            #(CLK_PERIOD * 40); // 4 timer ticks with prescale=8
            wb_read(BASE_ADDR + 12'h000, read_data2);

            // Should have advanced by approximately 4
            if ((read_data2 - read_data1) < 3 || (read_data2 - read_data1) > 5) begin
                $display("ERROR: Prescaler not working: advanced by %d (expected ~4)", read_data2 - read_data1);
                error_count++;
            end

            $display("Prescaler test completed with %0d errors", error_count);
        end
    endtask

    task test_status_register;
        output [31:0] error_count;
        reg [31:0] read_data;
        begin
            error_count = 0;

            // Test overflow detection
            wb_write(BASE_ADDR + 12'h008, 32'h0000_0001, 4'b0001); // CTRL = 0x01
            wb_write(BASE_ADDR + 12'h004, 32'hFFFF_FFFC, 4'b1111); // CMP = almost max

            // Wait for overflow
            #(CLK_PERIOD * 10);

            wb_read(BASE_ADDR + 12'h00C, read_data);
            if (read_data[1] !== 1'b1) begin
                $display("ERROR: Overflow flag not set: %b", read_data[1]);
                error_count++;
            end

            // Clear both flags
            wb_write(BASE_ADDR + 12'h00C, 32'h0000_0003, 4'b0001); // Clear both flags
            wb_read(BASE_ADDR + 12'h00C, read_data);
            if (read_data[1:0] !== 2'b00) begin
                $display("ERROR: Flags not cleared: %b", read_data[1:0]);
                error_count++;
            end

            $display("Status register test completed with %0d errors", error_count);
        end
    endtask



    // -------------------------------------------
    // Wishbone Bus Tasks
    // -------------------------------------------
    
    task wb_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [3:0] sel;
        begin
            @(posedge clk);
            wbs_cyc = 1;
            wbs_stb = 1;
            wbs_we = 1;
            wbs_addr = addr;
            wbs_data_write = data;
            wbs_sel = sel;
            
            @(posedge clk);
            while (!wbs_ack) @(posedge clk);
            
            wbs_cyc = 0;
            wbs_stb = 0;
            wbs_we = 0;
            @(posedge clk);
        end
    endtask
    
    task wb_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            wbs_cyc = 1;
            wbs_stb = 1;
            wbs_we = 0;
            wbs_addr = addr;
            
            @(posedge clk);
            while (!wbs_ack) @(posedge clk);
            data = wbs_data_read;
            
            wbs_cyc = 0;
            wbs_stb = 0;
            @(posedge clk);
        end
    endtask
endmodule