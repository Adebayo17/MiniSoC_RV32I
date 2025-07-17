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


# -------------------------------------------
# Aggregate Targets
# -------------------------------------------
sim: check_env
	$(MAKE) -C sim all


clean:
	@echo "Cleaning entire Project..."
	@rm -rf $(BUILD_DIR)
	@find . -name "*.vcd" -delete
	@find . -name "*.log" -delete
	@find . -name "*.out" -delete

distclean: clean
	@rm -rf *.vcd *.log *.out

# -------------------------------------------
# help
# -------------------------------------------
help:
	@echo "================================================================================"
	@echo "Top-Level Makefile Commands"
	@echo " make check_env		- Check for required tools"
	@echo ""
	@echo "Subsystem targets:"
	@echo "  make sim.bus   - Build bus components"
	@echo "  make sim.cpu   - Build CPU components"
	@echo "  make sw.test   - Build test programs"
	@echo "  make synth.top - Synthesize top-level"
	@echo "================================================================================"

