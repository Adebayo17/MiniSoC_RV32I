`timescale 1ns/1ps

module tb_io_pad;
    // Testbench parameters
    parameter CLK_PERIOD = 10; // 100MHz
    
    // Digital core interface
    reg         pad_in;
    wire        pad_out;
    reg         pad_oe;
    
    // Physical pad interface  
    wire        pad_io;
    
    // Testbench signals
    reg         external_drive;
    reg         external_value;
    
    // Instantiate DUT
    io_pad dut (
        .pad_in(pad_in),
        .pad_out(pad_out),
        .pad_oe(pad_oe),
        .pad_io(pad_io)
    );
    
    // Bidirectional pad modeling
    assign pad_io = (external_drive) ? external_value : 1'bz;
    
    // Clock generation (not strictly needed for pad test, but useful for timing)
    reg clk;
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Main test sequence
    initial begin
        $dumpfile("io_pad_tb.vcd");
        $dumpvars(0, tb_io_pad);
        
        $display("=== IO Pad Testbench Started ===");
        
        // Initialize signals
        pad_in = 0;
        pad_oe = 0;
        external_drive = 0;
        external_value = 0;
        
        #100;
        
        // Test 1: Output mode (pad_oe = 1)
        $display("\n[TEST 1] Output Mode Testing");
        test_output_mode();
        
        // Test 2: Input mode (pad_oe = 0)  
        $display("\n[TEST 2] Input Mode Testing");
        test_input_mode();
        
        // Test 3: Output enable switching
        $display("\n[TEST 3] Output Enable Switching");
        test_oe_switching();
        
        // Test 4: Conflict detection (both driving)
        $display("\n[TEST 4] High-Z Behavior");
        test_high_z_behavior();
        
        // Test 5: High-Z behavior
        $display("\n[TEST 5] Basic Functionality");
        test_basic_functionality();
        
        $display("\n=== IO Pad Testbench Completed ===");
        $finish;
    end
    
    // -------------------------------------------
    // Test Tasks
    // -------------------------------------------
    
    task test_output_mode;
        begin
            pad_oe = 1; // Enable output
            
            // Test driving high
            pad_in = 1;
            #20;
            if (pad_io === 1'b1) 
                $display("✅ Output HIGH: pad_io = %b (expected 1)", pad_io);
            else
                $display("❌ Output HIGH: pad_io = %b (expected 1)", pad_io);
            
            // Test driving low  
            pad_in = 0;
            #20;
            if (pad_io === 1'b0)
                $display("✅ Output LOW: pad_io = %b (expected 0)", pad_io);
            else
                $display("❌ Output LOW: pad_io = %b (expected 0)", pad_io);
                
            // Test pad_out should follow pad_io in output mode
            if (pad_out === pad_io)
                $display("✅ pad_out follows pad_io in output mode");
            else
                $display("❌ pad_out should follow pad_io in output mode");
        end
    endtask
    
    task test_input_mode;
        begin
            pad_oe = 0; // Disable output (input mode)
            
            // External drive high
            external_drive = 1;
            external_value = 1;
            #20;
            if (pad_out === 1'b1 && pad_io === 1'b1)
                $display("✅ Input HIGH: pad_out = %b, pad_io = %b", pad_out, pad_io);
            else
                $display("❌ Input HIGH: pad_out = %b, pad_io = %b", pad_out, pad_io);
            
            // External drive low
            external_value = 0;
            #20;
            if (pad_out === 1'b0 && pad_io === 1'b0)
                $display("✅ Input LOW: pad_out = %b, pad_io = %b", pad_out, pad_io);
            else
                $display("❌ Input LOW: pad_out = %b, pad_io = %b", pad_out, pad_io);
        end
    endtask
    
    task test_oe_switching;
        begin
            // Start in input mode with external drive
            pad_oe = 0;
            external_drive = 1;
            external_value = 1;
            #20;
            
            // Switch to output mode
            external_drive = 0;
            pad_oe = 1;
            pad_in = 0; // Drive low
            #20;
            if (pad_io === 1'b0)
                $display("✅ OE switch: Output mode takes precedence");
            else
                $display("❌ OE switch: pad_io = %b (expected 0)", pad_io);
                
            // Switch back to input mode
            pad_oe = 0;
            external_drive = 1;
            external_value = 1;
            #20;
            if (pad_io === 1'b1) // Should return to external value
                $display("✅ OE switch: Back to input mode");
            else
                $display("❌ OE switch: pad_io = %b (expected 1)", pad_io);
        end
    endtask
    
    
    task test_high_z_behavior;
        begin
            // No one driving - should be high-Z
            pad_oe = 0;
            external_drive = 0;
            
            #20;
            if (pad_io === 1'bz)
                $display("✅ High-Z: pad_io = %b (expected z)", pad_io);
            else
                $display("❌ High-Z: pad_io = %b (expected z)", pad_io);
                
            // pad_out should also be high-Z (or undefined)
            $display("Note: pad_out = %b in High-Z mode", pad_out);
        end
    endtask

    task test_basic_functionality;
        begin
            // Test that pad_out always follows pad_io
            pad_oe = 1;
            pad_in = 1;
            external_drive = 0;
            #20;
            
            if (pad_out === pad_io && pad_io === 1'b1)
                $display("✅ pad_out follows pad_io (HIGH)");
            else
                $display("❌ pad_out should follow pad_io");
                
            pad_in = 0;
            #20;
            
            if (pad_out === pad_io && pad_io === 1'b0)
                $display("✅ pad_out follows pad_io (LOW)");
            else
                $display("❌ pad_out should follow pad_io");
        end
    endtask
    
    // -------------------------------------------
    // Monitoring and Assertions
    // -------------------------------------------
    
    // Monitor pad behavior
    always @(posedge clk) begin
        $display("Time %0t: pad_oe=%b, pad_in=%b, pad_out=%b, pad_io=%b, ext_drive=%b, ext_val=%b",
                $time, pad_oe, pad_in, pad_out, pad_io, external_drive, external_value);
    end
    
    // Basic assertions
    always @(*) begin
        // When in output mode, pad_io should equal pad_in
        if (pad_oe === 1'b1) begin
            #1; // Small delay to avoid race conditions
            if (pad_io !== pad_in && pad_io !== 1'bz) begin
                $display("ASSERTION FAILED: Output mode - pad_io should equal pad_in");
                $display("  pad_oe=%b, pad_in=%b, pad_io=%b", pad_oe, pad_in, pad_io);
            end
        end
        
        // pad_out should always equal pad_io
        #1; // Small delay
        if (pad_out !== pad_io) begin
            $display("ASSERTION FAILED: pad_out should always equal pad_io");
            $display("  pad_out=%b, pad_io=%b", pad_out, pad_io);
        end
    end
    
    // -------------------------------------------
    // Timing Tests
    // -------------------------------------------
    
    // Test propagation delays (if specified in your technology library)
    initial begin
        #500;
        $display("\n[Timing Test] Checking basic timing behavior...");
        
        // Quick timing test
        pad_oe = 1;
        pad_in = 0;
        #5;
        if (pad_io === 1'b0)
            $display("✅ Immediate response to input change");
        else
            $display("❌ Delay in output response");
    end
    
endmodule