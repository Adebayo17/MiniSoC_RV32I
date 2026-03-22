# ==============================================================================
# sim/top/include.sim.top.mk : Top-level Simulation Makefile
# ==============================================================================

# -------------------------------------------
# Configuration
# -------------------------------------------
TOP_SIM_DIR             := $(SIM_DIR)/top
TOP_SRC_DIR             := $(TOP_DIR)/src/top
TOP_SIM_BUILD_DIR       := $(SIM_BUILD_DIR)/top
TOP_SIM_TESTCASES_DIR   := $(TOP_SIM_DIR)/testcases
TOP_SIM_FIRMWARE_DIR    := $(TOP_SIM_DIR)/firmware_program

# Toolchain RISC-V pour le firmware de simulation
RISCV_PREFIX            ?= riscv32-unknown-elf-
CC                      := $(RISCV_PREFIX)gcc
OBJCOPY                 := $(RISCV_PREFIX)objcopy
OBJDUMP                 := $(RISCV_PREFIX)objdump
SIZE                    := $(RISCV_PREFIX)size

# -------------------------------------------
# Source Files (Auto-discovery)
# -------------------------------------------
TOP_SOURCES := $(wildcard $(TOP_SRC_DIR)/*.v)
TOP_TB      := $(wildcard $(TOP_SIM_DIR)/*.v)

# Firmware files (We specifically keep firmware.S as the main entry point)
TOP_SIM_FIRMWARE_SRC  := $(TOP_SIM_FIRMWARE_DIR)/firmware.S
TOP_SIM_LINKER_SCRIPT := $(TOP_SIM_FIRMWARE_DIR)/linker.ld
TOP_SIM_TEST_HEADER   := $(TOP_SIM_FIRMWARE_DIR)/minisoc_test.h

# Compiler flags
FIRMWARE_CFLAGS := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -static \
                   -T$(TOP_SIM_LINKER_SCRIPT) -Os -ffreestanding -Wall \
                   -mno-div   # Explicitly disable M extension

# -------------------------------------------
# Firmware Targets
# -------------------------------------------
.PHONY: sim.top.firmware sim.top.firmware-clean sim.top.firmware-verify

sim.top.firmware: $(TOP_SIM_BUILD_DIR)/firmware.mem

# Build firmware from assembly source
$(TOP_SIM_BUILD_DIR)/firmware.mem: $(TOP_SIM_FIRMWARE_SRC) $(TOP_SIM_LINKER_SCRIPT) $(TOP_SIM_TEST_HEADER)
	@mkdir -p $(dir $@)
	$(Q)echo "  [CC]        Building TOP test firmware"
	$(Q)$(CC) $(FIRMWARE_CFLAGS) -I$(TOP_SIM_FIRMWARE_DIR) $(TOP_SIM_FIRMWARE_SRC) -o $(TOP_SIM_BUILD_DIR)/firmware.elf
	$(Q)echo "  [OBJCOPY]   Generating ihex format"
	$(Q)$(OBJCOPY) -O ihex $(TOP_SIM_BUILD_DIR)/firmware.elf $(TOP_SIM_BUILD_DIR)/firmware.ihex
	$(Q)echo "  [HEX2MEM]   Converting to memory format"
	$(Q)python3 $(TOP_DIR)/scripts/convert/hex2mem.py $(TOP_SIM_BUILD_DIR)/firmware.ihex $@
	$(Q)rm -f $(TOP_SIM_BUILD_DIR)/firmware.ihex
	$(Q)echo "  [TOP-FW]    Test firmware ready: $@"
	@$(SIZE) $(TOP_SIM_BUILD_DIR)/firmware.elf | tail -1 | awk '{print "              Text: " $$1 " bytes, Data: " $$2 " bytes, BSS: " $$3 " bytes"}'
	@wc -l < $@ | xargs echo "              Memory words:"

sim.top.firmware-clean:
	$(Q)echo "  [CLEAN]     TOP Firmware artifacts"
	$(Q)rm -f $(TOP_SIM_BUILD_DIR)/firmware.*

sim.top.firmware-verify: sim.top.firmware
	$(Q)echo "  [VERIFY]    TOP Firmware contents"
	$(Q)echo "Firmware file: $(TOP_SIM_BUILD_DIR)/firmware.mem"
	$(Q)echo ""
	$(Q)echo "First 10 words of firmware:"
	$(Q)head -10 $(TOP_SIM_BUILD_DIR)/firmware.mem
	$(Q)echo ""
	$(Q)echo "Firmware word count:"
	$(Q)wc -l < $(TOP_SIM_BUILD_DIR)/firmware.mem
	$(Q)echo ""
	$(Q)echo "Disassembly (first 20 instructions):"
	$(Q)$(OBJDUMP) -d $(TOP_SIM_BUILD_DIR)/firmware.elf | head -30

# -------------------------------------------
# Simulation Targets
# -------------------------------------------
.PHONY: sim.top sim.top.run sim.top.wave sim.top.clean

sim.top: $(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.out

# Build Hardware Simulation
# All *_SOURCES variables come from the sub-makefiles included before
$(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.out: $(BUS_SOURCES) $(IMEM_SOURCES) $(DMEM_SOURCES) $(MEM_INIT_SOURCES) $(UART_SOURCES) $(TIMER_SOURCES) $(GPIO_SOURCES) $(CPU_SOURCES) $(PAD_SOURCES) $(TOP_SOURCES) $(TOP_TB)
	@mkdir -p $(dir $@)
	$(Q)echo "  [IVERILOG]  Compiling TOP Testbench"
	$(Q)$(IVERILOG) -o $@ \
		-I$(TOP_DIR)/src/bus \
		-I$(TOP_DIR)/src/cpu \
		-I$(TOP_DIR)/src/mem \
		-I$(TOP_DIR)/src/mem/imem \
		-I$(TOP_DIR)/src/mem/dmem \
		-I$(TOP_DIR)/src/mem/mem_init \
		-I$(TOP_DIR)/src/peripheral \
		-I$(TOP_DIR)/src/peripheral/uart \
		-I$(TOP_DIR)/src/peripheral/timer \
		-I$(TOP_DIR)/src/peripheral/gpio \
		-I$(TOP_DIR)/src/pad \
		-I$(TOP_SRC_DIR) \
		-DFIRMWARE_FILE=\"$(TOP_SIM_BUILD_DIR)/firmware.mem\" \
		-DBAUD_DIV_RST=104 \
		$^

# Run
sim.top.run: sim.top sim.top.firmware
	$(Q)echo "  [VVP]       Running TOP Simulation..."
	$(Q)cd $(TOP_SIM_BUILD_DIR) && $(VVP) mini_rv32i_top_tb.out -l mini_rv32i_top.log
	$(Q)echo "  [SIM-TOP]   Test completed. Log: $(TOP_SIM_BUILD_DIR)/mini_rv32i_top.log"
	$(Q)echo "  [SIM-TOP]   Last log lines:"
	@tail -5 $(TOP_SIM_BUILD_DIR)/mini_rv32i_top.log
	$(Q)echo ""

# Wave
sim.top.wave:
	$(Q)echo "  [GTKWAVE]   Opening TOP Waveform"
	$(Q)$(GTKWAVE) $(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.vcd &

# Clean
sim.top.clean:
	$(Q)echo "  [CLEAN]     TOP Simulation artifacts"
	$(Q)rm -rf $(TOP_SIM_BUILD_DIR)

# -------------------------------------------
# Debug and Quick Targets
# -------------------------------------------
.PHONY: top-quick debug-firmware

# Quick rebuild and run
top-quick: sim.top.firmware debug-firmware sim.top sim.top.run

# Debug: build firmware only with heavy disassemblies
debug-firmware:
	@mkdir -p $(TOP_SIM_BUILD_DIR)
	$(Q)echo "  [CC]        Building debug firmware with detailed output..."
	$(Q)$(CC) $(FIRMWARE_CFLAGS) $(TOP_SIM_FIRMWARE_SRC) -o $(TOP_SIM_BUILD_DIR)/firmware.elf
	$(Q)$(OBJCOPY) -O ihex $(TOP_SIM_BUILD_DIR)/firmware.elf $(TOP_SIM_BUILD_DIR)/firmware.ihex
	$(Q)python3 $(TOP_DIR)/scripts/convert/hex2mem.py $(TOP_SIM_BUILD_DIR)/firmware.ihex $(TOP_SIM_BUILD_DIR)/firmware.mem
	$(Q)rm -f $(TOP_SIM_BUILD_DIR)/firmware.ihex
	$(Q)echo "  [OBJDUMP]   Extracting disassembly sections..."
	$(Q)$(OBJDUMP) -d $(TOP_SIM_BUILD_DIR)/firmware.elf > $(TOP_SIM_BUILD_DIR)/firmware.disasm
	$(Q)$(OBJDUMP) -D $(TOP_SIM_BUILD_DIR)/firmware.elf > $(TOP_SIM_BUILD_DIR)/firmware_full.disasm
	$(Q)$(OBJDUMP) -h $(TOP_SIM_BUILD_DIR)/firmware.elf > $(TOP_SIM_BUILD_DIR)/firmware_section.disasm
	$(Q)$(OBJDUMP) -t $(TOP_SIM_BUILD_DIR)/firmware.elf > $(TOP_SIM_BUILD_DIR)/firmware_symbol_table.disasm
	$(Q)echo "  [DEBUG]     Files generated in $(TOP_SIM_BUILD_DIR)/ :"
	$(Q)echo "              - firmware.disasm"
	$(Q)echo "              - firmware_full.disasm"
	$(Q)echo "              - firmware_section.disasm"
	$(Q)echo "              - firmware_symbol_table.disasm"

# -------------------------------------------
# Help
# -------------------------------------------
.PHONY: sim.top.help

sim.top.help:
	@echo "================================================================================"
	@echo "MiniSoC-RV32I: TOP-LEVEL Simulation Makefile Commands"
	@echo "================================================================================"
	@echo ""
	@echo "Simulation control"
	@echo "  make sim.top                   - Build top simulation"
	@echo "  make sim.top.run               - Run top simulation"
	@echo "  make sim.top.wave              - Open waveform viewer (GTKWave)"
	@echo "  make sim.top.clean             - Clean top simulation files"
	@echo "  make sim.top.help              - Show top simulation help"
	@echo ""
	@echo "Firmware Management:"
	@echo "  make sim.top.firmware          - Build firmware for simulation"
	@echo "  make sim.top.firmware-verify   - Verify firmware content and size"
	@echo "  make sim.top.firmware-clean    - Clean simulation firmware files"
	@echo ""
	@echo "Development Shortcuts:"
	@echo "  make top-quick                 - Rebuild firmware and run simulation"
	@echo "  make debug-firmware            - Build firmware with detailed output"
	@echo ""
	@echo "Shortcuts:"
	@echo "  make top                       - Alias for sim.top"
	@echo "  make top-run                   - Alias for sim.top.run"
	@echo "  make top-wave                  - Alias for sim.top.wave"
	@echo "  make top-clean                 - Alias for sim.top.clean"
	@echo "  make top-firmware              - Alias for sim.top.firmware"
	@echo "  make top-firmware-verify       - Alias for sim.top.firmware-verify"
	@echo "================================================================================"

# -------------------------------------------
# Shortcuts
# -------------------------------------------
.PHONY: top top-run top-wave top-clean top-help \
        top-firmware top-firmware-clean top-firmware-verify

top:                    sim.top
top-run:                sim.top.run
top-wave:               sim.top.wave
top-clean:              sim.top.clean
top-help:               sim.top.help

top-firmware:           sim.top.firmware
top-firmware-clean:     sim.top.firmware-clean
top-firmware-verify:    sim.top.firmware-verify