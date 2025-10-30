# Top-level Simulation Makefile

# -------------------------------------------
# Configuration
# -------------------------------------------
TOP_SIM_DIR          	:= $(SIM_DIR)/top
TOP_SRC_DIR          	:= $(TOP_DIR)/src/top
TOP_SIM_BUILD_DIR    	:= $(SIM_BUILD_DIR)/top
TOP_SIM_TESTCASES_DIR	:= $(TOP_SIM_DIR)/testcases
TOP_SIM_FIRMWARE_DIR 	:= $(TOP_SIM_DIR)/firmware_program

# Toolchain
RISCV_PREFIX 			?= riscv32-unknown-elf-
CC 						:= $(RISCV_PREFIX)gcc
OBJCOPY 				:= $(RISCV_PREFIX)objcopy

# -------------------------------------------
# Source Files
# -------------------------------------------
TOP_SOURCES := \
    $(TOP_SRC_DIR)/top_soc.v \
    $(TOP_SRC_DIR)/mini_rv32i_top.v


TOP_TB := $(TOP_SIM_DIR)/tb_mini_rv32i_top.v

# Firmware files
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
	@echo "[TOP_SIM_FIRMWARE] Building test firmware..."
	@mkdir -p $(TOP_SIM_BUILD_DIR)
	$(CC) $(FIRMWARE_CFLAGS) -I$(TOP_SIM_FIRMWARE_DIR) $(TOP_SIM_FIRMWARE_SRC) -o $(TOP_SIM_BUILD_DIR)/firmware.elf
	$(OBJCOPY) -O ihex $(TOP_SIM_BUILD_DIR)/firmware.elf $(TOP_SIM_BUILD_DIR)/firmware.ihex
	python3 $(TOP_DIR)/scripts/convert/hex2mem.py $(TOP_SIM_BUILD_DIR)/firmware.ihex $@
	@rm -f $(TOP_SIM_BUILD_DIR)/firmware.ihex
	@echo "[TOP_SIM_FIRMWARE] Test firmware ready: $@"
	@echo "[TOP_SIM_FIRMWARE] Firmware created: $@"
	@echo "[TOP_SIM_FIRMWARE] Firmware statistics:"
	@$(SIZE) $(TOP_SIM_BUILD_DIR)/firmware.elf | tail -1 | awk '{print "  Text: " $$1 " bytes, Data: " $$2 " bytes, BSS: " $$3 " bytes"}'
	@wc -l < $@ | xargs echo "  Memory words:"


sim.top.firmware-clean:
	rm -f $(TOP_SIM_BUILD_DIR)/firmware.*


sim.top.firmware-verify: sim.top.firmware
	@echo "[TOP_SIM_FIRMWARE_VERIFY] Verifying firmware..."
	@echo "Firmware file: $(TOP_SIM_BUILD_DIR)/firmware.mem"
	@echo ""
	@echo "First 10 words of firmware:"
	@head -10 $(TOP_SIM_BUILD_DIR)/firmware.mem
	@echo ""
	@echo "Firmware word count:"
	@wc -l < $(TOP_SIM_BUILD_DIR)/firmware.mem
	@echo ""
	@echo "Disassembly (first 20 instructions):"
	@$(RISCV_PREFIX)objdump -d $(TOP_SIM_BUILD_DIR)/firmware.elf | head -30


# -------------------------------------------
# Targets
# -------------------------------------------
.PHONY: sim.top sim.top.run sim.top.wave sim.top.clean

sim.top: $(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.out

# Build
$(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.out: $(BUS_SOURCES) $(IMEM_SOURCES) $(DMEM_SOURCES) $(MEM_INIT_SOURCES) $(UART_SOURCES) $(TIMER_SOURCES) $(GPIO_SOURCES) $(CPU_SOURCES) $(PAD_SOURCES) $(TOP_SOURCES) $(TOP_TB)
	@echo "Building top-level SoC testbench..."
	@mkdir -p $(TOP_SIM_BUILD_DIR)
	$(IVERILOG) -o $@ \
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
	@echo "[TOP_SOC] Testbench built: $@"
	@echo ""

# Run
sim.top.run: sim.top	
	@echo "\n[TOP] Running top-level simulation..."
	@cd $(TOP_SIM_BUILD_DIR) && $(VVP) mini_rv32i_top_tb.out -l mini_rv32i_top.log
	@echo "[TOP] Simulation completed"
	@echo "[TOP] Log file: $(TOP_SIM_BUILD_DIR)/mini_rv32i_top.log"
	@echo "[TOP] Last log lines:"
	@tail -5 $(TOP_SIM_BUILD_DIR)/mini_rv32i_top.log
	@echo ""

# Wave
sim.top.wave:
	$(GTKWAVE) $(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.vcd &

# Clean
sim.top.clean:
	rm -rf $(TOP_SIM_BUILD_DIR)
	rm -f $(TOP_SIM_DIR)/*.vcd $(TOP_SIM_DIR)/*.log

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
	@echo "  make sim.top                 	- Build top simulation"
	@echo "  make sim.top.run             	- Run top simulation"
	@echo "  make sim.top.wave            	- Open Open waveform viewer (GTKWave)"
	@echo "  make sim.top.clean           	- Clean top simulation files"
	@echo "  make sim.top.help            	- Show top simulation help"
	@echo ""
	@echo "Firmware Management:"
	@echo "  make sim.top.firmware        	- Build/copy firmware for simulation"
	@echo "  make sim.top.firmware-verify 	- Verify firmware content and size"
	@echo "  make sim.top.firmware-clean 	- Clean simulation firmware files"
	@echo ""
	@echo "Development Shortcuts:"
	@echo "  make top-quick              	- Rebuild firmware and run simulation"
	@echo "  make debug-firmware        	- Build firmware with detailed output"
	@echo ""
	@echo "Shortcuts:"
	@echo "  make top                     	- Alias for sim.top"
	@echo "  make top-run                 	- Alias for sim.top.run"
	@echo "  make top-wave                	- Alias for sim.top.wave"
	@echo "  make top-clean               	- Alias for sim.top.clean"
	@echo "  make top-help                	- Alias for sim.top.help"
	@echo "  make top-firmware           	- Alias for sim.top.firmware"
	@echo "  make top-firmware-clean    	- Alias for sim.top.firmware-clean"
	@echo ""
	@echo "File Locations:"
	@echo "  Firmware source:            	$(TOP_SIM_FIRMWARE_SRC)"
	@echo "  Firmware output:            	$(TOP_SIM_BUILD_DIR)/firmware.mem"
	@echo "  Simulation build:           	$(TOP_SIM_BUILD_DIR)"
	@echo "  Waveform file:              	$(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.vcd"
	@echo ""
	@echo "Workflow Examples:"
	@echo "  Quick test:                	make top-quick"
	@echo "  Full build and run:        	make top-run"
	@echo "  Debug firmware:            	make debug-firmware"
	@echo "  Verify then run:           	make top-firmware-verify && make top-run"
	@echo ""
	@echo "================================================================================"


# -------------------------------------------
# Shortcuts
# -------------------------------------------
top: 					sim.top
top-run: 				sim.top.run
top-wave: 				sim.top.wave
top-clean: 				sim.top.clean
top-help: 				sim.top.help

top-firmware: 			sim.top.firmware
top-firmware-clean: 	sim.top.firmware-clean
top-firmware-verify: 	sim.top.firmware-verify

# Quick rebuild and run
top-quick: sim.top.firmware debug-firmware sim.top sim.top.run

# Debug: build firmware only
debug-firmware:
	@echo "[TOP_SIM_FIRMWARE_DEBUG] Building firmware with detailed output..."
	@mkdir -p $(TOP_SIM_BUILD_DIR)
	$(CC) $(FIRMWARE_CFLAGS) $(TOP_SIM_FIRMWARE_SRC) -o $(TOP_SIM_BUILD_DIR)/firmware.elf
	$(OBJCOPY) -O ihex $(TOP_SIM_BUILD_DIR)/firmware.elf $(TOP_SIM_BUILD_DIR)/firmware.ihex
	python3 $(TOP_DIR)/scripts/convert/hex2mem.py $(TOP_SIM_BUILD_DIR)/firmware.ihex $(TOP_SIM_BUILD_DIR)/firmware.mem
	@rm -f $(TOP_SIM_BUILD_DIR)/firmware.ihex
	@echo "[TOP_SIM_FIRMWARE_DEBUG] Generated: $(TOP_SIM_BUILD_DIR)/firmware.mem"
	@echo "[TOP_SIM_FIRMWARE_DEBUG] Firmware disassembly:"
	@$(RISCV_PREFIX)objdump -d $(TOP_SIM_BUILD_DIR)/firmware.elf > $(TOP_SIM_BUILD_DIR)/firmware.disasm
	@$(RISCV_PREFIX)objdump -D $(TOP_SIM_BUILD_DIR)/firmware.elf > $(TOP_SIM_BUILD_DIR)/firmware_full.disasm
	@$(RISCV_PREFIX)objdump -h $(TOP_SIM_BUILD_DIR)/firmware.elf > $(TOP_SIM_BUILD_DIR)/firmware_section.disasm
	@$(RISCV_PREFIX)objdump -t $(TOP_SIM_BUILD_DIR)/firmware.elf > $(TOP_SIM_BUILD_DIR)/firmware_symbol_table.disasm
	@echo "    Text:         	$(TOP_SIM_BUILD_DIR)/firmware.disasm"
	@echo "    Full:          	$(TOP_SIM_BUILD_DIR)/firmware_full.disasm"
	@echo "    Section:        	$(TOP_SIM_BUILD_DIR)/firmware_section.disasm"
	@echo "    Symbol Table:   	$(TOP_SIM_BUILD_DIR)/firmware_symbol_table.disasm"