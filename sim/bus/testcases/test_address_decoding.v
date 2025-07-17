// Resume of tasks for Test address decoding
// Included directly in the testbench


`ifndef TEST_ADDRESS_DECODING_V
`define TEST_ADDRESS_DECODING_V


task test_address_decoding;
    output [31:0] error_count;
    reg [8*40:1] test_name;
    begin
        test_name = "Address Decoding Test";
        $display("[%s] Starting test", test_name);
        error_count = 0;

        // Test each slave's address range
        test_slave_access(32'h0000_1000, "IMEM",  0, error_count);
        test_slave_access(32'h1000_1000, "DMEM",  1, error_count);
        test_slave_access(32'h2000_1000, "UART",  2, error_count);
        test_slave_access(32'h3000_1000, "TIMER", 3, error_count);
        test_slave_access(32'h4000_1000, "GPIO",  4, error_count);

        // Test invalid address
        test_invalid_address(32'h5000_0000, error_count);

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
        write_data = 32'hA5A5_A5A5 + slave_id;

        // Write to the address
        cpu_master.wb_write(addr, write_data);

        // Verify correct slave was accessed
        if (!slave_accessed[slave_id]) begin
            $display("ERROR: %s (slave %0d) not accessed at addr %h", slave_name, slave_id, addr);
            err_cnt = err_cnt + 1;
        end

        // Read from address
        //read_data = cpu_master.wb_read(addr);
        cpu_master.wb_read(addr, read_data);

        if (read_data != write_data) begin
            $display("ERROR: %s (slave %0d) data mismatch at addr %h. Wrote %h, Read %h", slave_name, slave_id, addr, write_data, read_data);
            err_cnt = err_cnt + 1;
        end
    end
endtask


task test_invalid_address;
    input  [ADDR_WIDTH-1:0] addr;
    output [31:0]           err_cnt;

    reg    [DATA_WIDTH-1:0] read_data;
    integer                 i;
    begin
        cpu_master.wb_write(addr, 32'hDEAD_BEEF);
        
        // Verification code...
        if (slave_accessed != 5'b0) begin
            $display("ERROR: Slaves incorrectly accessed for invalid address %h", addr);
            err_cnt = err_cnt + 1;
        end
        
        //read_data = cpu_master.wb_read(addr);
        cpu_master.wb_read(addr, read_data);
        if (read_data !== 32'hDEAD_DEAD) begin
            $display("ERROR: Invalid address read returned %h, expected DEAD_DEAD",
                    read_data);
            err_cnt = err_cnt + 1;
        end
    end
endtask

`endif TEST_ADDRESS_DECODING_V