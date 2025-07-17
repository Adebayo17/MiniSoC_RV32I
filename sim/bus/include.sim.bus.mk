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

BUS_TESTBENCHES := \
				$(BUS_SIM_DIR)/tb_wishbone_interconnect.v \
#				$(BUS_SIM_DIR)/testcases/test_address_decoding.v 


# -------------------------------------------
# Targets
# -------------------------------------------
.PHONY: sim.bus sim.bus.run sim.bus.wave sim.bus.clean

sim.bus: $(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.out

$(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.out: $(BUS_SOURCES) $(BUS_TESTBENCHES)
	@mkdir -p $(BUS_SIM_BUILD_DIR)
	@touch  $(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.vcd
	$(IVERILOG) -o $@ -I$(BUS_SRC_DIR) $^
	@echo ""
	@echo "Simulation executable built: $@"

#sim.bus.run: sim.bus
#	@echo "Running bus simulation..."
#	@cd $(BUS_SIM_BUILD_DIR) && $(VVP) wishbone_interconnect_tb.out

sim.bus.run: $(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.out
	@echo ""
	@echo "Running bus simulation..."
	@cd $(BUS_SIM_BUILD_DIR) && $(VVP) wishbone_interconnect_tb.out -l simulation.log

sim.bus.wave:
	$(GTKWAVE) $(BUS_SIM_BUILD_DIR)/wishbone_interconnect_tb.vcd &

sim.bus.clean:
	rm -rf $(BUS_SIM_BUILD_DIR)
	rm -f *.vcd *.log

# -------------------------------------------
# Shortcuts
# -------------------------------------------
bus: sim.bus
bus-run: sim.bus.run
bus-wave: sim.bus.wave
bus-clean: sim.bus.clean