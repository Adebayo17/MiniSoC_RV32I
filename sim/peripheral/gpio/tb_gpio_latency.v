`timescale 1ns/1ps

module tb_gpio_latency;
    // Parameters (same as original)
    parameter CLK_PERIOD    = 10;
    parameter CLK_FREQ      = 100_000_000;
    parameter ADDR_WIDTH    = 32;
    parameter DATA_WIDTH    = 32;
    parameter BASE_ADDR     = 32'h4000_0000;
    parameter N_GPIO        = 8;

    // Clock and reset
    reg clk;
    reg rst_n;

    // Wishbone Interface
    reg                     wbs_cyc;
    reg                     wbs_stb;
    reg                     wbs_we;
    reg [ADDR_WIDTH-1:0]    wbs_addr;
    reg [DATA_WIDTH-1:0]    wbs_data_write;
    reg [3:0]               wbs_sel;
    wire [DATA_WIDTH-1:0]   wbs_data_read;
    wire                    wbs_ack;

    // GPIO Physical Interface
    reg  [N_GPIO-1:0]       gpio_in;
    wire [N_GPIO-1:0]       gpio_out;
    wire [N_GPIO-1:0]       gpio_oe;

    // Testbench Signals
    integer write_latency, read_latency;
    integer output_update_latency, oe_update_latency;
    integer sync_latency;
    integer start_time, end_time;
    integer stb_assert_time, ack_assert_time;
    integer test_start;

    // Instantiate DUT
    gpio_wrapper #(
        .BASE_ADDR(BASE_ADDR),
        .SIZE_KB(4),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .N_GPIO(N_GPIO)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wbs_cyc(wbs_cyc),
        .wbs_stb(wbs_stb),
        .wbs_we(wbs_we),
        .wbs_addr(wbs_addr),
        .wbs_data_write(wbs_data_write),
        .wbs_sel(wbs_sel),
        .wbs_data_read(wbs_data_read),
        .wbs_ack(wbs_ack),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_oe(gpio_oe)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset Generation
    initial begin
        rst_n = 0;
        stb_assert_time = 0;
        ack_assert_time = 0;
        test_start = 0;
        wbs_cyc = 0; wbs_stb = 0; wbs_we = 0;
        wbs_addr = 0; wbs_data_write = 0; wbs_sel = 0;
        gpio_in = 0;
        #100 rst_n = 1;
    end

    // Monitor STB assertion time
    always @(posedge clk) begin
        if (test_start) begin
            if (wbs_stb === 1'b1) begin
                stb_assert_time = $time;
            end
        end
        
    end

    // Monitor ACK assertion time
    always @(posedge clk) begin
        if (test_start) begin
            if (wbs_ack === 1'b1) begin
                ack_assert_time = $time;
            end 
        end
        
    end

    // Main Test Sequence
    initial begin
        $dumpfile("gpio_latency_tb.vcd");
        $dumpvars(0, tb_gpio_latency);
        
        wait(rst_n);
        #(CLK_PERIOD*4); // Wait a bit longer after reset
        
        $display("\n=== GPIO Latency Testbench Started ===");
        
        test_write_latency();
        test_read_latency();
        test_output_propagation_latency();
        test_input_sync_latency();
        test_atomic_operation_latency();
        
        $display("\n=== GPIO Latency Testbench Completed ===");
        $finish;
    end

    // -------------------------------------------
    // Fixed Latency Test Tasks
    // -------------------------------------------

    task test_write_latency;
        begin
            $display("\n[TEST] Write Latency Measurement");
            test_start = 1;
            
            @(posedge clk);
            wb_write(BASE_ADDR + 12'h000, 32'h0000_00FF, 4'b0001);
            
            write_latency = (ack_assert_time - stb_assert_time) / CLK_PERIOD;
            $display("Write latency (STB to ACK): %0d cycles", write_latency);
            
            test_start = 0;
        end
    endtask

    task test_read_latency;
        reg [31:0] read_data;
        begin
            $display("\n[TEST] Read Latency Measurement");
            test_start = 1;
            
            @(posedge clk);
            wb_read(BASE_ADDR + 12'h000, read_data);
            
            read_latency = (ack_assert_time - stb_assert_time) / CLK_PERIOD;
            $display("Read latency (STB to ACK): %0d cycles", read_latency);
            $display("Read data: %h", read_data);
            
            test_start = 0;
        end
    endtask

    task test_output_propagation_latency;
        begin
            $display("\n[TEST] Output Propagation Latency");
            test_start = 1;
            
            // First set direction to output
            wb_write(BASE_ADDR + 12'h004, 32'h0000_00FF, 4'b0001);
            #(CLK_PERIOD*2);
            
            // Measure DATA register to output latency
            @(posedge clk);
            wb_write(BASE_ADDR + 12'h000, 32'h0000_00AA, 4'b0001);
            start_time = $time;
            
            // Wait for output to update (should be next clock edge)
            @(posedge clk);
            if (gpio_out === 8'hAA) begin
                end_time = $time;
                output_update_latency = (end_time - start_time) / CLK_PERIOD;
                $display("DATA to output latency: %0d cycles", output_update_latency);
            end else begin
                $display("ERROR: Output not updated as expected");
            end
            
            // Measure DIR register to OE latency
            @(posedge clk);
            wb_write(BASE_ADDR + 12'h004, 32'h0000_0055, 4'b0001);
            start_time = $time;
            
            @(posedge clk);
            if (gpio_oe === 8'h55) begin
                end_time = $time;
                oe_update_latency = (end_time - start_time) / CLK_PERIOD;
                $display("DIR to OE latency: %0d cycles", oe_update_latency);
            end else begin
                $display("ERROR: OE not updated as expected");
            end

            test_start = 0;
        end
    endtask

    task test_input_sync_latency;
        reg [31:0] read_data;
        begin
            $display("\n[TEST] Input Synchronization Latency");
            
            // Set as input first
            wb_write(BASE_ADDR + 12'h004, 32'h0000_0000, 4'b0001);
            #(CLK_PERIOD*2);
            
            // Read initial value
            wb_read(BASE_ADDR + 12'h000, read_data);
            $display("Initial input value: %h", read_data);
            
            // Change input and measure sync time
            @(posedge clk);
            gpio_in = 8'hAA;
            start_time = $time;
            
            // Wait for synchronized value to appear (2 cycles for double sync)
            #(CLK_PERIOD * 2);
            wb_read(BASE_ADDR + 12'h000, read_data);
            
            if (read_data[7:0] === 8'hAA) begin
                end_time = $time;
                sync_latency = (end_time - start_time) / CLK_PERIOD;
                $display("Input sync latency: %0d cycles", sync_latency);
                $display("Synced value: %h", read_data);
            end else begin
                $display("ERROR: Input not synchronized correctly");
            end
        end
    endtask

    task test_atomic_operation_latency;
        begin
            $display("\n[TEST] Atomic Operation Latency");
            
            // Set pin 0 as output first
            wb_write(BASE_ADDR + 12'h004, 32'h0000_0001, 4'b0001);
            #(CLK_PERIOD*2);
            
            // Test SET operation latency from STB to output update
            @(posedge clk);
            wb_write(BASE_ADDR + 12'h008, 32'h0000_0001, 4'b0001);
            start_time = $time;
            
            // Wait for output to reflect the change
            @(posedge clk);
            if (gpio_out[0] === 1'b1) begin
                end_time = $time;
                $display("SET operation latency: %0d cycles", (end_time - start_time) / CLK_PERIOD);
            end else begin
                $display("ERROR: SET operation failed");
            end
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
            while (wbs_ack !== 1'b1) @(posedge clk);
            
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
            while (wbs_ack !== 1'b1) @(posedge clk);
            data = wbs_data_read;
            
            wbs_cyc = 0;
            wbs_stb = 0;
            @(posedge clk);
        end
    endtask

endmodule