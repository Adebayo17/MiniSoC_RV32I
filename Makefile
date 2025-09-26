# Central Makefile for MiniSoC-RV32I Project

.PHONY: all check_env help clean

# -------------------------------------------
# Configuration
# -------------------------------------------
TOP_DIR := $(shell pwd)
BUILD_DIR ?= $(TOP_DIR)/build
export TOP_DIR BUILD_DIR

# -------------------------------------------
# Include Sub-Makefiles
# -------------------------------------------
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
	@mkdir -p $(SIM_BUILD_DIR)
	@mkdir -p $(SW_BUILD_DIR)
	@mkdir -p $(SYNTH_BUILD_DIR)
	@echo "[Makefile] Environment check complete"
	@echo ""


# -------------------------------------------
# Aggregate Targets
# -------------------------------------------

# Simulation targets
sim: check_env
	$(MAKE) -C sim.all

sim-run: check_env
	$(MAKE) sim.run.all


clean:
	@echo "Cleaning entire Project..."
	@rm -rf $(BUILD_DIR)
	@find . -name "*.vcd" -delete
	@find . -name "*.log" -delete
	@find . -name "*.out" -delete
	@find . -name "*.hex" -delete
	@find . -name "*.bin" -delete
	@find . -name "*.o" -delete
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

# Build firmware for simulation (used by sim targets)
firmware: check_env
	$(MAKE) sw.firmware.for_sim


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
	@echo "  make sw.firmware        - Build firmware"
	@echo "  make sw.test            - Build test programs"
	@echo "  make sw-clean           - Clean software files"
	@echo ""
	@echo "Synthesis:"
	@echo "  make synth              - Run synthesis"
	@echo "  make synth-clean        - Clean synthesis files"
	@echo ""
	@echo "Cleaning:"
	@echo "  make clean              - Clean build files"
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

