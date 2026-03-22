# ==============================================================================
# sim/pad/include.sim.pad.mk : PAD Simulation Makefile
# ==============================================================================

# -------------------------------------------
# Configuration
# -------------------------------------------
PAD_SIM_DIR         := $(SIM_DIR)/pad
PAD_SRC_DIR         := $(TOP_DIR)/src/pad
PAD_SIM_BUILD_DIR   := $(SIM_BUILD_DIR)/pad

# -------------------------------------------
# Source Files (Auto-discovery)
# -------------------------------------------
PAD_SOURCES := $(wildcard $(PAD_SRC_DIR)/*.v)
PAD_TB      := $(wildcard $(PAD_SIM_DIR)/*.v)

# -------------------------------------------
# Targets
# -------------------------------------------
.PHONY: sim.pad sim.pad.run sim.pad.wave sim.pad.clean

sim.pad: $(PAD_SIM_BUILD_DIR)/io_pad_tb.out

# Build
$(PAD_SIM_BUILD_DIR)/io_pad_tb.out: $(PAD_SOURCES) $(PAD_TB)
	@mkdir -p $(dir $@)
	$(Q)echo "  [IVERILOG]  Compiling PAD Testbench"
	$(Q)$(IVERILOG) -o $@ -I$(PAD_SRC_DIR) $^

# Run
sim.pad.run: sim.pad
	$(Q)echo "  [VVP]       Running PAD Simulation..."
	$(Q)cd $(PAD_SIM_BUILD_DIR) && $(VVP) io_pad_tb.out -l io_pad.log
	$(Q)echo "  [SIM-PAD]   Test completed. Log: $(PAD_SIM_BUILD_DIR)/io_pad.log"

# Wave
sim.pad.wave:
	$(Q)echo "  [GTKWAVE]   Opening PAD Waveform"
	$(Q)$(GTKWAVE) $(PAD_SIM_BUILD_DIR)/io_pad_tb.vcd &

# Clean
sim.pad.clean:
	$(Q)echo "  [CLEAN]     PAD Simulation artifacts"
	$(Q)rm -rf $(PAD_SIM_BUILD_DIR)

# -------------------------------------------
# Help
# -------------------------------------------
.PHONY: sim.pad.help

sim.pad.help:
	@echo "================================================================================"
	@echo "MiniSoC-RV32I: pad Makefile Commands"
	@echo "================================================================================"
	@echo "  make sim.pad               - Build pad simulation"
	@echo "  make sim.pad.run           - Run pad simulation"
	@echo "  make sim.pad.wave          - Open pad waveform"
	@echo "  make sim.pad.clean         - Clean pad simulation files"
	@echo "  make sim.pad.help          - Show pad simulation help"
	@echo ""
	@echo "Shortcuts:"
	@echo "  make pad                   - Alias for sim.pad"
	@echo "  make pad-run               - Alias for sim.pad.run"
	@echo "  make pad-wave              - Alias for sim.pad.wave"
	@echo "  make pad-clean             - Alias for sim.pad.clean"
	@echo "  make pad-help              - Alias for sim.pad.help"
	@echo "================================================================================"

# -------------------------------------------
# Shortcuts
# -------------------------------------------
.PHONY: pad pad-run pad-wave pad-clean pad-help

pad:        sim.pad
pad-run:    sim.pad.run
pad-wave:   sim.pad.wave
pad-clean:  sim.pad.clean
pad-help:   sim.pad.help