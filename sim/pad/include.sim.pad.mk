# PAD Simulation Makefile

# -------------------------------------------
# Configuration
# -------------------------------------------
PAD_SIM_DIR 		:= $(SIM_DIR)/pad
PAD_SRC_DIR 		:= $(TOP_DIR)/src/pad
PAD_SIM_BUILD_DIR 	:= $(SIM_BUILD_DIR)/pad


# -------------------------------------------
# Source Files
# -------------------------------------------
PAD_SOURCES := $(PAD_SRC_DIR)/io_pad.v

PAD_TB := $(PAD_SIM_DIR)/tb_io_pad.v

# -------------------------------------------
# Targets
# -------------------------------------------
.PHONY: sim.pad sim.pad.run sim.pad.wave sim.pad.clean

sim.pad: $(PAD_SIM_BUILD_DIR)/io_pad_tb.out

# Build
$(PAD_SIM_BUILD_DIR)/io_pad_tb.out:  $(PAD_SOURCES) $(PAD_TB)
	@echo "$(PAD_SIM_DIR)"
	@mkdir -p $(PAD_SIM_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(PAD_SRC_DIR) $^
	@echo "[IO_PAD] Testbench built: $@"
	@echo ""

# Run
sim.pad.run: $(PAD_SIM_BUILD_DIR)/io_pad_tb.out
	@echo "\n[IO_PAD] Running tests..."
	@cd $(PAD_SIM_BUILD_DIR) && $(VVP) io_pad_tb.out -l io_pad.log
	@echo "[IO_PAD] Test completed - see $(PAD_SIM_BUILD_DIR)/io_pad.log"
	@echo ""

# Wave
sim.pad.wave:
	$(GTKWAVE) $(PAD_SIM_BUILD_DIR)/io_pad_tb.vcd &

# Clean
sim.pad.clean:
	rm -rf $(PAD_SIM_BUILD_DIR)
	rm -rf *.vcd *.log


# -------------------------------------------
# Shortcuts
# -------------------------------------------
pad: sim.pad
pad-run: sim.pad.run
pad-wave: sim.pad.wave
pad-clean: sim.pad.clean