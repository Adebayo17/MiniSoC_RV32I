# sim/include.sim.mk : sim Folder Makefile

# -------------------------------------------
# Simulation Directories
# -------------------------------------------
SIM_DIR 		:= $(TOP_DIR)/sim
SIM_BUILD_DIR 	:= $(BUILD_DIR)/sim
export SIM_DIR SIM_BUILD_DIR

# Use minisoc build directory for sources
SIM_SRC_DIR := $(MINISOC_BUILD_DIR)/src
SIM_FIRMWARE_DIR := $(MINISOC_BUILD_DIR)


# -------------------------------------------
# Simulation Tools
# -------------------------------------------
IVERILOG 		?= iverilog 
VVP 			?= vvp 
GTKWAVE 		?= gtkwave 


# -------------------------------------------
# Simulation Flags
# -------------------------------------------


# -------------------------------------------
# Include sub-components (Respect order)
# -------------------------------------------
include $(SIM_DIR)/bus/include.sim.bus.mk
include $(SIM_DIR)/mem/include.sim.mem.mk
include $(SIM_DIR)/peripheral/include.sim.peripheral.mk
include $(SIM_DIR)/cpu/include.sim.cpu.mk
include $(SIM_DIR)/pad/include.sim.pad.mk
include $(SIM_DIR)/top/include.sim.top.mk


# -------------------------------------------
# Simulation Variables
# -------------------------------------------
SIM_TARGETS := sim.bus sim.mem sim.peripheral sim.cpu sim.pad sim.top


# -------------------------------------------
# Top-level simulation Targets
# -------------------------------------------
.PHONY: sim.all sim.clean $(SIM_TARGETS)

# Main simulation target
sim.all: $(SIM_TARGETS)
	@echo "[SIM] All simulation components built successfully"


# Run all simulations
sim.run.all: $(SIM_TARGETS:%=%.run)
	@echo "[SIM] All simulations completed"

# Clean all simulation files
sim.clean:
	@echo "Cleaning simulation files..."
	@rm -rf $(SIM_BUILD_DIR)
	@find $(SIM_DIR) -name "build" -delete
	@find $(SIM_DIR) -name "*.vcd" -delete
	@find $(SIM_DIR) -name "*.log" -delete
	@find $(SIM_DIR) -name "*.out" -delete
	@echo "[SIM] Clean complete"

# -------------------------------------------
# Shortcuts
# -------------------------------------------
sim: 		sim.all
sim-run: 	sim.run.all
sim-clean: 	sim.clean

