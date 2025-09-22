# Top-level Simulation Makefile

# -------------------------------------------
# Configuration
# -------------------------------------------
TOP_SIM_DIR          := $(SIM_DIR)/top
TOP_SRC_DIR          := $(TOP_DIR)/src/top
TOP_SIM_BUILD_DIR    := $(SIM_BUILD_DIR)/top
TOP_SIM_TESTCASES_DIR:= $(TOP_SIM_DIR)/testcases
FIRMWARE_DIR         := $(TOP_SIM_DIR)/firmware_program

# Toolchain
RISCV_PREFIX 	?= riscv64-unknown-elf-
CC 				:= $(RISCV_PREFIX)gcc
OBJCOPY 		:= $(RISCV_PREFIX)objcopy

# -------------------------------------------
# Source Files
# -------------------------------------------
TOP_SOURCES := \
    $(TOP_SRC_DIR)/top_soc.v \
    $(TOP_SRC_DIR)/mini_rv32i_top.v


TOP_TB := $(TOP_SIM_DIR)/tb_mini_rv32i_top.v

# Firmware files
FIRMWARE_SRC  := $(FIRMWARE_DIR)/firmware.S
LINKER_SCRIPT := $(FIRMWARE_DIR)/linker.ld

# Compiler flags
FIRMWARE_CFLAGS := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -static \
                   -T$(LINKER_SCRIPT) -Os -ffreestanding -Wall \
                   -mno-div   # Explicitly disable M extension


# -------------------------------------------
# Firmware Targets
# -------------------------------------------
.PHONY: firmware firmware-clean

firmware: $(TOP_SIM_BUILD_DIR)/firmware.hex

# Build firmware from assembly source
$(TOP_SIM_BUILD_DIR)/firmware.hex: $(FIRMWARE_SRC) $(LINKER_SCRIPT)
	@echo "[FIRMWARE] Building firmware from $(FIRMWARE_SRC)"
	@mkdir -p $(TOP_SIM_BUILD_DIR)
	@# Compile to ELF
	$(CC) $(FIRMWARE_CFLAGS) $(FIRMWARE_SRC) -o $(TOP_SIM_BUILD_DIR)/firmware.elf
	@# Convert to binary
	$(OBJCOPY) -O binary $(TOP_SIM_BUILD_DIR)/firmware.elf $(TOP_SIM_BUILD_DIR)/firmware.bin
	@# Convert to hex format for Verilog $readmemh
	hexdump -v -e '1/4 "%08x\n"' $(TOP_SIM_BUILD_DIR)/firmware.bin > $@
	@echo "[FIRMWARE] Firmware created: $@"
	@echo "[FIRMWARE] Firmware size:"
	@wc -l < $@ | xargs echo "  Words:"
	@stat -c "  Bytes: %s" $(TOP_SIM_BUILD_DIR)/firmware.bin

firmware-clean:
	rm -f $(TOP_SIM_BUILD_DIR)/firmware.*


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
		-DFIRMWARE_FILE=\"$(TOP_SIM_BUILD_DIR)/firmware.hex\" \
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
# Shortcuts
# -------------------------------------------
top: sim.top
top-run: sim.top.run
top-wave: sim.top.wave
top-clean: sim.top.clean

top-firmware: firmware
top-firmware-clean: firmware-clean

# Quick rebuild and run
top-quick: firmware sim.top sim.top.run

# Debug: build firmware only
debug-firmware:
	@echo "[DEBUG] Building firmware with detailed output..."
	$(CC) $(FIRMWARE_CFLAGS) $(FIRMWARE_SRC) -o $(TOP_SIM_BUILD_DIR)/firmware.elf
	$(OBJCOPY) -O binary $(TOP_SIM_BUILD_DIR)/firmware.elf $(TOP_SIM_BUILD_DIR)/firmware.bin
	hexdump -v -e '1/4 "%08x\n"' $(TOP_SIM_BUILD_DIR)/firmware.bin > $(TOP_SIM_BUILD_DIR)/firmware.hex
	@echo "[DEBUG] Firmware disassembly:"
	$(RISCV_PREFIX)objdump -d $(TOP_SIM_BUILD_DIR)/firmware.elf