`timescale 1ns/1ps

module tb_wishbone_interconnect;
    // Parameters
    parameter CLK_PERIOD      = 10;  // 100 Mhz
    parameter ADDR_WIDTH      = 32;
    parameter DATA_WIDTH      = 32;
    parameter DMEM_BASE_ADDR  = 32'h1000_0000;
    parameter UART_BASE_ADDR  = 32'h2000_0000;
    parameter TIMER_BASE_ADDR = 32'h3000_0000;
    parameter GPIO_BASE_ADDR  = 32'h4000_0000;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Test Control
    reg [31:0]      test_num;
    reg [8*40:1]    test_name;
    reg [31:0]      task_error_count;
    reg [31:0]      total_errors;
    reg [4:0]       slave_accessed;

    
    // -------------------------------------------
    // Wires and Reg
    // -------------------------------------------

    // Master interface (from CPU)
    wire                      wb_m_cpu_cyc;
    wire                      wb_m_cpu_stb;
    wire                      wb_m_cpu_we;
    wire [ADDR_WIDTH-1:0]     wb_m_cpu_addr;
    wire [DATA_WIDTH-1:0]     wb_m_cpu_data_write;
    wire [3:0]                wb_m_cpu_sel;
    wire [DATA_WIDTH-1:0]     wb_m_cpu_data_read;
    wire                      wb_m_cpu_ack;
    // Slave 1: DMEM
    wire                      wb_s1_dmem_cyc;
    wire                      wb_s1_dmem_stb;
    wire                      wb_s1_dmem_we;
    wire [ADDR_WIDTH-1:0]     wb_s1_dmem_addr;
    wire [DATA_WIDTH-1:0]     wb_s1_dmem_data_write;
    wire [3:0]                wb_s1_dmem_sel;
    wire [DATA_WIDTH-1:0]     wb_s1_dmem_data_read;
    wire                      wb_s1_dmem_ack;
    // Slave 2: UART
    wire                      wb_s2_uart_cyc;
    wire                      wb_s2_uart_stb;
    wire                      wb_s2_uart_we;
    wire  [ADDR_WIDTH-1:0]    wb_s2_uart_addr;
    wire  [DATA_WIDTH-1:0]    wb_s2_uart_data_write;
    wire  [3:0]               wb_s2_uart_sel;
    wire  [DATA_WIDTH-1:0]    wb_s2_uart_data_read;
    wire                      wb_s2_uart_ack;
    // Slave 3: TIMER
    wire                      wb_s3_timer_cyc;
    wire                      wb_s3_timer_stb;
    wire                      wb_s3_timer_we;
    wire [ADDR_WIDTH-1:0]     wb_s3_timer_addr;
    wire [DATA_WIDTH-1:0]     wb_s3_timer_data_write;
    wire [3:0]                wb_s3_timer_sel;
    wire [DATA_WIDTH-1:0]     wb_s3_timer_data_read;
    wire                      wb_s3_timer_ack;
    // Slave 4: GPIO
    wire                      wb_s4_gpio_cyc;
    wire                      wb_s4_gpio_stb;
    wire                      wb_s4_gpio_we;
    wire [ADDR_WIDTH-1:0]     wb_s4_gpio_addr;
    wire [DATA_WIDTH-1:0]     wb_s4_gpio_data_write;
    wire [3:0]                wb_s4_gpio_sel;
    wire [DATA_WIDTH-1:0]     wb_s4_gpio_data_read;
    wire                      wb_s4_gpio_ack;


    // -------------------------------------------
    // Instantiate DUT
    // -------------------------------------------

    wishbone_interconnect #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk                     (clk                     ),
        .rst_n                   (rst_n                   ),
        .wbm_cpu_cyc            (wb_m_cpu_cyc            ),
        .wbm_cpu_stb            (wb_m_cpu_stb            ),
        .wbm_cpu_we             (wb_m_cpu_we             ),
        .wbm_cpu_addr           (wb_m_cpu_addr           ),
        .wbm_cpu_data_write     (wb_m_cpu_data_write     ),
        .wbm_cpu_sel            (wb_m_cpu_sel            ),
        .wbm_cpu_data_read      (wb_m_cpu_data_read      ),
        .wbm_cpu_ack            (wb_m_cpu_ack            ),
        .wbs_dmem_cyc           (wb_s1_dmem_cyc          ),
        .wbs_dmem_stb           (wb_s1_dmem_stb          ),
        .wbs_dmem_we            (wb_s1_dmem_we           ),
        .wbs_dmem_addr          (wb_s1_dmem_addr         ),
        .wbs_dmem_data_write    (wb_s1_dmem_data_write   ),
        .wbs_dmem_sel           (wb_s1_dmem_sel          ),
        .wbs_dmem_data_read     (wb_s1_dmem_data_read    ),
        .wbs_dmem_ack           (wb_s1_dmem_ack          ),
        .wbs_uart_cyc           (wb_s2_uart_cyc          ),
        .wbs_uart_stb           (wb_s2_uart_stb          ),
        .wbs_uart_we            (wb_s2_uart_we           ),
        .wbs_uart_addr          (wb_s2_uart_addr         ),
        .wbs_uart_data_write    (wb_s2_uart_data_write   ),
        .wbs_uart_sel           (wb_s2_uart_sel          ),
        .wbs_uart_data_read     (wb_s2_uart_data_read    ),
        .wbs_uart_ack           (wb_s2_uart_ack          ),
        .wbs_timer_cyc          (wb_s3_timer_cyc         ),
        .wbs_timer_stb          (wb_s3_timer_stb         ),
        .wbs_timer_we           (wb_s3_timer_we          ),
        .wbs_timer_addr         (wb_s3_timer_addr        ),
        .wbs_timer_data_write   (wb_s3_timer_data_write  ),
        .wbs_timer_sel          (wb_s3_timer_sel         ),
        .wbs_timer_data_read    (wb_s3_timer_data_read   ),
        .wbs_timer_ack          (wb_s3_timer_ack         ),
        .wbs_gpio_cyc           (wb_s4_gpio_cyc          ),
        .wbs_gpio_stb           (wb_s4_gpio_stb          ),
        .wbs_gpio_we            (wb_s4_gpio_we           ),
        .wbs_gpio_addr          (wb_s4_gpio_addr         ),
        .wbs_gpio_data_write    (wb_s4_gpio_data_write   ),
        .wbs_gpio_sel           (wb_s4_gpio_sel          ),
        .wbs_gpio_data_read     (wb_s4_gpio_data_read    ),
        .wbs_gpio_ack           (wb_s4_gpio_ack          )
    );

    // -------------------------------------------
    // Instantiate Master and Slave Model (CPU simulator)
    // -------------------------------------------

    wb_master_model #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) cpu_master (
        .clk                     (clk                     ),
        .rst_n                   (rst_n                   ),
        .wb_cyc_o                (wb_m_cpu_cyc            ),
        .wb_stb_o                (wb_m_cpu_stb            ),
        .wb_we_o                 (wb_m_cpu_we             ),
        .wb_addr_o               (wb_m_cpu_addr           ),
        .wb_data_o               (wb_m_cpu_data_write     ),
        .wb_sel_o                (wb_m_cpu_sel            ),
        .wb_data_i               (wb_m_cpu_data_read      ),
        .wb_ack_i                (wb_m_cpu_ack            ) 
    );

    wb_slave_model #(
        .SLAVE_ID(1),
        .BASE_ADDR(DMEM_BASE_ADDR),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dmem_slave (
        .clk                     (clk                     ),
        .rst_n                   (rst_n                   ),
        .wb_cyc_i                (wb_s1_dmem_cyc          ),
        .wb_stb_i                (wb_s1_dmem_stb          ),
        .wb_we_i                 (wb_s1_dmem_we           ),
        .wb_addr_i               (wb_s1_dmem_addr         ),
        .wb_data_i               (wb_s1_dmem_data_write   ),
        .wb_sel_i                (wb_s1_dmem_sel          ),
        .wb_data_o               (wb_s1_dmem_data_read    ),
        .wb_ack_o                (wb_s1_dmem_ack          ) 
    );

    wb_slave_model #(
        .SLAVE_ID(2),
        .BASE_ADDR(UART_BASE_ADDR),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) uart_slave (
        .clk                     (clk                     ),
        .rst_n                   (rst_n                   ),
        .wb_cyc_i                (wb_s2_uart_cyc          ),
        .wb_stb_i                (wb_s2_uart_stb          ),
        .wb_we_i                 (wb_s2_uart_we           ),
        .wb_addr_i               (wb_s2_uart_addr         ),
        .wb_data_i               (wb_s2_uart_data_write   ),
        .wb_sel_i                (wb_s2_uart_sel          ),
        .wb_data_o               (wb_s2_uart_data_read    ),
        .wb_ack_o                (wb_s2_uart_ack          ) 
    );

    wb_slave_model #(
        .SLAVE_ID(3),
        .BASE_ADDR(TIMER_BASE_ADDR),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) timer_slave (
        .clk                     (clk                     ),
        .rst_n                   (rst_n                   ),
        .wb_cyc_i                (wb_s3_timer_cyc         ),
        .wb_stb_i                (wb_s3_timer_stb         ),
        .wb_we_i                 (wb_s3_timer_we          ),
        .wb_addr_i               (wb_s3_timer_addr        ),
        .wb_data_i               (wb_s3_timer_data_write  ),
        .wb_sel_i                (wb_s3_timer_sel         ),
        .wb_data_o               (wb_s3_timer_data_read   ),
        .wb_ack_o                (wb_s3_timer_ack         ) 
    );

    wb_slave_model #(
        .SLAVE_ID(4),
        .BASE_ADDR(GPIO_BASE_ADDR),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) gpio_slave (
        .clk                     (clk                     ),
        .rst_n                   (rst_n                   ),
        .wb_cyc_i                (wb_s4_gpio_cyc          ),
        .wb_stb_i                (wb_s4_gpio_stb          ),
        .wb_we_i                 (wb_s4_gpio_we           ),
        .wb_addr_i               (wb_s4_gpio_addr         ),
        .wb_data_i               (wb_s4_gpio_data_write   ),
        .wb_sel_i                (wb_s4_gpio_sel          ),
        .wb_data_o               (wb_s4_gpio_data_read    ),
        .wb_ack_o                (wb_s4_gpio_ack          ) 
    );


    // -------------------------------------------
    // Clock and Reset Generation
    // -------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        rst_n = 0;
        #100 rst_n = 1;
    end


    // -------------------------------------------
    // Main Test Sequence
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_accessed <= 5'b0;
        end else begin
            // Only update when a transfer is happening
            if (wb_m_cpu_cyc && wb_m_cpu_stb) begin
                slave_accessed <= {
                    (wb_s1_dmem_cyc  && wb_s1_dmem_stb ),
                    (wb_s2_uart_cyc  && wb_s2_uart_stb ),
                    (wb_s3_timer_cyc && wb_s3_timer_stb),
                    (wb_s4_gpio_cyc  && wb_s4_gpio_stb )
                };
            end else begin
                slave_accessed <= 5'b0;
            end
        end
    end 


    initial begin
        // Open waveform file
        $dumpfile("wishbone_interconnect_tb.vcd");
        $dumpvars(0, tb_wishbone_interconnect);

        total_errors = 0;
        task_error_count  = 0;

        // Wait for reset to complete
        @(posedge rst_n);
        #(CLK_PERIOD*2);

        // Run test cases
        $display("\n[TESTBENCH WISHBONE_INTERCONNECT][TEST 1] ADDRESS DECODING: Starting");
        test_num = 1;
        test_name = "Address Decoding";
        // test_address_decoding(task_error_count);
        // total_errors = total_errors + task_error_count;
        $display("\n[TESTBENCH WISHBONE_INTERCONNECT][TEST 1] ADDRESS DECODING: Completed");

        $display("\n[TESTBENCH WISHBONE_INTERCONNECT][TEST 2] DATA PATH: Starting");
        test_num = 2;
        test_name = "Data path";
        // test_data_path(task_error_count);
        // total_errors = total_errors + task_error_count;
        $display("\n[TESTBENCH WISHBONE_INTERCONNECT][TEST 2] DATA PATH: Completed");

        $display("\n[TESTBENCH WISHBONE_INTERCONNECT][TEST 3] PROTOCOL: Starting");
        test_num = 3;
        test_name = "Protocol";
        test_protocol(task_error_count);
        total_errors = total_errors + task_error_count;
        $display("\n[TESTBENCH WISHBONE_INTERCONNECT][TEST 3] PROTOCOL: Completed");

        // Summary
        $display("\nTestbench completed with %0d total errors", total_errors);
        $finish;
    end


    // -------------------------------------------
    // Test Addres Decoding
    // -------------------------------------------

    task test_address_decoding;
        output [31:0] error_count;
        reg [8*40:1] test_name;
        reg [31:0] tmp_cnt;
        begin
            test_name = "Address Decoding Test";
            $display("[%s] Starting test", test_name);
            error_count = 0;
            tmp_cnt = 0;

            // Test each slave's address range
            test_slave_access(32'h1000_0100, "DMEM",  1, tmp_cnt);
            error_count = error_count + tmp_cnt;
            #(CLK_PERIOD*2);

            test_slave_access(32'h2000_0100, "UART",  2, tmp_cnt);
            error_count = error_count + tmp_cnt;
            #(CLK_PERIOD*2);

            test_slave_access(32'h3000_0100, "TIMER", 3, tmp_cnt);
            error_count = error_count + tmp_cnt;
            #(CLK_PERIOD*2);

            test_slave_access(32'h4000_0100, "GPIO",  4, tmp_cnt);
            error_count = error_count + tmp_cnt;
            #(CLK_PERIOD*2);

            // Test invalid address
            test_invalid_address(32'h5000_0000, tmp_cnt);
            error_count = error_count + tmp_cnt;

            $display("[%s] Completed with %0d errors", test_name, error_count);
        end
    endtask

    task test_slave_access;
        input  [ADDR_WIDTH-1:0] addr;
        input  [8*8:1]          slave_name;   // 8-character name
        input  [31:0]           slave_id;
        output [31:0]           err_cnt;

        reg    [DATA_WIDTH-1:0] write_data;
        reg    [DATA_WIDTH-1:0] read_data;
        integer                 i;
        begin
            err_cnt = 0;

            write_data = 32'hA5A5_A5A5 + slave_id;

            // Write to the address
            cpu_master.wb_write(addr, write_data);

            // Read from address
            cpu_master.wb_read(addr, read_data);

            if (read_data != write_data) begin
                $display("ERROR: %s (slave %0d) data mismatch at addr %h. Wrote %h, Read %h", slave_name, slave_id, addr, write_data, read_data);
                err_cnt = err_cnt + 1;
            end

            // Clear for next test
            #(CLK_PERIOD);
        end
    endtask


    task test_invalid_address;
        input  [ADDR_WIDTH-1:0] addr;
        output [31:0]           err_cnt;
        reg    [DATA_WIDTH-1:0] read_data;
        integer                 i;
        begin
            err_cnt = 0;

            cpu_master.wb_write(addr, 32'hDEAD_BEEF);
            #(CLK_PERIOD*2);
            
            // Verification code...
            if (slave_accessed != 5'b0) begin
                $display("ERROR: Slaves incorrectly accessed for invalid address %h", addr);
                err_cnt = err_cnt + 1;
            end
            
            cpu_master.wb_read(addr, read_data);
            #(CLK_PERIOD*2);
            if (read_data !== 32'hDEAD_DEAD) begin
                $display("ERROR: Invalid address read returned %h, expected DEAD_DEAD",
                        read_data);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    // -------------------------------------------
    // Test Data Path
    // -------------------------------------------

    task test_data_path;
        output [31:0] error_count;
        reg [8*40:1] test_name;
        reg [31:0] test_data;
        reg [31:0] tmp_cnt;
        integer i;
        begin
            test_name = "Data Path Verification";
            $display("[%s] Starting test", test_name);

            error_count = 0;
            tmp_cnt = 0;
            test_data = 0;

            // -------------------------------------------
            // Test 1: Basic Word Write/Read
            // -------------------------------------------
            $display("\n[Test 1] Basic 32-bit word access");

            // Test pattern: Walking ones
            for (i = 0; i < 32; i = i+1) begin
                test_data = (32'b1 << i);

                // Test each slave
                verify_data_transfer(32'h1000_0100 + (i << 2), test_data, "DMEM",  1, tmp_cnt); error_count = error_count + tmp_cnt;
                verify_data_transfer(32'h2000_0100 + (i << 2), test_data, "UART",  2, tmp_cnt); error_count = error_count + tmp_cnt;
                verify_data_transfer(32'h3000_0100 + (i << 2), test_data, "TIMER", 3, tmp_cnt); error_count = error_count + tmp_cnt;
                verify_data_transfer(32'h4000_0100 + (i << 2), test_data, "GPIO",  4, tmp_cnt); error_count = error_count + tmp_cnt;
            end

            // -------------------------------------------
            // Test 2: Byte Access
            // -------------------------------------------
            $display("\n[Test 2] Byte access tests");

            // Test each byte lane
            for (i = 0; i < 4; i = i+1) begin
                test_data = (8'hA5 << (i*8));

                // Test with byte select
                verify_byte_access(32'h1000_0200 + i, test_data, 1 << i, "DMEM",  1, tmp_cnt); error_count = error_count + tmp_cnt;
                verify_byte_access(32'h2000_0200 + i, test_data, 1 << i, "UART",  2, tmp_cnt); error_count = error_count + tmp_cnt;
            end

            $display("[%s] Completed with %0d errors", test_name, error_count);
        end
    endtask

    task verify_data_transfer;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [8*8:1] slave_name;
        input [31:0] slave_id;
        output [31:0] err_cnt;
        reg [DATA_WIDTH-1:0] read_data;
        begin
            read_data = 0;
            err_cnt = 0;

            // Full word write/read
            cpu_master.wb_write(addr, data);
            #(CLK_PERIOD*4);
            cpu_master.wb_read(addr, read_data);

            if (read_data != data) begin
                $display("ERROR: %s data mismatch @ %h: Wrote %h, Read %h", slave_name, addr, data, read_data);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    task verify_byte_access;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0] data;
        input [3:0] sel;
        input [8*8:1] slave_name;
        input [31:0] slave_id;
        output [31:0] err_cnt;
        reg [DATA_WIDTH-1:0] write_data, read_data, expected;
        begin
            write_data = 0;
            read_data  = 0;
            expected   = 0;
            err_cnt    = 0;

            // Create masked write data
            write_data = {data + 8'h03, data + 8'h02, data + 8'h01, data}; // Replicate byte to all positions
            
            // Write with byte select
            cpu_master.wb_write_sel(addr, write_data, sel);
            #(CLK_PERIOD*4);

            // Read back full word
            cpu_master.wb_read_sel(addr, sel, read_data); // World-aligned read
            #(CLK_PERIOD*4);

            // Create expected result
            if (sel[0]) expected[7:0]   = data;
            if (sel[1]) expected[15:8]  = data + 8'h01;
            if (sel[2]) expected[23:16] = data + 8'h02;
            if (sel[3]) expected[31:24] = data + 8'h03;

            if (read_data != expected) begin
                $display("ERROR: %s byte access failed @ %h (sel=%b): Expected %h, Got %h", slave_name, addr, sel, expected, read_data);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    // -------------------------------------------
    // Test Protocol
    // -------------------------------------------

    task test_protocol;
        output [31:0] error_count;
        reg [8*40:1] test_name;
        reg [31:0] test_data;
        reg [31:0] tmp_cnt;
        integer i;
        begin
            test_name = "Protocol Compliance Test";
            $display("[%s] Starting test", test_name);
            error_count = 0;
            tmp_cnt = 0;

            // -------------------------------------------
            // Test 1: Basic Single Read/Write Cycle
            // -------------------------------------------
            $display("\n[Test 1] Basic single transfer");
        
            
            // Verify CYC/STB/ACK timing for read
            verify_single_transfer(32'h10000100, 32'h0, "DMEM", tmp_cnt);
            error_count = error_count + tmp_cnt;

            // -------------------------------------------
            // Test 2: Consecutive Transfers
            // -------------------------------------------
            $display("\n[Test 2] Consecutive transfers");
            verify_consecutive_transfers(tmp_cnt);
            error_count = error_count + tmp_cnt;

            // -------------------------------------------
            // Test 3: Error Conditions
            // -------------------------------------------
            $display("\n[Test 3] Error conditions");
            verify_error_conditions(tmp_cnt);
            error_count = error_count + tmp_cnt;

            // -------------------------------------------
            // Test 4: SEL Signal Verification
            // -------------------------------------------
            $display("\n[Test 4] SEL signal verification");
            verify_sel_signals(tmp_cnt);
            error_count = error_count + tmp_cnt;

            $display("[%s] Completed with %0d errors", test_name, error_count);
        end
    endtask


    task verify_single_transfer;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [8*8:1] slave_name;
        output [31:0] err_cnt;
        reg [DATA_WIDTH-1:0] read_data;
        begin
            err_cnt = 0;
            read_data = 0;

            // Write test
            cpu_master.wb_write(addr, data);
            
            // Verify protocol signals
            if (!check_cyc_stb_timing(addr, 1)) begin
                $display("ERROR: %s write protocol violation", slave_name);
                err_cnt = err_cnt + 1;
            end
            
            // Read test
            cpu_master.wb_read(addr, read_data);
            
            // Verify protocol signals
            if (!check_cyc_stb_timing(addr, 0)) begin
                $display("ERROR: %s read protocol violation", slave_name);
                err_cnt = err_cnt + 1;
            end
            
            // Verify data
            if (read_data !== data) begin
                $display("ERROR: %s data mismatch", slave_name);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    task verify_consecutive_transfers;
        output [31:0] err_cnt;
        reg [DATA_WIDTH-1:0] data [0:3];
        reg [DATA_WIDTH-1:0] read_data;
        integer i;
        begin
            err_cnt = 0;
            read_data = 0;

            // Initialize test data
            data[0] = 32'hA5A5A5A5;
            data[1] = 32'h5A5A5A5A;
            data[2] = 32'h12345678;
            data[3] = 32'h87654321;
            
            // Burst write
            for (i = 0; i < 4; i = i + 1) begin
                cpu_master.wb_write(32'h20000000 + (i << 2), data[i]);
            end
            
            // Burst read
            for (i = 0; i < 4; i = i + 1) begin
                cpu_master.wb_read(32'h20000000 + (i << 2), read_data);
                if (read_data !== data[i]) begin
                    $display("ERROR: Consecutive transfer data mismatch @ %0d", i);
                    err_cnt = err_cnt + 1;
                end
            end
        end
    endtask

    task verify_error_conditions;
        output [31:0] err_cnt;
        reg [DATA_WIDTH-1:0] read_data;
        begin
            err_cnt = 0;

            // Test 1: Non-responding address
            cpu_master.wb_write(32'h50000000, 32'hDEADBEEF);
            #(CLK_PERIOD*10); // Wait longer than normal
            if (wb_m_cpu_ack) begin
                $display("ERROR: Unexpected ACK for invalid address");
                err_cnt = err_cnt + 1;
            end
            
            // Test 2: Unaligned access
            cpu_master.wb_write(32'h10000001, 32'h12345678);
            if (wb_m_cpu_ack) begin
                $display("ERROR: Unexpected ACK for unaligned address");
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    task verify_sel_signals;
        output [31:0] err_cnt;
        reg [31:0] read_data;
        begin
            err_cnt = 0;
            read_data = 0;

            // Test individual byte lanes
            cpu_master.wb_write_sel(32'h30000000, 4'b0001, 32'hA5A5A5A5);
            cpu_master.wb_read(32'h30000000, read_data);
            if (read_data[7:0] !== 8'hA5 || read_data[31:8] !== 24'h0) begin
                $display("ERROR: SEL[0] failed");
                err_cnt = err_cnt + 1;
            end
            
            // Test half-word
            cpu_master.wb_write_sel(32'h30000004, 4'b0011, 32'h12345678);
            cpu_master.wb_read(32'h30000004, read_data);
            if (read_data[15:0] !== 16'h5678 || read_data[31:16] !== 16'h0) begin
                $display("ERROR: SEL[1:0] failed");
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    // Protocol checker function
    function check_cyc_stb_timing;
        input [ADDR_WIDTH-1:0] addr;
        input is_write;
        reg error;
        begin
            error = 0;
            
            // Check CYC asserted before STB
            if (wb_m_cpu_stb && !wb_m_cpu_cyc) begin
                $display("ERROR: STB asserted without CYC");
                error = 1;
            end
            
            // Check WE signal matches operation
            if (is_write && !wb_m_cpu_we) begin
                $display("ERROR: WE not asserted for write");
                error = 1;
            end
            if (!is_write && wb_m_cpu_we) begin
                $display("ERROR: WE asserted for read");
                error = 1;
            end
            
            // Check ACK comes after STB
            if (wb_m_cpu_ack && !wb_m_cpu_stb) begin
                $display("ERROR: ACK without STB");
                error = 1;
            end
            
            check_cyc_stb_timing = !error;
        end
    endfunction

    
endmodule