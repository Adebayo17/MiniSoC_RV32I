`timescale 1ns/1ps

module tb_wishbone_interconnect;
    // Parameters
    parameter CLK_PERIOD      = 10;  // 100 Mhz
    parameter ADDR_WIDTH      = 32;
    parameter DATA_WIDTH      = 32;
    parameter IMEM_BASE_ADDR  = 32'h0000_0000;
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
    // Slave 0: IMEM
    wire                      wb_s0_imem_cyc;
    wire                      wb_s0_imem_stb;
    wire                      wb_s0_imem_we;
    wire [ADDR_WIDTH-1:0]     wb_s0_imem_addr;
    wire [DATA_WIDTH-1:0]     wb_s0_imem_data_write;
    wire [3:0]                wb_s0_imem_sel;
    wire [DATA_WIDTH-1:0]     wb_s0_imem_data_read;
    wire                      wb_s0_imem_ack;
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
        .wb_m_cpu_cyc            (wb_m_cpu_cyc            ),
        .wb_m_cpu_stb            (wb_m_cpu_stb            ),
        .wb_m_cpu_we             (wb_m_cpu_we             ),
        .wb_m_cpu_addr           (wb_m_cpu_addr           ),
        .wb_m_cpu_data_write     (wb_m_cpu_data_write     ),
        .wb_m_cpu_sel            (wb_m_cpu_sel            ),
        .wb_m_cpu_data_read      (wb_m_cpu_data_read      ),
        .wb_m_cpu_ack            (wb_m_cpu_ack            ),
        .wb_s0_imem_cyc          (wb_s0_imem_cyc          ),
        .wb_s0_imem_stb          (wb_s0_imem_stb          ),
        .wb_s0_imem_we           (wb_s0_imem_we           ),
        .wb_s0_imem_addr         (wb_s0_imem_addr         ),
        .wb_s0_imem_data_write   (wb_s0_imem_data_write   ),
        .wb_s0_imem_sel          (wb_s0_imem_sel          ),
        .wb_s0_imem_data_read    (wb_s0_imem_data_read    ),
        .wb_s0_imem_ack          (wb_s0_imem_ack          ),
        .wb_s1_dmem_cyc          (wb_s1_dmem_cyc          ),
        .wb_s1_dmem_stb          (wb_s1_dmem_stb          ),
        .wb_s1_dmem_we           (wb_s1_dmem_we           ),
        .wb_s1_dmem_addr         (wb_s1_dmem_addr         ),
        .wb_s1_dmem_data_write   (wb_s1_dmem_data_write   ),
        .wb_s1_dmem_sel          (wb_s1_dmem_sel          ),
        .wb_s1_dmem_data_read    (wb_s1_dmem_data_read    ),
        .wb_s1_dmem_ack          (wb_s1_dmem_ack          ),
        .wb_s2_uart_cyc          (wb_s2_uart_cyc          ),
        .wb_s2_uart_stb          (wb_s2_uart_stb          ),
        .wb_s2_uart_we           (wb_s2_uart_we           ),
        .wb_s2_uart_addr         (wb_s2_uart_addr         ),
        .wb_s2_uart_data_write   (wb_s2_uart_data_write   ),
        .wb_s2_uart_sel          (wb_s2_uart_sel          ),
        .wb_s2_uart_data_read    (wb_s2_uart_data_read    ),
        .wb_s2_uart_ack          (wb_s2_uart_ack          ),
        .wb_s3_timer_cyc         (wb_s3_timer_cyc         ),
        .wb_s3_timer_stb         (wb_s3_timer_stb         ),
        .wb_s3_timer_we          (wb_s3_timer_we          ),
        .wb_s3_timer_addr        (wb_s3_timer_addr        ),
        .wb_s3_timer_data_write  (wb_s3_timer_data_write  ),
        .wb_s3_timer_sel         (wb_s3_timer_sel         ),
        .wb_s3_timer_data_read   (wb_s3_timer_data_read   ),
        .wb_s3_timer_ack         (wb_s3_timer_ack         ),
        .wb_s4_gpio_cyc          (wb_s4_gpio_cyc          ),
        .wb_s4_gpio_stb          (wb_s4_gpio_stb          ),
        .wb_s4_gpio_we           (wb_s4_gpio_we           ),
        .wb_s4_gpio_addr         (wb_s4_gpio_addr         ),
        .wb_s4_gpio_data_write   (wb_s4_gpio_data_write   ),
        .wb_s4_gpio_sel          (wb_s4_gpio_sel          ),
        .wb_s4_gpio_data_read    (wb_s4_gpio_data_read    ),
        .wb_s4_gpio_ack          (wb_s4_gpio_ack          )
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
        .SLAVE_ID(0),
        .BASE_ADDR(IMEM_BASE_ADDR),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) imem_slave (
        .clk                     (clk                     ),
        .rst_n                   (rst_n                   ),
        .wb_cyc_i                (wb_s0_imem_cyc          ),
        .wb_stb_i                (wb_s0_imem_stb          ),
        .wb_we_i                 (wb_s0_imem_we           ),
        .wb_addr_i               (wb_s0_imem_addr         ),
        .wb_data_i               (wb_s0_imem_data_write   ),
        .wb_sel_i                (wb_s0_imem_sel          ),
        .wb_data_o               (wb_s0_imem_data_read    ),
        .wb_ack_o                (wb_s0_imem_ack          ) 
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
            test_slave_access(32'h0000_0100, "IMEM",  0, tmp_cnt);
            error_count = error_count + tmp_cnt;
            #(CLK_PERIOD*2);

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
    // Main Test Sequence
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_accessed <= 5'b0;
        end else begin
            // Only update when a transfer is happening
            if (wb_m_cpu_cyc && wb_m_cpu_stb) begin
                slave_accessed <= {
                    (wb_s0_imem_cyc  && wb_s0_imem_stb ),
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
        test_address_decoding(task_error_count);
        total_errors = total_errors + task_error_count;
        $display("\n[TESTBENCH WISHBONE_INTERCONNECT][TEST 1] ADDRESS DECODING: Completed");

        // Summary
        $display("\nTestbench completed with %0d total errors", total_errors);
        $finish;
    end
endmodule