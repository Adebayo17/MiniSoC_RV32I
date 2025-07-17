// Resume of tasks for Test address decoding
// Included directly in the testbench


`ifndef TEST_ADDRESS_DECODING_V
`define TEST_ADDRESS_DECODING_V


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

`endif TEST_ADDRESS_DECODING_V