# src/include.src.mk : Hardware Source Compilation

# -------------------------------------------
# Source Directories
# -------------------------------------------
SRC_DIR := $(TOP_DIR)/src
SRC_BUILD_DIR := $(MINISOC_BUILD_DIR)/src
export SRC_DIR SRC_BUILD_DIR

# -------------------------------------------
# Source Files by Category
# -------------------------------------------

# CPU Core
CPU_SRCS := $(SRC_DIR)/cpu/cpu.v
CPU_SRCS += $(SRC_DIR)/cpu/alu.v
CPU_SRCS += $(SRC_DIR)/cpu/control_unit.v
CPU_SRCS += $(SRC_DIR)/cpu/decode_stage.v
CPU_SRCS += $(SRC_DIR)/cpu/execute_stage.v
CPU_SRCS += $(SRC_DIR)/cpu/fetch_stage.v
CPU_SRCS += $(SRC_DIR)/cpu/forward_unit.v
CPU_SRCS += $(SRC_DIR)/cpu/hazard_unit.v
CPU_SRCS += $(SRC_DIR)/cpu/mem_stage.v
CPU_SRCS += $(SRC_DIR)/cpu/regfile.v
CPU_SRCS += $(SRC_DIR)/cpu/wb_stage.v

# Memory
MEM_SRCS := $(SRC_DIR)/mem/imem/imem.v
MEM_SRCS += $(SRC_DIR)/mem/imem/imem_wrapper.v
MEM_SRCS += $(SRC_DIR)/mem/dmem/dmem.v
MEM_SRCS += $(SRC_DIR)/mem/dmem/dmem_wrapper.v
MEM_SRCS += $(SRC_DIR)/mem/mem_init/mem_init.v

# Bus
BUS_SRCS := $(SRC_DIR)/bus/wishbone_interconnect.v

# Peripherals
PERIPH_SRCS := $(SRC_DIR)/peripheral/uart/uart.v
PERIPH_SRCS += $(SRC_DIR)/peripheral/uart/uart_baudgen.v
PERIPH_SRCS += $(SRC_DIR)/peripheral/uart/uart_rx.v
PERIPH_SRCS += $(SRC_DIR)/peripheral/uart/uart_tx.v
PERIPH_SRCS += $(SRC_DIR)/peripheral/uart/uart_wrapper.v
PERIPH_SRCS += $(SRC_DIR)/peripheral/timer/timer.v
PERIPH_SRCS += $(SRC_DIR)/peripheral/timer/timer_wrapper.v
PERIPH_SRCS += $(SRC_DIR)/peripheral/gpio/gpio.v
PERIPH_SRCS += $(SRC_DIR)/peripheral/gpio/gpio_wrapper.v

# Top Level
TOP_SRCS := $(SRC_DIR)/top/mini_rv32i_top.v
TOP_SRCS += $(SRC_DIR)/top/top_soc.v

# Common
COMMON_SRCS := $(SRC_DIR)/common/debug_utils.vh
COMMON_SRCS += $(SRC_DIR)/pad/io_pad.v

# All Source Files
ALL_SRCS := $(CPU_SRCS) $(MEM_SRCS) $(BUS_SRCS) $(PERIPH_SRCS) $(TOP_SRCS) $(COMMON_SRCS)

# Build targets in minisoc directory
SRC_BUILD_TARGETS := $(patsubst $(SRC_DIR)/%, $(SRC_BUILD_DIR)/%, $(ALL_SRCS))

# -------------------------------------------
# Compilation Rules
# -------------------------------------------

# Copy Verilog files to build directory
$(SRC_BUILD_DIR)/%.v: $(SRC_DIR)/%.v
	@echo "[SRC] Copying: $<"
	@mkdir -p $(dir $@)
	@cp $< $@
	@echo ""

$(SRC_BUILD_DIR)/%.vh: $(SRC_DIR)/%.vh
	@echo "[SRC] Copying: $<"
	@mkdir -p $(dir $@)
	@cp $< $@
	@echo ""

# Top-level source targets
.PHONY: src.all src.cpu src.mem src.bus src.peripheral src.top src.clean

src.all: $(SRC_BUILD_TARGETS)
	@echo "[SRC] All hardware sources compiled to $(SRC_BUILD_DIR)"
	@echo "  CPU:        $(words $(CPU_SRCS)) files"
	@echo "  Memory:     $(words $(MEM_SRCS)) files"
	@echo "  Bus:        $(words $(BUS_SRCS)) files"
	@echo "  Peripherals: $(words $(PERIPH_SRCS)) files"
	@echo "  Top Level:  $(words $(TOP_SRCS)) files"
	@echo ""

src.cpu: $(patsubst $(SRC_DIR)/%, $(SRC_BUILD_DIR)/%, $(CPU_SRCS))
	@echo "[SRC] CPU sources compiled"

src.mem: $(patsubst $(SRC_DIR)/%, $(SRC_BUILD_DIR)/%, $(MEM_SRCS))
	@echo "[SRC] Memory sources compiled"

src.bus: $(patsubst $(SRC_DIR)/%, $(SRC_BUILD_DIR)/%, $(BUS_SRCS))
	@echo "[SRC] Bus sources compiled"

src.peripheral: $(patsubst $(SRC_DIR)/%, $(SRC_BUILD_DIR)/%, $(PERIPH_SRCS))
	@echo "[SRC] Peripheral sources compiled"

src.top: $(patsubst $(SRC_DIR)/%, $(SRC_BUILD_DIR)/%, $(TOP_SRCS))
	@echo "[SRC] Top-level sources compiled"

src.clean:
	@echo "[SRC] Cleaning hardware build..."
	@rm -rf $(SRC_BUILD_DIR)
	@echo "[SRC] Clean complete"
	@echo ""

# -------------------------------------------
# File Lists for Simulation and Synthesis
# -------------------------------------------

# Generate file list for simulation
$(MINISOC_BUILD_DIR)/minisoc.f: src.all
	@echo "[SRC] Generating file list: $@"
	@echo "# MiniSoC-RV32I Source File List" > $@
	@echo "# Generated automatically - DO NOT EDIT" >> $@
	@echo "" >> $@
	@for file in $(SRC_BUILD_TARGETS); do \
		echo "$$file" >> $@; \
	done
	@echo "[SRC] File list generated: $@"
	@echo ""

.PHONY: src.filelist
src.filelist: $(MINISOC_BUILD_DIR)/minisoc.f