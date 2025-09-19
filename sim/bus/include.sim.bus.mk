# Bus Simulation Makefile

# -------------------------------------------
# Configuration
# -------------------------------------------
BUS_SIM_DIR := $(SIM_DIR)/bus
BUS_SRC_DIR := $(TOP_DIR)/src/bus
BUS_SIM_BUILD_DIR := $(SIM_BUILD_DIR)/bus


# -------------------------------------------
# Source files
# -------------------------------------------
BUS_SOURCES := \
				$(BUS_SRC_DIR)/wishbone_interconnect.v \
				$(BUS_SIM_DIR)/wb_master_model.v \
				$(BUS_SIM_DIR)/wb_slave_model.v 

BUS_TESTBENCHES := $(BUS_SIM_DIR)/tb_wishbone_interconnect.v \



# -------------------------------------------
# Targets
# -------------------------------------------
.PHONY: sim.bus sim.bus.run sim.bus.wave sim.bus.clean

$(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.out: $(BUS_SOURCES) $(BUS_TESTBENCHES)
	@mkdir -p $(BUS_SIM_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(BUS_SRC_DIR) $^
	@echo "[WISHBONE_INTERCONNECT] Testbench built: $@"
	@echo ""

sim.bus: $(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.out

sim.bus.run: sim.bus
	@echo "\n[WISHBONE_INTERCONNECT] Running tests..."
	@cd $(BUS_SIM_BUILD_DIR) && $(VVP) wishbone_interconnect_tb.out -l wishbone_interconnect.log
	@echo "[WISHBONE_INTERCONNECT] Test completed - see $(BUS_SIM_BUILD_DIR)/wishbone_interconnect.log"
	@echo ""

sim.bus.wave:
	$(GTKWAVE) $(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.vcd &


# -------------------------------------------
# Clean Targets
# -------------------------------------------

sim.bus.clean:
	@echo "Cleaning bus test files..."
	@rm -rf $(BUS_SIM_BUILD_DIR)
	@find $(BUS_SIM_DIR) -name "*.vcd" -delete
	@find $(BUS_SIM_DIR) -name "*.log" -delete
	@echo ""

# -------------------------------------------
# Shortcuts
# -------------------------------------------
bus: sim.bus
bus-run: sim.bus.run
bus-wave: sim.bus.wave
bus-clean: sim.bus.clean