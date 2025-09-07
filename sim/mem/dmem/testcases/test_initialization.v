task test_initialization;
    output [31:0] error_count;
    reg [DATA_WIDTH-1:0] read_data;
    integer i;
    begin
        error_count = 0;
        
        // Initialize memory with single-cycle pulses
        for (i = 0; i < 8; i = i + 1) begin
            init_write(BASE_ADDR + (i * 4), 32'h12345678 + i);
        end

        // Wait a couple cycles
        @(posedge clk);
        @(posedge clk);

        // Verify initialization
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge clk);
            wb_read(BASE_ADDR + (i * 4), read_data);
            
            if (read_data !== (32'h12345678 + i)) begin
                $display("ERROR: Init failed @%h Exp=%h Got=%h", 
                        BASE_ADDR + (i * 4), 32'h12345678 + i, read_data);
                error_count = error_count + 1;
            end
        end
    end
endtask

// Helper task for initialization writes
task init_write;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    begin
        init_en = 1;
        init_addr = addr;
        init_data = data;
        $display("[INFO]: Testbench Initialization @%h Data=%h", addr, data);
        
        // Wait for the clock edge to ensure memory captures the values
        @(posedge clk);
        
        // Keep signals stable for a small delay after clock edge
        #1;

        // The deassert
        init_en = 0;
        init_addr = 0;
        init_data = 0;
        
        // Wait a bit before next initialization
        #(CLK_PERIOD/4);
    end
endtask