# ============================================================================
# MiniSoC Complete System Simulation Makefile
# ============================================================================
# This Makefile builds and runs the complete MiniSoC with C-generated firmware
# ============================================================================

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
SIM_MINISOC_DIR       := $(TOP_DIR)/sim_minisoc
SIM_MINISOC_BUILD_DIR := $(BUILD_DIR)/minisoc/sim
export SIM_MINISOC_DIR SIM_MINISOC_BUILD_DIR

# ----------------------------------------------------------------------------
# Source Files
# ----------------------------------------------------------------------------

# Testbench source
SIM_MINISOC_TB_SOURCE := $(SIM_MINISOC_DIR)/tb_minisoc_c_firmware.v

# Hardware sources (complete system)
SIM_MINISOC_HW_SOURCES := \
    $(TOP_DIR)/src/top/mini_rv32i_top.v \
    $(TOP_DIR)/src/top/top_soc.v \
    $(TOP_DIR)/src/cpu/*.v \
    $(TOP_DIR)/src/bus/*.v \
    $(TOP_DIR)/src/mem/**/*.v \
    $(TOP_DIR)/src/peripheral/**/*.v \
    $(TOP_DIR)/src/pad/*.v

# Testbench include files
SIM_MINISOC_INCLUDE_FILES := \
    $(SIM_MINISOC_DIR)/testcases/verify_minisoc.vh \
    $(SIM_MINISOC_DIR)/testcases/monitor_minisoc.vh

# Firmware file (generated from sw/)
FIRMWARE_MEM_FILE := $(MINISOC_BUILD_DIR)/firmware.mem


# ----------------------------------------------------------------------------
# Compilation Flags
# ----------------------------------------------------------------------------
SIM_MINISOC_IVERILOG_FLAGS := \
    -I$(SIM_MINISOC_DIR) \
    -I$(TOP_DIR)/src/common \
    -DFIRMWARE_PATH=\"$(MINISOC_BUILD_DIR)/firmware.mem\" \
    -DMINISOC_SIMULATION

SIM_LOG_FILE := $(SIM_MINISOC_BUILD_DIR)/minisoc_firmware.log
SIM_MINISOC_VVP_FLAGS := -l $(SIM_LOG_FILE)


# ----------------------------------------------------------------------------
# Target Definitions
# ----------------------------------------------------------------------------
SIM_MINISOC_OUTPUT := $(SIM_MINISOC_BUILD_DIR)/tb_minisoc.out
SIM_MINISOC_VCD    := $(SIM_MINISOC_BUILD_DIR)/minisoc_c_firmware.vcd

# ----------------------------------------------------------------------------
# Build Rules
# ----------------------------------------------------------------------------

# Check firmware exists
.PHONY: check_firmware
check_firmware:
	@if [ ! -f "$(FIRMWARE_MEM_FILE)" ]; then \
		echo "=================================================="; \
		echo "FIRMWARE NOT FOUND"; \
		echo "=================================================="; \
		echo "C firmware needs to be built first."; \
		echo ""; \
		echo "Run from project root:"; \
		echo "  make minisoc"; \
		echo ""; \
		echo "Or build just the firmware:"; \
		echo "  make sw-firmware"; \
		echo "=================================================="; \
		exit 1; \
	fi

	@cp $(FIRMWARE_MEM_FILE) $(SIM_MINISOC_BUILD_DIR)/


# Main simulation build
$(SIM_MINISOC_OUTPUT): check_firmware $(SIM_MINISOC_TB_SOURCE) $(SIM_MINISOC_HW_SOURCES) $(SIM_MINISOC_INCLUDE_FILES)
	@echo "=================================================="
	@echo "Building MiniSoC with C Firmware Simulation"
	@echo "=================================================="
	@echo "Testbench:     $(SIM_MINISOC_TB_SOURCE)"
	@echo "Hardware:      $(words $(SIM_MINISOC_HW_SOURCES)) source files"
	@echo "Firmware:      $(FIRMWARE_MEM_FILE)"
	@echo "Build dir:     $(SIM_MINISOC_BUILD_DIR)"
	@echo ""
	
	@mkdir -p $(SIM_MINISOC_BUILD_DIR)
	
	@echo "[1/4] Checking firmware..."
	@if [ ! -f "$(FIRMWARE_MEM_FILE)" ]; then \
		echo "ERROR: Firmware not found at $(FIRMWARE_MEM_FILE)"; \
		echo "Run 'make minisoc' from project root first"; \
		exit 1; \
	fi
	@echo "  ✓ Firmware found"
	@echo "    Size: $$(wc -l < $(FIRMWARE_MEM_FILE)) lines"
	
	@echo "[2/4] Checking hardware sources..."
	@for file in $(SIM_MINISOC_HW_SOURCES); do \
		if [ ! -f "$$file" ]; then \
			echo "  WARNING: Source file not found: $$file"; \
		fi; \
	done
	
	@echo "[3/4] Compiling simulation..."
	@cd $(SIM_MINISOC_BUILD_DIR) && $(IVERILOG) \
		$(SIM_MINISOC_IVERILOG_FLAGS) \
		-o tb_minisoc.out \
		$(SIM_MINISOC_TB_SOURCE) \
		$(SIM_MINISOC_HW_SOURCES) \
		2>&1 | tee compile.log
	
	@echo "[4/4] Build complete!"
	@echo "  Output: $(SIM_MINISOC_OUTPUT)"
	@echo "  Log:    $(SIM_MINISOC_BUILD_DIR)/compile.log"
	@echo "=================================================="




# -------------------------------------------
# Top-level Targets
# -------------------------------------------
.PHONY: sim_minisoc.all sim_minisoc.build sim_minisoc.run sim_minisoc.wave \
        sim_minisoc.quick sim_minisoc.clean sim_minisoc.info \
        sim_minisoc.view-firmware

# Build simulation
sim_minisoc.build: $(SIM_MINISOC_OUTPUT)
	@echo "[SIM-MINISOC] Build complete"

# Run simulation
sim_minisoc.run: sim_minisoc.build
	@echo "=================================================="
	@echo "Running MiniSoC C Firmware Simulation"
	@echo "=================================================="
	@echo "Starting at: $$(date)"
	@echo "Firmware: $(FIRMWARE_MEM_FILE)"
	@echo ""
	
	@cd $(SIM_MINISOC_BUILD_DIR) && $(VVP) tb_minisoc.out $(SIM_MINISOC_VVP_FLAGS)
	
	@echo ""
	@echo "=================================================="
	@echo "Simulation Complete"
	@echo "Log file: $(SIM_MINISOC_BUILD_DIR)/simulation.log"
	@echo "=================================================="

# Run simulation with waveform capture
sim_minisoc.wave: 
	@echo "=================================================="
	@echo "Running MiniSoC with Waveform Capture"
	@echo "=================================================="
	
	@if [ -f "$(SIM_MINISOC_VCD)" ]; then \
		echo "Opening waveform viewer..."; \
		$(GTKWAVE) $(SIM_MINISOC_VCD) & \
	fi

# Quick run (assumes already built)
sim_minisoc.quick: sim_minisoc.build sim_minisoc.run 

# View firmware information
sim_minisoc.view-firmware: check_firmware
	@echo "=================================================="
	@echo "C Firmware Information"
	@echo "=================================================="
	@echo "Location: $(FIRMWARE_MEM_FILE)"
	@echo ""
	@echo "First 20 instructions:"
	@head -n 20 $(FIRMWARE_MEM_FILE)
	@echo ""
	@if [ -f "$(MINISOC_BUILD_DIR)/firmware.disasm" ]; then \
		echo "Disassembly (first 30 lines):"; \
		head -n 30 $(MINISOC_BUILD_DIR)/firmware.disasm; \
	fi
	@echo "=================================================="

# Show simulation information
sim_minisoc.info:
	@echo "=================================================="
	@echo "MiniSoC Complete System Simulation Info"
	@echo "=================================================="
	@echo "Directory:      $(SIM_MINISOC_DIR)"
	@echo "Build dir:      $(SIM_MINISOC_BUILD_DIR)"
	@echo "Testbench:      $(notdir $(SIM_MINISOC_TB_SOURCE))"
	@echo "Hardware files: $(words $(SIM_MINISOC_HW_SOURCES))"
	@echo "Firmware:       $(FIRMWARE_MEM_FILE)"
	@echo "Tools:"
	@echo "  IVERILOG:     $(IVERILOG)"
	@echo "  VVP:          $(VVP)"
	@echo "  GTKWAVE:      $(GTKWAVE)"
	@echo ""
	@echo "Firmware status:"
	@if [ -f "$(FIRMWARE_MEM_FILE)" ]; then \
		echo "  ✓ Present ($$(wc -l < $(FIRMWARE_MEM_FILE)) instructions)"; \
	else \
		echo "  ✗ Missing - run 'make minisoc' first"; \
	fi
	@echo "=================================================="

# Clean simulation files
sim_minisoc.clean:
	@echo "Cleaning MiniSoC simulation files..."
	@rm -rf $(SIM_MINISOC_BUILD_DIR)
	@echo "Clean complete."

# Alias for all
sim_minisoc.all: sim_minisoc.build

# -------------------------------------------
# Shortcut Targets (for main Makefile)
# -------------------------------------------
.PHONY: sim-minisoc sim-minisoc-run sim-minisoc-wave sim-minisoc-clean view-firmware

sim-minisoc: sim_minisoc.build
sim-minisoc-run: sim_minisoc.run
sim-minisoc-wave: sim_minisoc.wave
sim-minisoc-quick: sim_minisoc.quick
sim-minisoc-clean: sim_minisoc.clean
view-firmware: sim_minisoc.view-firmware

# -------------------------------------------
# Help Target
# -------------------------------------------
.PHONY: sim_minisoc.help
sim_minisoc.help:
	@echo "=================================================="
	@echo "MINISOC COMPLETE SYSTEM SIMULATION COMMANDS"
	@echo "=================================================="
	@echo ""
	@echo "This module simulates the complete MiniSoC with C-generated"
	@echo "firmware from the sw/ folder."
	@echo ""
	@echo "From project root (recommended):"
	@echo "  make sim-minisoc       - Build simulation"
	@echo "  make sim-minisoc-run   - Build and run simulation"
	@echo "  make sim-minisoc-wave  - Run with waveform viewer"
	@echo "  make view-firmware     - View firmware contents"
	@echo "  make sim-minisoc-clean - Clean simulation files"
	@echo ""
	@echo "Direct targets (from include.sim_minisoc.mk):"
	@echo "  sim_minisoc.build      - Build simulation"
	@echo "  sim_minisoc.run        - Run simulation"
	@echo "  sim_minisoc.wave       - Run with waveform capture"
	@echo "  sim_minisoc.quick      - Run existing simulation"
	@echo "  sim_minisoc.info       - Show simulation info"
	@echo "  sim_minisoc.view-firmware - View firmware"
	@echo "  sim_minisoc.clean      - Clean files"
	@echo ""
	@echo "Prerequisites:"
	@echo "  1. Build firmware first: make minisoc"
	@echo "  2. Firmware location: $(FIRMWARE_MEM_FILE)"
	@echo ""
	@echo "Workflow:"
	@echo "  1. Edit software in sw/src/main.c"
	@echo "  2. Build: make minisoc"
	@echo "  3. Simulate: make sim-minisoc-run"
	@echo "=================================================="