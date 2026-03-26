# ==============================================================================
# MiniSoC_RV32I - Root Makefile
# ==============================================================================

.PHONY: all check_env help clean

# -------------------------------------------
# Configuration
# -------------------------------------------
TOP_DIR 				:= $(shell pwd)
BUILD_DIR 				?= $(TOP_DIR)/build

# Defining build subfolders to isolate artifacts
MINISOC_BUILD_DIR     	?= $(BUILD_DIR)/minisoc
SIM_BUILD_DIR         	?= $(BUILD_DIR)/sim
SW_BUILD_DIR          	?= $(BUILD_DIR)/sw
SYNTH_BUILD_DIR       	?= $(BUILD_DIR)/synth
SIM_MINISOC_BUILD_DIR 	?= $(BUILD_DIR)/sim_minisoc

export TOP_DIR BUILD_DIR MINISOC_BUILD_DIR SIM_BUILD_DIR SW_BUILD_DIR SYNTH_BUILD_DIR SIM_MINISOC_BUILD_DIR

# -------------------------------------------
# Global Tools and Flags
# -------------------------------------------
# (Optional, to activate verbose mode: make V=1)
ifeq ($(V),1)
  Q :=
else
  Q := @
endif
export Q


# -------------------------------------------
# Include Sub-Makefiles (Non-Recursive)
# -------------------------------------------
include src/include.src.mk 
include sim/include.sim.mk 
include sw/include.sw.mk
include sim_minisoc/include.sim_minisoc.mk
include synth/include.synth.mk


# -------------------------------------------
# Default target
# -------------------------------------------
all: check_env
	$(Q)echo "MiniSoC-RV32I Project Ready"
	$(Q)echo "Use 'make sim' for simulation, 'make sw' for software, 'make synth' for synthesis"


# -------------------------------------------
# Environment check
# -------------------------------------------
check_env:
	$(Q)echo "[Makefile] Checking environment..."
	$(Q)bash scripts/setup/setup.sh
	$(Q)mkdir -p $(BUILD_DIR)
	$(Q)mkdir -p $(MINISOC_BUILD_DIR)
	$(Q)mkdir -p $(SIM_BUILD_DIR)
	$(Q)mkdir -p $(SW_BUILD_DIR)
	$(Q)mkdir -p $(SYNTH_BUILD_DIR)
	$(Q)mkdir -p $(SIM_MINISOC_BUILD_DIR)
	$(Q)echo "[Makefile] Environment check complete"
	$(Q)echo ""


# -------------------------------------------
# MiniSoC Build Target
# -------------------------------------------
minisoc: check_env src.all firmware.copy
	$(Q)echo "[MiniSoC] Complete system built in $(MINISOC_BUILD_DIR)"
	$(Q)echo "  Hardware: $(MINISOC_BUILD_DIR)/*.v"
	$(Q)echo "  Firmware: $(MINISOC_BUILD_DIR)/firmware.*"
	$(Q)echo ""

firmware.copy: sw.firmware
	$(Q)echo "[MiniSoC] Copying firmware to minisoc build directory..."
	$(Q)cp $(SW_BUILD_DIR)/firmware.bin $(MINISOC_BUILD_DIR)/ 2>/dev/null || true
	$(Q)cp $(SW_BUILD_DIR)/firmware.hex $(MINISOC_BUILD_DIR)/ 2>/dev/null || true
	$(Q)cp $(SW_BUILD_DIR)/firmware.disasm $(MINISOC_BUILD_DIR)/ 2>/dev/null || true
	$(Q)cp $(SW_BUILD_DIR)/firmware.mem $(MINISOC_BUILD_DIR)/ 2>/dev/null || true
	$(Q)cp $(SW_BUILD_DIR)/firmware.sym $(MINISOC_BUILD_DIR)/ 2>/dev/null || true
	$(Q)echo "[MiniSoC] Firmware ready for simulation/synthesis"
	$(Q)echo ""


# -------------------------------------------
# Simulation Targets
# -------------------------------------------



# -------------------------------------------
# Cleaning
# -------------------------------------------
clean:
	$(Q)echo "Cleaning entire Project..."
	$(Q)rm -rf $(BUILD_DIR)
	$(Q)mkdir -p $(BUILD_DIR)
	$(Q)echo "[Makefile] Clean complete"

distclean: clean
	$(Q)rm -f *.vcd *.log *.out *.hex *.bin *.o
	$(Q)echo "[Makefile] Distclean complete"


# -------------------------------------------
# Software Targets
# -------------------------------------------
sw: check_env
	$(Q)$(MAKE) sw.all

sw-firmware: check_env
	$(Q)$(MAKE) sw.firmware

sw-test: check_env
	$(Q)$(MAKE) sw.test

sw-clean: check_env
	$(Q)$(MAKE) sw.clean


# -------------------------------------------
# Hardware Source Targets
# -------------------------------------------
src: check_env
	$(Q)$(MAKE) src.all

src-clean: check_env
	$(Q)$(MAKE) src.clean


# -------------------------------------------
# help
# -------------------------------------------
help:
	@echo "================================================================================"
	@echo "MiniSoC-RV32I Project Makefile Commands"
	@echo "================================================================================"
	@echo ""
	@echo "Environment:"
	@echo "  make check_env          - Check for required tools and setup environment"
	@echo "  make all                - Default target (setup environment)"
	@echo ""
	@echo "Complete System Build:"
	@echo "  make minisoc            - Build complete system (hardware + firmware)"
	@echo "  make src                - Build hardware sources only"
	@echo "  make src-clean          - Clean hardware build files"
	@echo ""
	@echo "Simulation:"
	@echo "  make sim                - Build all simulation components"
	@echo "  make sim-run            - Run all simulations"
	@echo "  make sim-clean          - Clean simulation files"
	@echo ""
	@echo "  Component-specific simulation:"
	@echo "    make sim.bus          - Build bus simulation"
	@echo "    make sim.mem          - Build memory simulation"
	@echo "    make sim.cpu          - Build CPU simulation"
	@echo "    make sim.peripheral   - Build peripheral simulation"
	@echo "    make sim.pad          - Build pad simulation"
	@echo "    make sim.top          - Build top-level simulation"
	@echo ""
	@echo "Software:"
	@echo "  make sw                 - Build all software components"
	@echo "  make sw-firmware        - Build firmware"
	@echo "  make sw-clean           - Clean software files"
	@echo ""
	@echo "Complete System Simulation"
	@echo "  make sim-minisoc       - Build simulation"
	@echo "  make sim-minisoc-run   - Build and run simulation"
	@echo "  make sim-minisoc-wave  - Run with waveform viewer"
	@echo "  make view-firmware     - View firmware contents"
	@echo "  make sim-minisoc-clean - Clean simulation files"
	@echo ""
	@echo "Synthesis:"
	@echo "  make synth.all         - Run synthesis"
	@echo ""
	@echo "Cleaning:"
	@echo "  make clean              - Clean all build files"
	@echo "  make distclean          - Deep clean (includes generated files)"
	@echo ""
	@echo "Shortcuts:"
	@echo "  make bus                - Alias for sim.bus"
	@echo "  make mem                - Alias for sim.mem"
	@echo "  make cpu                - Alias for sim.cpu"
	@echo "  make peripheral         - Alias for sim.peripheral"
	@echo "  make pad                - Alias for sim.pad"
	@echo "  make top                - Alias for sim.top"
	@echo "================================================================================"

