# Central Makefile for MiniSoC-RV32I Project

.PHONY: all check_env help clean

# -------------------------------------------
# Configuration
# -------------------------------------------
TOP_DIR 			:= $(shell pwd)
BUILD_DIR 			?= $(TOP_DIR)/build
MINISOC_BUILD_DIR 	?= $(BUILD_DIR)/minisoc
export TOP_DIR BUILD_DIR MINISOC_BUILD_DIR


# -------------------------------------------
# Include Sub-Makefiles
# -------------------------------------------
include src/include.src.mk 
include sim/include.sim.mk 
include sw/include.sw.mk
include synth/include.synth.mk


# -------------------------------------------
# Default target
# -------------------------------------------
all: check_env
	@echo "MiniSoC-RV32I Project Ready"
	@echo "Use 'make sim' for simulation, 'make sw' for software, 'make synth' for synthesis"


# -------------------------------------------
# Environment check
# -------------------------------------------
check_env:
	@echo "[Makefile] Checking environment..."
	@bash scripts/setup/setup.sh
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(MINISOC_BUILD_DIR)
	@mkdir -p $(SIM_BUILD_DIR)
	@mkdir -p $(SW_BUILD_DIR)
	@mkdir -p $(SYNTH_BUILD_DIR)
	@echo "[Makefile] Environment check complete"
	@echo ""


# -------------------------------------------
# MiniSoC Build Target
# -------------------------------------------
minisoc: check_env src.all firmware.copy
	@echo "[MiniSoC] Complete system built in $(MINISOC_BUILD_DIR)"
	@echo "  Hardware: $(MINISOC_BUILD_DIR)/*.v"
	@echo "  Firmware: $(MINISOC_BUILD_DIR)/firmware.*"
	@echo ""

firmware.copy: sw.firmware
	@echo "[MiniSoC] Copying firmware to minisoc build directory..."
	@cp $(SW_BUILD_DIR)/firmware.bin $(MINISOC_BUILD_DIR)/
	@cp $(SW_BUILD_DIR)/firmware.hex $(MINISOC_BUILD_DIR)/
	@cp $(SW_BUILD_DIR)/firmware.disasm $(MINISOC_BUILD_DIR)/
	@CP $(SW_BUILD_DIR)/firmware.mem $(MINISOC_BUILD_DIR)/
	@echo "[MiniSoC] Firmware ready for simulation/synthesis"
	@echo ""


# -------------------------------------------
# Simulation Targets
# -------------------------------------------
sim: check_env minisoc
	$(MAKE) -C sim.all

sim-run: check_env minisoc
	$(MAKE) sim.run.all


# -------------------------------------------
# Cleaning
# -------------------------------------------
clean:
	@echo "Cleaning entire Project..."
	@rm -rf $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)
	@echo "[Makefile] Clean complete"

distclean: clean
	@rm -rf *.vcd *.log *.out *.hex *.bin *.o
	@echo "[Makefile] Distclean complete"


# -------------------------------------------
# Software Targets
# -------------------------------------------
sw: check_env
	$(MAKE) sw.all

sw-firmware: check_env
	$(MAKE) sw.firmware

sw-test: check_env
	$(MAKE) sw.test

sw-clean: check_env
	$(MAKE) sw.clean

# -------------------------------------------
# Hardware Source Targets
# -------------------------------------------
src: check_env
	$(MAKE) src.all

src-clean: check_env
	$(MAKE) src.clean


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
	@echo "Synthesis:"
	@echo "  make synth              - Run synthesis"
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

