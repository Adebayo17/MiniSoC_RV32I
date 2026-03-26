# ==============================================================================
# sim/bus/include.sim.bus.mk : Bus Simulation Makefile
# ==============================================================================

# -------------------------------------------
# Configuration
# -------------------------------------------
BUS_SIM_DIR 		:= $(SIM_DIR)/bus
BUS_SRC_DIR 		:= $(TOP_DIR)/src/bus
BUS_SIM_BUILD_DIR 	:= $(SIM_BUILD_DIR)/bus


# -------------------------------------------
# Source files
# -------------------------------------------
BUS_SOURCES := $(wildcard $(BUS_SRC_DIR)/*.v)
BUS_TB      := $(wildcard $(BUS_SIM_DIR)/*.v)


# -------------------------------------------
# Targets
# -------------------------------------------
.PHONY: sim.bus sim.bus.run sim.bus.wave 

# Compiling the test bench with Icarus Verilog
$(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.out: $(COMMON_SRCS) $(BUS_SOURCES) $(BUS_TB)
	@mkdir -p $(dir $@)
	$(Q)echo "  [IVERILOG]  Compiling Bus Testbench"
	$(Q)$(IVERILOG) -o $@ -I$(INC_DIR) -I$(BUS_SOURCES) $^

# Main dependency
sim.bus: $(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.out

# Running simulation
sim.bus.run: sim.bus
	$(Q)echo "  [VVP]       Running Bus Simulation..."
	$(Q)cd $(BUS_SIM_BUILD_DIR) && $(VVP) wishbone_interconnect_tb.out -l wishbone_interconnect.log
	$(Q)echo "  [SIM-BUS]   Test completed. Log: $(BUS_SIM_BUILD_DIR)/wishbone_interconnect.log"

# Show waveforms
sim.bus.wave:
	$(Q)echo "  [GTKWAVE]   Opening Bus Waveform"
	$(Q)$(GTKWAVE) $(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.vcd &


# -------------------------------------------
# Clean Targets
# -------------------------------------------
.PHONY: sim.bus.clean

sim.bus.clean:
	$(Q)echo "  [CLEAN]     Bus Simulation artifacts"
	$(Q)rm -rf $(BUS_SIM_BUILD_DIR)


# -------------------------------------------
# Help
# -------------------------------------------
.PHONY: sim.bus.help

sim.bus.help:
	@echo "================================================================================"
	@echo "MiniSoC-RV32I: WISHBONE_INTERCONNECT Makefile Commands"
	@echo "================================================================================"
	@echo "  make sim.bus             	- Build bus simulation"
	@echo "  make sim.bus.run         	- Run bus simulation"
	@echo "  make sim.bus.wave        	- Open bus waveform"
	@echo "  make sim.bus.clean       	- Clean bus simulation files"
	@echo "  make sim.bus.help         	- Show Bus simulation help"
	@echo ""
	@echo "Shortcuts:"
	@echo "  make bus                	- Alias for sim.bus"
	@echo "  make bus-run             	- Alias for sim.bus.run"
	@echo "  make bus-wave            	- Alias for sim.bus.wave"
	@echo "  make bus-clean     		- Alias for sim.bus.clean"
	@echo "  make bus-help            	- Alias for sim.bus.help"
	@echo "================================================================================"

# -------------------------------------------
# Shortcuts
# -------------------------------------------
.PHONY: bus bus-run bus-wave bus-clean bus-help

bus: 		sim.bus
bus-run: 	sim.bus.run
bus-wave: 	sim.bus.wave
bus-clean: 	sim.bus.clean
bus-help: 	sim.bus.help