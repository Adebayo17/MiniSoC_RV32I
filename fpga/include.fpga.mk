# =============================================================================
# fpga/include.fpga.mk — FPGA Build Sub-Makefile (Arty Z7-20 / Vivado)
# =============================================================================
# Included by the root Makefile.
# Provides targets:
#   fpga-project    → Create Vivado project (TCL)
#   fpga-firmware   → Compile firmware for FPGA (SYS_CLK = 125 MHz)
#   fpga-bitstream  → Run synthesis + implementation + generate bitstream
#   fpga-program    → Program the FPGA via Vivado hardware manager
#   fpga-clean      → Clean FPGA build artefacts
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
FPGA_DIR            := $(TOP_DIR)/fpga
FPGA_BUILD_DIR      := $(BUILD_DIR)/fpga
FPGA_PROJECT_NAME   := minisoc_arty_z7
FPGA_PROJECT_DIR    := $(FPGA_BUILD_DIR)/$(FPGA_PROJECT_NAME)

# Vivado executable — adapt path if needed, or set VIVADO in your shell env
VIVADO              ?= vivado

# FPGA target clock frequency (Hz) — used for BAUD_DIV and firmware delays
FPGA_SYS_CLK_HZ    := 125000000

# UART baud rate (same as simulation)
BAUD_RATE           := 115200

# Computed baud divisor for the RTL parameter (integer division)
FPGA_BAUD_DIV       := $(shell python3 -c "print($(FPGA_SYS_CLK_HZ) // $(BAUD_RATE) - 1)")

# Firmware build directory for FPGA (separate from sim firmware)
FPGA_SW_BUILD_DIR   := $(FPGA_BUILD_DIR)/sw

export FPGA_DIR FPGA_BUILD_DIR FPGA_PROJECT_NAME FPGA_PROJECT_DIR
export FPGA_SYS_CLK_HZ FPGA_BAUD_DIV FPGA_SW_BUILD_DIR

# ---------------------------------------------------------------------------
# .PHONY declarations
# ---------------------------------------------------------------------------
.PHONY: fpga fpga-project fpga-firmware fpga-bitstream fpga-program fpga-clean

# ---------------------------------------------------------------------------
# fpga — default FPGA target: firmware + project creation
# ---------------------------------------------------------------------------
fpga: fpga-firmware fpga-project
	$(Q)echo "[FPGA] Ready. Open Vivado project or run 'make fpga-bitstream'."
	$(Q)echo "  Project: $(FPGA_PROJECT_DIR)/$(FPGA_PROJECT_NAME).xpr"
	$(Q)echo ""

# ---------------------------------------------------------------------------
# fpga-project — create Vivado project via TCL
# ---------------------------------------------------------------------------
fpga-project: fpga-firmware
	$(Q)echo "[FPGA] Creating Vivado project for Arty Z7-20..."
	$(Q)mkdir -p $(FPGA_BUILD_DIR)
	$(Q)cp $(FPGA_SW_BUILD_DIR)/firmware.mem $(FPGA_BUILD_DIR)/ 2>/dev/null || \
	    echo "  WARNING: firmware.mem not found in $(FPGA_SW_BUILD_DIR)"
	$(Q)$(VIVADO) -mode batch \
	              -source $(FPGA_DIR)/vivado_project.tcl \
	              -log    $(FPGA_BUILD_DIR)/vivado_project.log \
	              -tclargs REPO_ROOT=$(TOP_DIR)
	$(Q)echo "[FPGA] Project created."
	$(Q)echo ""

# ---------------------------------------------------------------------------
# fpga-firmware — compile firmware with FPGA clock frequency
# ---------------------------------------------------------------------------
# Passes SYS_CLK_HZ=125000000 so firmware delay loops use the correct value.
# Output goes to FPGA_SW_BUILD_DIR to avoid overwriting the sim firmware.
fpga-firmware:
	$(Q)echo "[FPGA] Building firmware @ $(FPGA_SYS_CLK_HZ) Hz..."
	$(Q)mkdir -p $(FPGA_SW_BUILD_DIR)
	$(Q)$(MAKE) sw.firmware \
	    SW_BUILD_DIR=$(FPGA_SW_BUILD_DIR) \
	    EXTRA_CFLAGS="-DSYS_CLK_HZ=$(FPGA_SYS_CLK_HZ) -DFPGA_TARGET"
	$(Q)echo "[FPGA] Firmware ready in $(FPGA_SW_BUILD_DIR)/"
	$(Q)echo ""

# ---------------------------------------------------------------------------
# fpga-bitstream — batch synthesis + implementation + bitstream generation
# ---------------------------------------------------------------------------
fpga-bitstream: fpga-project
	$(Q)echo "[FPGA] Running Vivado synthesis + implementation + bitstream..."
	$(Q)$(VIVADO) -mode batch \
	              -source $(FPGA_DIR)/vivado_build.tcl \
	              -log    $(FPGA_BUILD_DIR)/vivado_build.log \
	              -tclargs REPO_ROOT=$(TOP_DIR)
	$(Q)echo "[FPGA] Bitstream: $(FPGA_PROJECT_DIR)/$(FPGA_PROJECT_NAME).runs/impl_1/top_arty_z7.bit"
	$(Q)echo ""

# ---------------------------------------------------------------------------
# fpga-program — program the FPGA (board must be connected via USB-JTAG)
# ---------------------------------------------------------------------------
fpga-program:
	$(Q)echo "[FPGA] Programming Arty Z7-20 via JTAG..."
	$(Q)$(VIVADO) -mode batch \
	              -source $(FPGA_DIR)/vivado_program.tcl \
	              -log    $(FPGA_BUILD_DIR)/vivado_program.log \
	              -tclargs BITFILE=$(FPGA_PROJECT_DIR)/$(FPGA_PROJECT_NAME).runs/impl_1/top_arty_z7.bit
	$(Q)echo "[FPGA] Programming complete."
	$(Q)echo ""

# ---------------------------------------------------------------------------
# fpga-clean
# ---------------------------------------------------------------------------
fpga-clean:
	$(Q)echo "[FPGA] Cleaning FPGA build directory..."
	$(Q)rm -rf $(FPGA_BUILD_DIR)
	$(Q)echo "[FPGA] Clean complete."