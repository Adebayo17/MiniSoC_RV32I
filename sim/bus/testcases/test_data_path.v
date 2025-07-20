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
            verify_data_transfer(32'h0000_0100 + (i << 2), test_data, "IMEM",  0, tmp_cnt); error_count = error_count + tmp_cnt;
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
            verify_byte_access(32'h0000_0200 + i, test_data, 1 << i, "IMEM",  0, tmp_cnt); error_count = error_count + tmp_cnt;
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
