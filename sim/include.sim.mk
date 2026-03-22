# ==============================================================================
# sim/include.sim.mk : Simulation Root Makefile
# ==============================================================================

# -------------------------------------------
# Simulation Directories
# -------------------------------------------
SIM_DIR := $(TOP_DIR)/sim
export SIM_DIR 

# Use minisoc build directory for sources
SIM_FIRMWARE_DIR := $(SIM_BUILD_DIR)/firmware


# -------------------------------------------
# Simulation Tools
# -------------------------------------------
IVERILOG 		?= iverilog 
VVP 			?= vvp 
GTKWAVE 		?= gtkwave 
export IVERILOG VVP GTKWAVE


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
SIM_TARGETS := sim.bus sim.mem sim.peripheral sim.cpu sim.pad 


# -------------------------------------------
# Top-level simulation Targets
# -------------------------------------------
.PHONY: sim.all sim.clean $(SIM_TARGETS)

# Main simulation target (Compile all testbenches)
sim.all: $(SIM_TARGETS) sim.top.firmware debug-firmware sim.top
	$(Q)echo "  [SIM]       All simulation components built successfully"


# Run all simulations
sim.run.all: $(SIM_TARGETS:%=%.run) sim.top.run
	$(Q)echo "  [SIM]       All simulations completed"

# Clean all simulation files
sim.clean:
	$(Q)echo "  [CLEAN]     Simulation artifacts ($(SIM_BUILD_DIR))"
	$(Q)rm -rf $(SIM_BUILD_DIR)

# -------------------------------------------
# Shortcuts
# -------------------------------------------
.PHONY: sim sim-run sim-clean
sim:        sim.all
sim-run:    sim.run.all
sim-clean:  sim.clean

