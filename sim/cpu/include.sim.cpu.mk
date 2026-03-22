# ==============================================================================
# sim/cpu/include.sim.cpu.mk : CPU Simulation Makefile
# ==============================================================================

# -------------------------------------------
# Configuration
# -------------------------------------------
CPU_SIM_DIR         := $(SIM_DIR)/cpu
CPU_SRC_DIR         := $(TOP_DIR)/src/cpu
CPU_SIM_BUILD_DIR   := $(SIM_BUILD_DIR)/cpu

# -------------------------------------------
# Source Files (Auto-discovery)
# -------------------------------------------
CPU_SOURCES := $(wildcard $(CPU_SRC_DIR)/*.v)
CPU_TB      := $(wildcard $(CPU_SIM_DIR)/*.v)

# -------------------------------------------
# Targets
# -------------------------------------------
.PHONY: sim.cpu sim.cpu.run sim.cpu.wave sim.cpu.clean

sim.cpu: $(CPU_SIM_BUILD_DIR)/cpu_tb.out

# Build
# Note: CPU simulation relies on memory modules (IMEM, DMEM) defined in include.sim.mem.mk.
# Because Make flattens the files, $(IMEM_SOURCES) etc. are perfectly valid here!
$(CPU_SIM_BUILD_DIR)/cpu_tb.out: $(IMEM_SOURCES) $(DMEM_SOURCES) $(MEM_INIT_SOURCES) $(CPU_SOURCES) $(CPU_TB)
	@mkdir -p $(dir $@)
	$(Q)echo "  [IVERILOG]  Compiling CPU Testbench"
	$(Q)$(IVERILOG) -o $@ -I$(CPU_SRC_DIR) $^

# Run
sim.cpu.run: sim.cpu
	$(Q)echo "  [VVP]       Running CPU Simulation..."
	$(Q)cd $(CPU_SIM_BUILD_DIR) && $(VVP) cpu_tb.out -l cpu.log
	$(Q)echo "  [SIM-CPU]   Test completed. Log: $(CPU_SIM_BUILD_DIR)/cpu.log"

# Wave
sim.cpu.wave:
	$(Q)echo "  [GTKWAVE]   Opening CPU Waveform"
	$(Q)$(GTKWAVE) $(CPU_SIM_BUILD_DIR)/cpu_tb.vcd &

# Clean
sim.cpu.clean:
	$(Q)echo "  [CLEAN]     CPU Simulation artifacts"
	$(Q)rm -rf $(CPU_SIM_BUILD_DIR)

# -------------------------------------------
# Help
# -------------------------------------------
.PHONY: sim.cpu.help

sim.cpu.help:
	@echo "================================================================================"
	@echo "MiniSoC-RV32I: CPU Makefile Commands"
	@echo "================================================================================"
	@echo "  make sim.cpu               - Build cpu simulation"
	@echo "  make sim.cpu.run           - Run cpu simulation"
	@echo "  make sim.cpu.wave          - Open cpu waveform"
	@echo "  make sim.cpu.clean         - Clean cpu simulation files"
	@echo "  make sim.cpu.help          - Show cpu simulation help"
	@echo ""
	@echo "Shortcuts:"
	@echo "  make cpu                   - Alias for sim.cpu"
	@echo "  make cpu-run               - Alias for sim.cpu.run"
	@echo "  make cpu-wave              - Alias for sim.cpu.wave"
	@echo "  make cpu-clean             - Alias for sim.cpu.clean"
	@echo "  make cpu-help              - Alias for sim.cpu.help"
	@echo "================================================================================"

# -------------------------------------------
# Shortcuts
# -------------------------------------------
.PHONY: cpu cpu-run cpu-wave cpu-clean cpu-help

cpu:        sim.cpu
cpu-run:    sim.cpu.run
cpu-wave:   sim.cpu.wave
cpu-clean:  sim.cpu.clean
cpu-help:   sim.cpu.help