
reg [31:0] flush_count;
reg [31:0] branch_count;
reg [31:0] jump_count;
reg [31:0] return_count;
reg [31:0] instruction_count;
reg [31:0] last_pc;
reg program_completed;
reg [31:0] completion_time;

// Flush detection
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        flush_count <= 0;
        branch_count <= 0;
        jump_count <= 0;
        return_count <= 0;
        instruction_count <= 0;
        last_pc <= 0;
        program_completed <= 0;
        completion_time <= 0;
    end else begin
        // Detect program completion (write to 0x50000000)
        if (dut.top_soc_inst.wbs_dmem_cyc && 
            dut.top_soc_inst.wbs_dmem_we && 
            dut.top_soc_inst.wbs_dmem_addr == 32'h50000000 && 
            !program_completed) begin
            program_completed <= 1;
            completion_time <= cycle_count;
            $display("[PROGRAM_COMPLETION] Program completed at cycle %0d", cycle_count);
            $fdisplay(log_file, "[PROGRAM_COMPLETION] Program completed at cycle %0d", cycle_count);
            $display("[PROGRAM_COMPLETION] Test result: %h", dut.top_soc_inst.wbs_dmem_data_write);
            $fdisplay(log_file, "[PROGRAM_COMPLETION] Test result: %h", dut.top_soc_inst.wbs_dmem_data_write);
        end
        
        // Count instructions (when PC changes)
        if (dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc !== last_pc && 
            dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc !== 32'hxxxxxxxx) begin
            instruction_count <= instruction_count + 1;
        end
        last_pc <= dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc;
        
        // Detect flushes - you'll need to check what signals your CPU exposes
        // These are examples - adjust based on your actual CPU signals
        if (dut.top_soc_inst.rv32i_core.execute_stage_inst.branch_taken) begin
            flush_count <= flush_count + 1;
            branch_count <= branch_count + 1;
            $display("[FLUSH] Branch taken at PC=%h, cycle=%0d", 
                    dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc, cycle_count);
        end
        // Add similar detection for jumps and returns based on your CPU design
    end
end

// Flush analysis task
task analyze_flush_performance;
    real flush_rate;
    real ipc;
    begin
        $display("[FLUSH_ANALYSIS] ===== Pipeline Flush Analysis =====");
        $fdisplay(log_file, "[FLUSH_ANALYSIS] ===== Pipeline Flush Analysis =====");
        
        $display("[FLUSH_ANALYSIS] Total Cycles: %0d", cycle_count);
        $display("[FLUSH_ANALYSIS] Total Instructions: %0d", instruction_count);
        $display("[FLUSH_ANALYSIS] Total Flushes: %0d", flush_count);
        $display("[FLUSH_ANALYSIS]   - Branch flushes: %0d", branch_count);
        $display("[FLUSH_ANALYSIS]   - Jump flushes: %0d", jump_count);
        $display("[FLUSH_ANALYSIS]   - Return flushes: %0d", return_count);
        
        $fdisplay(log_file, "[FLUSH_ANALYSIS] Total Cycles: %0d", cycle_count);
        $fdisplay(log_file, "[FLUSH_ANALYSIS] Total Instructions: %0d", instruction_count);
        $fdisplay(log_file, "[FLUSH_ANALYSIS] Total Flushes: %0d", flush_count);
        $fdisplay(log_file, "[FLUSH_ANALYSIS]   - Branch flushes: %0d", branch_count);
        $fdisplay(log_file, "[FLUSH_ANALYSIS]   - Jump flushes: %0d", jump_count);
        $fdisplay(log_file, "[FLUSH_ANALYSIS]   - Return flushes: %0d", return_count);
        
        if (instruction_count > 0) begin
            flush_rate = (flush_count * 100.0) / instruction_count;
            ipc = instruction_count / (cycle_count * 1.0);
            
            $display("[FLUSH_ANALYSIS] Flush Rate: %.2f%%", flush_rate);
            $display("[FLUSH_ANALYSIS] Instructions Per Cycle: %.3f", ipc);
            
            $fdisplay(log_file, "[FLUSH_ANALYSIS] Flush Rate: %.2f%%", flush_rate);
            $fdisplay(log_file, "[FLUSH_ANALYSIS] Instructions Per Cycle: %.3f", ipc);
        end
        
        $display("[FLUSH_ANALYSIS] ===== End Analysis =====");
        $fdisplay(log_file, "[FLUSH_ANALYSIS] ===== End Analysis =====");
    end
endtask

// Progress monitoring task
task monitor_progress;
    integer last_report_cycle;
    begin
        last_report_cycle = 0;
        
        while (cycle_count < 1000000 && !program_completed) begin
            @(posedge clk);
            
            // Report every 10000 cycles
            if ((cycle_count - last_report_cycle) >= 10000) begin
                $display("[PROGRESS] Cycle %0d: Instructions=%0d, Flushes=%0d, PC=%h",
                        cycle_count, instruction_count, flush_count,
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                $fdisplay(log_file, "[PROGRESS] Cycle %0d: Instructions=%0d, Flushes=%0d, PC=%h",
                        cycle_count, instruction_count, flush_count,
                        dut.top_soc_inst.rv32i_core.fetch_stage_inst.pc);
                last_report_cycle = cycle_count;
            end
        end
    end
endtask