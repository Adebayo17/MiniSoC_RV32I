# sim/include.sim.mk : sim Folder Makefile

# -------------------------------------------
# Common Simulation Settings
# -------------------------------------------
SIM_DIR 		:= $(TOP_DIR)/sim
SIM_BUILD_DIR 	:= $(BUILD_DIR)/sim
IVERILOG 		?= iverilog 
VVP 			?= vvp 
GTKWAVE 		?= gtkwave 

# -------------------------------------------
# Include sub-components
# -------------------------------------------
include $(SIM_DIR)/bus/include.sim.bus.mk
include $(SIM_DIR)/mem/include.sim.mem.mk
include $(SIM_DIR)/peripheral/include.sim.peripheral.mk
include $(SIM_DIR)/cpu/include.sim.cpu.mk


# -------------------------------------------
# Top-level simulation Targets
# -------------------------------------------
.PHONY: sim.all sim.clean

sim.all: sim.bus sim.mem sim.cpu # sim.top sim.peripheral

sim.clean:
	@echo "Cleaning simulation files..."
	@rm -rf $(SIM_BUILD_DIR)
	@find $(SIM_DIR) -name "*.vcd" -delete
	@find $(SIM_DIR) -name "*.log" -delete
	@find $(SIM_DIR) -name "*.out" -delete

