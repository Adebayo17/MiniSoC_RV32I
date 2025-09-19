# CPU Simulation Makefile

# -------------------------------------------
# Configuration
# -------------------------------------------
CPU_SIM_DIR 		:= $(SIM_DIR)/cpu
CPU_SRC_DIR 		:= $(TOP_DIR)/src/cpu
CPU_SIM_BUILD_DIR 	:= $(SIM_BUILD_DIR)/cpu


# -------------------------------------------
# Source Files
# -------------------------------------------
CPU_SOURCES := \
	$(CPU_SRC_DIR)/alu.v \
	$(CPU_SRC_DIR)/regfile.v \
	$(CPU_SRC_DIR)/control_unit.v \
	$(CPU_SRC_DIR)/forward_unit.v \
	$(CPU_SRC_DIR)/hazard_unit.v \
	$(CPU_SRC_DIR)/fetch_stage.v \
	$(CPU_SRC_DIR)/decode_stage.v \
	$(CPU_SRC_DIR)/execute_stage.v \
	$(CPU_SRC_DIR)/mem_stage.v \
	$(CPU_SRC_DIR)/wb_stage.v \
	$(CPU_SRC_DIR)/cpu.v


CPU_TB := $(CPU_SIM_DIR)/tb_cpu.v

# -------------------------------------------
# Targets
# -------------------------------------------
.PHONY: sim.cpu sim.cpu.run sim.cpu.wave sim.cpu.clean

sim.cpu: $(CPU_SIM_BUILD_DIR)/cpu_tb.out

# Build
$(CPU_SIM_BUILD_DIR)/cpu_tb.out: $(IMEM_SOURCES) $(DMEM_SOURCES) $(MEM_INIT_SOURCES) $(CPU_SOURCES) $(CPU_TB)
	@echo "$(CPU_SIM_DIR)"
	@mkdir -p $(CPU_SIM_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(CPU_SRC_DIR) $^
	@echo "[CPU] Testbench built: $@"
	@echo ""

# Run
sim.cpu.run: $(CPU_SIM_BUILD_DIR)/cpu_tb.out
	@echo "\n[RV32I_CORE] Running tests..."
	@cd $(CPU_SIM_BUILD_DIR) && $(VVP) cpu_tb.out -l cpu.log
	@echo "[CPU] Test completed - see $(CPU_SIM_BUILD_DIR)/cpu.log"
	@echo ""

# Wave
sim.cpu.wave:
	$(GTKWAVE) $(CPU_SIM_BUILD_DIR)/cpu_tb.vcd &

# Clean
sim.cpu.clean:
	rm -rf $(CPU_SIM_BUILD_DIR)
	rm -rf *.vcd *.log


# -------------------------------------------
# Shortcuts
# -------------------------------------------
cpu: sim.cpu
cpu-run: sim.cpu.run
cpu-wave: sim.cpu.wave
cpu-clean: sim.cpu.clean