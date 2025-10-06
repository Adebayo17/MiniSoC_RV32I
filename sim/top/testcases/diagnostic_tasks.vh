
task diagnose_cpu_freeze;
    begin
        $display("[DIAG] ===== CPU FREEZE DIAGNOSIS =====");
        $fdisplay(log_file, "[DIAG] ===== CPU FREEZE DIAGNOSIS =====");
        
        // 1. Check CPU reset state
        $display("[DIAG] CPU reset: %b", dut.top_soc_inst.cpu_rst_n);
        $fdisplay(log_file, "[DIAG] CPU reset: %b", dut.top_soc_inst.cpu_rst_n);
        
        // 2. Check memory initialization
        $display("[DIAG] Memory init done: %b", dut.top_soc_inst.init_done);
        $fdisplay(log_file, "[DIAG] Memory init done: %b", dut.top_soc_inst.init_done);
        
        // 3. Check CPU PC
        $display("[DIAG] CPU PC: %h", dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
        $fdisplay(log_file, "[DIAG] CPU PC: %h", dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
        
        // 4. Check if CPU is requesting instructions
        $display("[DIAG] IMEM request - CYC: %b, STB: %b", 
                dut.top_soc_inst.wbs_imem_cyc, dut.top_soc_inst.wbs_imem_stb);
        $fdisplay(log_file, "[DIAG] IMEM request - CYC: %b, STB: %b",
                dut.top_soc_inst.wbs_imem_cyc, dut.top_soc_inst.wbs_imem_stb);
        
        // 5. Check IMEM response
        $display("[DIAG] IMEM response - ACK: %b, DATA: %h", 
                dut.top_soc_inst.wbs_imem_ack, dut.top_soc_inst.wbs_imem_data_read);
        $fdisplay(log_file, "[DIAG] IMEM response - ACK: %b, DATA: %h",
                dut.top_soc_inst.wbs_imem_ack, dut.top_soc_inst.wbs_imem_data_read);
        
        // 6. Check first few IMEM locations
        $display("[DIAG] IMEM[0]: %h", dut.top_soc_inst.imem_inst.imem_inst.mem[0]);
        $display("[DIAG] IMEM[1]: %h", dut.top_soc_inst.imem_inst.imem_inst.mem[1]);
        $fdisplay(log_file, "[DIAG] IMEM[0]: %h", dut.top_soc_inst.imem_inst.imem_inst.mem[0]);
        $fdisplay(log_file, "[DIAG] IMEM[1]: %h", dut.top_soc_inst.imem_inst.imem_inst.mem[1]);
        
        $display("[DIAG] ===== END DIAGNOSIS =====");
        $fdisplay(log_file, "[DIAG] ===== END DIAGNOSIS =====");
    end
endtask

task test_interconnect_basic;
    integer cycles_monitored;
    begin
        $display("[INTERCONNECT_TEST] Testing basic interconnect functionality...");
        $fdisplay(log_file, "[INTERCONNECT_TEST] Testing basic interconnect functionality...");
        
        // Wait a few cycles after reset
        #(CLK_PERIOD * 10);
        
        cycles_monitored = 0;
        
        // Monitor interconnect activity for 1000 cycles
        while (cycles_monitored < 1000) begin
            @(posedge clk);
            cycles_monitored = cycles_monitored + 1;
            
            // Log any Wishbone activity
            if (dut.top_soc_inst.wbs_imem_cyc || dut.top_soc_inst.wbs_dmem_cyc) begin
                $display("[INTERCONNECT] Cycle %0d: IMEM_CYC=%b, DMEM_CYC=%b", 
                        cycles_monitored, 
                        dut.top_soc_inst.wbs_imem_cyc,
                        dut.top_soc_inst.wbs_dmem_cyc);
                $fdisplay(log_file, "[INTERCONNECT] Cycle %0d: IMEM_CYC=%b, DMEM_CYC=%b", 
                        cycles_monitored, 
                        dut.top_soc_inst.wbs_imem_cyc,
                        dut.top_soc_inst.wbs_dmem_cyc);
            end
        end
    end
endtask

task verify_firmware_loaded;
    begin
        $display("[FIRMWARE_VERIFY] Verifying firmware loaded correctly...");
        $fdisplay(log_file, "[FIRMWARE_VERIFY] Verifying firmware loaded correctly...");
        
        // Check first few instructions in IMEM
        $display("[FIRMWARE_VERIFY] IMEM[0] = %h (should be first instruction)", 
                dut.top_soc_inst.imem_inst.imem_inst.mem[0]);
        $display("[FIRMWARE_VERIFY] IMEM[1] = %h", 
                dut.top_soc_inst.imem_inst.imem_inst.mem[1]);
        $display("[FIRMWARE_VERIFY] IMEM[2] = %h", 
                dut.top_soc_inst.imem_inst.imem_inst.mem[2]);
        
        $fdisplay(log_file, "[FIRMWARE_VERIFY] IMEM[0] = %h", 
                dut.top_soc_inst.imem_inst.imem_inst.mem[0]);
        $fdisplay(log_file, "[FIRMWARE_VERIFY] IMEM[1] = %h", 
                dut.top_soc_inst.imem_inst.imem_inst.mem[1]);
        $fdisplay(log_file, "[FIRMWARE_VERIFY] IMEM[2] = %h", 
                dut.top_soc_inst.imem_inst.imem_inst.mem[2]);
        
        // Check if instructions look valid
        if (dut.top_soc_inst.imem_inst.imem_inst.mem[0] === 32'hxxxxxxxx) begin
            $display("[FIRMWARE_VERIFY] ERROR: IMEM[0] is uninitialized!");
            $fdisplay(log_file, "[FIRMWARE_VERIFY] ERROR: IMEM[0] is uninitialized!");
        end else begin
            $display("[FIRMWARE_VERIFY] IMEM appears to be initialized");
            $fdisplay(log_file, "[FIRMWARE_VERIFY] IMEM appears to be initialized");
        end
    end
endtask

task force_cpu_instruction;
    input [31:0] instruction;
    input [31:0] address;
    begin
        $display("[FORCE_TEST] Forcing instruction %h at address %h", instruction, address);
        $fdisplay(log_file, "[FORCE_TEST] Forcing instruction %h at address %h", instruction, address);
        
        // Force a simple instruction to see if CPU executes it
        force dut.top_soc_inst.imem_inst.imem_inst.mem[address[11:2]] = instruction;
        
        // Wait a few cycles
        #(CLK_PERIOD * 20);
        
        // Release the force
        release dut.top_soc_inst.imem_inst.imem_inst.mem[address[11:2]];
        
        $display("[FORCE_TEST] Instruction force released");
        $fdisplay(log_file, "[FORCE_TEST] Instruction force released");
    end
endtask

task test_interconnect_direct;
    begin
        $display("[INTERCONNECT_DIRECT] Direct interconnect test...");
        $fdisplay(log_file, "[INTERCONNECT_DIRECT] Direct interconnect test...");
        
        // Test 1: Check if CPU can read from IMEM at address 0
        $display("[INTERCONNECT_DIRECT] Checking IMEM read path...");
        
        // Monitor the path step by step
        #(CLK_PERIOD * 5);
        
        $display("[INTERCONNECT_DIRECT] CPU PC: %h", 
                dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
        $display("[INTERCONNECT_DIRECT] IMEM request - ADDR: %h, CYC: %b, STB: %b", 
                dut.top_soc_inst.wbs_imem_addr,
                dut.top_soc_inst.wbs_imem_cyc,
                dut.top_soc_inst.wbs_imem_stb);
        $display("[INTERCONNECT_DIRECT] IMEM response - ACK: %b, DATA: %h", 
                dut.top_soc_inst.wbs_imem_ack,
                dut.top_soc_inst.wbs_imem_data_read);
                
        $fdisplay(log_file, "[INTERCONNECT_DIRECT] CPU PC: %h", 
                dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
        $fdisplay(log_file, "[INTERCONNECT_DIRECT] IMEM request - ADDR: %h, CYC: %b, STB: %b", 
                dut.top_soc_inst.wbs_imem_addr,
                dut.top_soc_inst.wbs_imem_cyc,
                dut.top_soc_inst.wbs_imem_stb);
        $fdisplay(log_file, "[INTERCONNECT_DIRECT] IMEM response - ACK: %b, DATA: %h", 
                dut.top_soc_inst.wbs_imem_ack,
                dut.top_soc_inst.wbs_imem_data_read);
    end
endtask