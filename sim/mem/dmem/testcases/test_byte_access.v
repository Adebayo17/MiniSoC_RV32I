task test_byte_access;
    output [31:0] error_count;
    reg [DATA_WIDTH-1:0] current_value, write_data, read_data, expected;
    integer i;
    begin
        error_count = 0;

        // First, clear the memory location
        wb_write(BASE_ADDR, 32'h00000000, 4'b1111);
        wb_read(BASE_ADDR, read_data);
        if (read_data != write_data) begin
            $display("Memory at @%h not cleared properly", BASE_ADDR);
        end else begin
            $display("Memory at @%h cleared", BASE_ADDR);
        end
        
        // Test each byte lane with read-modify-write approach
        for (i = 0; i < 4; i = i + 1) begin
            // First read the current value
            wb_read(BASE_ADDR, current_value);
            
            // Prepare write data - set only the target byte to A5
            write_data = current_value; // Start with current value
            write_data[i*8 +: 8] = 8'hA5; // Modify only the target byte
            
            // Write with byte select - only modify the target byte
            wb_write(BASE_ADDR, write_data, (1 << i));
            
            // Read back to verify
            wb_read(BASE_ADDR, read_data);
            
            // Expected value should be the original with only the target byte changed
            expected = current_value;
            expected[i*8 +: 8] = 8'hA5;
            
            if (read_data !== expected) begin
                $display("ERROR: Byte access failed for byte %0d:", i);
                $display("  Original: %h", current_value);
                $display("  Expected: %h", expected);
                $display("  Got:      %h", read_data);
                error_count = error_count + 1;
            end
        end
        
        // Test reading individual bytes from a known pattern
        $display("\nTesting byte reading from known pattern...");
        
        // Write a known pattern
        wb_write(BASE_ADDR + 4, 32'hAABBCCDD, 4'b1111);
        
        for (i = 0; i < 4; i = i + 1) begin
            // Read back the full word
            wb_read(BASE_ADDR + 4, read_data);
            
            // Extract and verify each byte
            case (i)
                0: expected = 8'hDD;
                1: expected = 8'hCC;
                2: expected = 8'hBB;
                3: expected = 8'hAA;
            endcase
            
            if (read_data[i*8 +: 8] !== expected) begin
                $display("ERROR: Byte read failed for byte %0d: Expected %h, Got %h", 
                        i, expected, read_data[i*8 +: 8]);
                error_count = error_count + 1;
            end
        end
        
        // Additional test: verify that unwritten bytes are preserved
        $display("\nTesting that unwritten bytes are preserved...");
        
        // Write initial pattern
        wb_write(BASE_ADDR + 8, 32'h12345678, 4'b1111);
        
        // Read current value
        wb_read(BASE_ADDR + 8, current_value);
        
        // Modify only byte 1 (keep others unchanged)
        write_data = current_value;
        write_data[15:8] = 8'hAA; // Modify byte 1
        
        wb_write(BASE_ADDR + 8, write_data, 4'b0010); // Only write byte 1
        
        // Read back and verify
        wb_read(BASE_ADDR + 8, read_data);
        
        expected = 32'h1234AA78; // Only byte 1 should change
        
        if (read_data !== expected) begin
            $display("ERROR: Byte preservation failed:");
            $display("  Original: %h", current_value);
            $display("  Expected: %h", expected);
            $display("  Got:      %h", read_data);
            error_count = error_count + 1;
        end
    end
endtask