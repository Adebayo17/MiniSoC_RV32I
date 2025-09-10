`timescale 1ns/1ps

module tb_gpio;
    // Parameters
    parameter CLK_PERIOD    = 10; // 100MHz
    parameter CLK_FREQ      = 100_000_000;
    parameter ADDR_WIDTH    = 32;
    parameter DATA_WIDTH    = 32;
    parameter BASE_ADDR     = 32'h4000_0000;
    parameter SIZE_KB       = 4;
    parameter N_GPIO        = 8;


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


    // GPIO Physical Interface
    reg  [N_GPIO-1:0]       gpio_in;
    wire  [N_GPIO-1:0]       gpio_out;
    wire [N_GPIO-1:0]       gpio_oe; 
    

    // Testbench Signals
    integer i;

    // Instantiate DUT
    gpio_wrapper #(
        .BASE_ADDR(BASE_ADDR),
        .SIZE_KB(SIZE_KB),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .N_GPIO(N_GPIO)
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
        .wbs_ack            (wbs_ack        ),
        .gpio_in            (gpio_in        ),
        .gpio_out           (gpio_out       ),
        .gpio_oe            (gpio_oe        )
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
        gpio_in         = 0;

        test_num         = 0;
        total_errors     = 0;
        task_error_count = 0;

        #100 rst_n    = 1;   
    end

    // Main Test Sequence
    initial begin
        $dumpfile("gpio_tb.vcd");
        $dumpvars(0, tb_gpio);

        wait(rst_n);
        #(CLK_PERIOD*2);

        $display("\n=== GPIO Testbench Started ===");

        // Test 1: Basic Configuration
        test_num = 1;
        $display("\n[TEST %0d] GPIO Configuration: Starting", test_num);
        task_error_count = 0;
        test_gpio_configuration(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] GPIO Configuration: Completed\n", test_num);

        // Test 2: Output Functionality
        test_num = 2;
        $display("\n[TEST %0d] GPIO Output Functionality: Starting", test_num);
        task_error_count = 0;
        test_output_functionality(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] GPIO Output Functionality: Completed\n", test_num);

        // Test 3: Input Functionality
        test_num = 3;
        $display("\n[TEST %0d] GPIO Input Functionality: Starting", test_num);
        task_error_count = 0;
        test_input_functionality(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] GPIO Input Functionality: Completed\n", test_num);

        // Test 4: Atomic Operation
        test_num = 4;
        $display("\n[TEST %0d] GPIO Atomic Operation: Starting", test_num);
        task_error_count = 0;
        test_atomic_operations(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] GPIO Atomic Operation: Completed\n", test_num);

        // Test 4: Mixed I/O
        test_num = 5;
        $display("\n[TEST %0d] GPIO Mixed I/O: Starting", test_num);
        task_error_count = 0;
        test_mixed_io(task_error_count);
        total_errors += task_error_count;
        $display("[TEST %0d] GPIO Mixed I/O: Completed\n", test_num);


        // Summary
        $display("\n=== GPIO Testbench Completed ===");
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
    task test_gpio_configuration;
        output [31:0] error_count;
        reg [DATA_WIDTH-1:0] read_data;
        begin
            error_count = 0;
            read_data = 0;

            // Test initial state
            wb_read(BASE_ADDR + 12'h000, read_data); // DATA register
            if (read_data !== 32'h0000_0000) begin
                $display("ERROR: DATA register not zero after reset: %h", read_data);
                error_count++;
            end

            wb_read(BASE_ADDR + 12'h004, read_data); // DIR register
            if (read_data !== 32'h0000_0000) begin
                $display("ERROR: DIR register not zero after reset: %h", read_data);
                error_count++;
            end

            // Check all pins are inputs after reset
            if (gpio_oe !== 8'h00) begin
                $display("ERROR: GPIO_OE not all inputs after reset: %b", gpio_oe);
                error_count++;
            end

            $display("Configuration test completed");
        end
    endtask

    task test_output_functionality;
        output [31:0] error_count;
        reg [31:0] read_data;
        begin
            error_count = 0;
            read_data = 0;

            // Set pin 0 and 1 as outputs
            wb_write(BASE_ADDR + 12'h004, 32'h0000_0003, 4'b0001); // DIR = 0x03

            // Write output values
            wb_write(BASE_ADDR + 12'h000, 32'h0000_0001, 4'b0001); // DATA = 0x01

            // Verify outputs
            if (gpio_out !== 8'h01) begin
                $display("ERROR: GPIO_OUT incorrect: expected 01, got %b", gpio_out);
                error_count++;
            end

            if (gpio_oe !== 8'h03) begin
                $display("ERROR: GPIO_OE incorrect: expected 03, got %b", gpio_oe);
                error_count++;
            end

            // Read back data register
            wb_read(BASE_ADDR + 12'h000, read_data);
            if (read_data[7:0] !== 8'h01) begin
                $display("ERROR: DATA register readback incorrect: expected 01, got %h", read_data);
                error_count++;
            end

            $display("Output functionality test completed with %0d errors", error_count);
        end
    endtask

    task test_input_functionality;
        output [31:0] error_count;
        reg [31:0] read_data;
        begin
            error_count = 0;
            read_data = 0;

            // Set all pins as inputs (default)
            wb_write(BASE_ADDR + 12'h004, 32'h0000_0000, 4'b0001); // DIR = 0x00

            // Apply input signals
            gpio_in = 8'hA5;
            #(CLK_PERIOD * 3); // Wait for synchronization

            // Read input values
            wb_read(BASE_ADDR + 12'h000, read_data);
            if (read_data[7:0] !== 8'hA5) begin
                $display("ERROR: Input read incorrect: expected A5, got %h", read_data);
                error_count++;
            end

            // Verify outputs are not driving
            if (gpio_oe !== 8'h00) begin
                $display("ERROR: GPIO_OE should be all inputs: got %b", gpio_oe);
                error_count++;
            end

            $display("Input functionality test completed with %0d errors", error_count);
        end
    endtask


    task test_atomic_operations;
        output [31:0] error_count;
        reg [31:0] read_data;
        begin
            error_count = 0;
            read_data = 0;

            // Set pin 2 as output
            wb_write(BASE_ADDR + 12'h004, 32'h0000_0004, 4'b0001); // DIR = 0x04

            // Test SET operation
            wb_write(BASE_ADDR + 12'h008, 32'h0000_0004, 4'b0001); // SET bit 2
            if (gpio_out[2] !== 1'b1) begin
                $display("ERROR: SET operation failed: bit 2 should be 1");
                error_count++;
            end

            // Test CLEAR operation
            wb_write(BASE_ADDR + 12'h00C, 32'h0000_0004, 4'b0001); // CLEAR bit 2
            if (gpio_out[2] !== 1'b0) begin
                $display("ERROR: CLEAR operation failed: bit 2 should be 0");
                error_count++;
            end

            // Test TOGGLE operation
            wb_write(BASE_ADDR + 12'h010, 32'h0000_0004, 4'b0001); // TOGGLE bit 2
            if (gpio_out[2] !== 1'b1) begin
                $display("ERROR: TOGGLE operation failed: bit 2 should be 1");
                error_count++;
            end

            wb_write(BASE_ADDR + 12'h010, 32'h0000_0004, 4'b0001); // TOGGLE again
            if (gpio_out[2] !== 1'b0) begin
                $display("ERROR: TOGGLE operation failed: bit 2 should be 0");
                error_count++;
            end

            $display("Atomic operations test completed with %0d errors", error_count);
        end
    endtask

    task test_mixed_io;
        output [31:0] error_count;
        reg [31:0] read_data;
        begin
            error_count = 0;
            read_data = 0;

            // Configure mixed I/O: pins 0-3 as outputs, 4-7 as inputs
            wb_write(BASE_ADDR + 12'h004, 32'h0000_000F, 4'b0001); // DIR = 0x0F

            // Set output values
            wb_write(BASE_ADDR + 12'h000, 32'h0000_0005, 4'b0001); // DATA = 0x05

            // Apply input signals to input pins
            gpio_in = 8'hF0; // Inputs will be 0xF0, but outputs drive 0x05
            #(CLK_PERIOD * 3);

            // Read back - should show mixed values
            wb_read(BASE_ADDR + 12'h000, read_data);
            // Output pins (0-3): driven by out_reg (0x05)
            // Input pins (4-7): reflect gpio_in (0xF0)
            if (read_data[7:0] !== 8'hF5) begin  // 0xF0 | 0x05 = 0xF5
                $display("ERROR: Mixed I/O read incorrect: expected F5, got %h", read_data);
                error_count++;
            end

            // Verify output enables
            if (gpio_oe !== 8'h0F) begin
                $display("ERROR: Mixed I/O direction incorrect: expected 0F, got %b", gpio_oe);
                error_count++;
            end

            $display("Mixed I/O test completed with %0d errors", error_count);
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