task test_basic_rw;
    output [31:0] error_count;
    reg [DATA_WIDTH-1:0] write_data, read_data;
    integer i;
    begin
        error_count = 0;
        for (i = 0; i < 4; i++) begin
            write_data = 32'hA5A5_A5A5 + i;
            wb_write(BASE_ADDR + (i * 4), write_data, 4'b1111);
            wb_read(BASE_ADDR + (i * 4), read_data);
            if (read_data !== write_data) begin
                $display("ERROR: @%h Wrote %h, Read %h", 
                            BASE_ADDR + (i * 4), write_data, read_data);
                error_count++;
            end
        end
    end
endtask