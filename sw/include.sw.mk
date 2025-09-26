# sw/include.sw.mk : Software Build System

# -------------------------------------------
# Common Software Settings
# -------------------------------------------
SW_DIR := $(TOP_DIR)/sw
SW_BUILD_DIR := $(BUILD_DIR)/sw
SW_SRC_DIR := $(SW_DIR)/src
SW_DRIVERS_DIR := $(SW_DIR)/drivers
SW_TESTS_DIR := $(SW_DIR)/tests
SW_INCLUDE_DIR := $(SW_DIR)/include

export SW_DIR SW_BUILD_DIR SW_SRC_DIR SW_DRIVERS_DIR SW_TESTS_DIR SW_INCLUDE_DIR

# -------------------------------------------
# Toolchain Configuration
# -------------------------------------------
CROSS_COMPILE ?= riscv64-unknown-elf-
CC := $(CROSS_COMPILE)gcc
AS := $(CROSS_COMPILE)as
LD := $(CROSS_COMPILE)ld
OBJCOPY := $(CROSS_COMPILE)objcopy
OBJDUMP := $(CROSS_COMPILE)objdump
SIZE := $(CROSS_COMPILE)size

export CC AS LD OBJCOPY OBJDUMP SIZE

# Compiler flags
CFLAGS := -march=rv32i -mabi=ilp32 -O2 -Wall -Wextra -ffreestanding -nostartfiles
CFLAGS += -I$(SW_INCLUDE_DIR)
CFLAGS += -I$(SW_DRIVERS_DIR)/gpio/include
CFLAGS += -I$(SW_DRIVERS_DIR)/timer/include
CFLAGS += -I$(SW_DRIVERS_DIR)/uart/include

ASFLAGS := -march=rv32i -mabi=ilp32
LDFLAGS := -T $(SW_DIR)/linker.ld -nostdlib -static -Wl,--gc-sections

export CFLAGS ASFLAGS LDFLAGS

# -------------------------------------------
# Source Files
# -------------------------------------------

# Main application
SW_MAIN_SRCS := $(SW_SRC_DIR)/startup.S
SW_MAIN_SRCS += $(SW_SRC_DIR)/system.c
SW_MAIN_SRCS += $(SW_SRC_DIR)/main.c

# Driver sources
SW_DRIVER_SRCS := $(SW_DRIVERS_DIR)/uart/src/uart.c
SW_DRIVER_SRCS += $(SW_DRIVERS_DIR)/gpio/src/gpio.c
SW_DRIVER_SRCS += $(SW_DRIVERS_DIR)/timer/src/timer.c

# Test sources
SW_TEST_SRCS := $(SW_TESTS_DIR)/gpio/gpio_usage.c
SW_TEST_SRCS += $(SW_TESTS_DIR)/timer/timer_usage.c
SW_TEST_SRCS += $(SW_TESTS_DIR)/uart/uart_usage.c
SW_TEST_SRCS += $(SW_TESTS_DIR)/integration_test.c

# All sources
SW_ALL_SRCS := $(SW_MAIN_SRCS) $(SW_DRIVER_SRCS) $(SW_TEST_SRCS)

# Object files
SW_MAIN_OBJS := $(patsubst $(SW_DIR)/%, $(SW_BUILD_DIR)/%, $(SW_MAIN_SRCS:.c=.o))
SW_MAIN_OBJS := $(SW_MAIN_OBJS:.S=.o)

SW_DRIVER_OBJS := $(patsubst $(SW_DIR)/%, $(SW_BUILD_DIR)/%, $(SW_DRIVER_SRCS:.c=.o))

SW_TEST_OBJS := $(patsubst $(SW_DIR)/%, $(SW_BUILD_DIR)/%, $(SW_TEST_SRCS:.c=.o))

SW_ALL_OBJS := $(SW_MAIN_OBJS) $(SW_DRIVER_OBJS) $(SW_TEST_OBJS)

# -------------------------------------------
# Target Definitions
# -------------------------------------------

# Main firmware
FIRMWARE_ELF := $(SW_BUILD_DIR)/firmware.elf
FIRMWARE_BIN := $(SW_BUILD_DIR)/firmware.bin
FIRMWARE_HEX := $(SW_BUILD_DIR)/firmware.hex
FIRMWARE_MAP := $(SW_BUILD_DIR)/firmware.map
FIRMWARE_DISASM := $(SW_BUILD_DIR)/firmware.disasm

# Test programs
GPIO_TEST_ELF := $(SW_BUILD_DIR)/tests/gpio_test.elf
TIMER_TEST_ELF := $(SW_BUILD_DIR)/tests/timer_test.elf
UART_TEST_ELF := $(SW_BUILD_DIR)/tests/uart_test.elf
INTEGRATION_TEST_ELF := $(SW_BUILD_DIR)/tests/integration_test.elf

TEST_ELFS := $(GPIO_TEST_ELF) $(TIMER_TEST_ELF) $(UART_TEST_ELF) $(INTEGRATION_TEST_ELF)

# -------------------------------------------
# Build Rules
# -------------------------------------------

# Main firmware build
$(FIRMWARE_ELF): $(SW_MAIN_OBJS) $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@echo "[SW] Linking firmware: $@"
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -Wl,-Map=$(FIRMWARE_MAP) -o $@ $(SW_MAIN_OBJS) $(SW_DRIVER_OBJS) $(LDFLAGS)
	$(SIZE) $@

$(FIRMWARE_BIN): $(FIRMWARE_ELF)
	@echo "[SW] Creating binary: $@"
	$(OBJCOPY) -O binary $< $@

$(FIRMWARE_HEX): $(FIRMWARE_ELF)
	@echo "[SW] Creating hex: $@"
	$(OBJCOPY) -O ihex $< $@

$(FIRMWARE_DISASM): $(FIRMWARE_ELF)
	@echo "[SW] Creating disassembly: $@"
	$(OBJDUMP) -d $< > $@

# Test program builds
$(GPIO_TEST_ELF): $(SW_BUILD_DIR)/tests/gpio_usage.o $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

$(TIMER_TEST_ELF): $(SW_BUILD_DIR)/tests/timer_usage.o $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

$(UART_TEST_ELF): $(SW_BUILD_DIR)/tests/uart_usage.o $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

$(INTEGRATION_TEST_ELF): $(SW_BUILD_DIR)/tests/integration_test.o $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

# Pattern rule for object files
$(SW_BUILD_DIR)/%.o: $(SW_DIR)/%.c
	@echo "[SW] Compiling: $<"
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(SW_BUILD_DIR)/%.o: $(SW_DIR)/%.S
	@echo "[SW] Assembling: $<"
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -c $< -o $@

# -------------------------------------------
# Top-level Software Targets
# -------------------------------------------
.PHONY: sw.all sw.clean sw.firmware sw.test sw.drivers

sw.all: sw.firmware sw.test

sw.firmware: $(FIRMWARE_BIN) $(FIRMWARE_HEX) $(FIRMWARE_DISASM)
	@echo "[SW] Firmware build complete"
	@echo "    Binary: $(FIRMWARE_BIN)"
	@echo "    Hex:    $(FIRMWARE_HEX)"
	@echo "    ELF:    $(FIRMWARE_ELF)"

sw.test: $(TEST_ELFS)
	@echo "[SW] Test programs built:"
	@for test in $(TEST_ELFS); do \
		echo "    $$test"; \
	done

sw.drivers: $(SW_DRIVER_OBJS)
	@echo "[SW] Driver objects built"

sw.clean:
	@echo "[SW] Cleaning software build..."
	@rm -rf $(SW_BUILD_DIR)
	@echo "[SW] Clean complete"

sw.info:
	@echo "Software Build Configuration:"
	@echo "  SW_DIR:          $(SW_DIR)"
	@echo "  SW_BUILD_DIR:    $(SW_BUILD_DIR)"
	@echo "  CROSS_COMPILE:   $(CROSS_COMPILE)"
	@echo "  CC:              $(CC)"
	@echo "  CFLAGS:          $(CFLAGS)"
	@echo "  Sources:         $(words $(SW_ALL_SRCS)) files"
	@echo "  Firmware output: $(FIRMWARE_BIN)"

# -------------------------------------------
# Simulation Integration Targets
# -------------------------------------------
.PHONY: sw.firmware.for_sim

sw.firmware.for_sim: $(FIRMWARE_BIN)
	@echo "[SW] Copying firmware for simulation..."
	@cp $(FIRMWARE_BIN) $(SIM_BUILD_DIR)/firmware.bin
	@cp $(FIRMWARE_HEX) $(SIM_BUILD_DIR)/firmware.hex
	@echo "[SW] Firmware ready for simulation"