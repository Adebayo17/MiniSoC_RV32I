# ==============================================================================
# sw/include.sw.mk : Software Build System
# ==============================================================================

# -------------------------------------------
# Common Software Settings
# -------------------------------------------
SW_DIR         := $(TOP_DIR)/sw
# SW_BUILD_DIR is exported by Root Makefile
SW_BUILD_DIR   ?= $(BUILD_DIR)/sw
SW_SRC_DIR     := $(SW_DIR)/src
SW_DRIVERS_DIR := $(SW_DIR)/drivers
SW_TESTS_DIR   := $(SW_DIR)/tests
SW_INCLUDE_DIR := $(SW_DIR)/include

export SW_DIR SW_BUILD_DIR SW_SRC_DIR SW_DRIVERS_DIR SW_TESTS_DIR SW_INCLUDE_DIR

# -------------------------------------------
# Toolchain Configuration
# -------------------------------------------
CROSS_COMPILE ?= riscv32-unknown-elf-
CC      := $(CROSS_COMPILE)gcc
AS      := $(CROSS_COMPILE)as
LD      := $(CROSS_COMPILE)ld
NM      := $(CROSS_COMPILE)nm
OBJCOPY := $(CROSS_COMPILE)objcopy
OBJDUMP := $(CROSS_COMPILE)objdump
SIZE    := $(CROSS_COMPILE)size

export CC AS LD OBJCOPY OBJDUMP SIZE NM

# Architecture flags
ARCH_FLAGS := -march=rv32i -mabi=ilp32

# Compiler flags (Added -MMD -MP for automatic header dependencies)
CFLAGS := $(ARCH_FLAGS) -Os -Wall -Wextra -ffreestanding -nostartfiles -MMD -MP
CFLAGS += -I$(SW_INCLUDE_DIR)
CFLAGS += -I$(SW_DRIVERS_DIR)/gpio/include
CFLAGS += -I$(SW_DRIVERS_DIR)/timer/include
CFLAGS += -I$(SW_DRIVERS_DIR)/uart/include

ASFLAGS := $(ARCH_FLAGS) -MMD -MP
LDFLAGS := -T $(SW_DIR)/linker.ld -nostdlib -static -Wl,--gc-sections

export CFLAGS ASFLAGS LDFLAGS

# -------------------------------------------
# Source Files (Auto-discovery)
# -------------------------------------------

# Main application
SW_MAIN_C_SRCS := $(filter-out $(SW_SRC_DIR)/string.c, $(wildcard $(SW_SRC_DIR)/*.c))
SW_MAIN_S_SRCS := $(wildcard $(SW_SRC_DIR)/*.S)

# Driver sources (recursive into drivers/*/src)
SW_DRIVER_SRCS := $(wildcard $(SW_DRIVERS_DIR)/*/src/*.c)

# Test sources
SW_TEST_SRCS   := $(wildcard $(SW_TESTS_DIR)/*/*.c) $(wildcard $(SW_TESTS_DIR)/*.c)

# All sources
SW_ALL_SRCS    := $(SW_MAIN_C_SRCS) $(SW_MAIN_S_SRCS) $(SW_DRIVER_SRCS) $(SW_TEST_SRCS)

# Object files (mapped to build directory)
SW_MAIN_OBJS   := $(patsubst $(SW_DIR)/%.c, $(SW_BUILD_DIR)/%.o, $(SW_MAIN_C_SRCS)) \
                  $(patsubst $(SW_DIR)/%.S, $(SW_BUILD_DIR)/%.o, $(SW_MAIN_S_SRCS))

SW_DRIVER_OBJS := $(patsubst $(SW_DIR)/%.c, $(SW_BUILD_DIR)/%.o, $(SW_DRIVER_SRCS))
SW_TEST_OBJS   := $(patsubst $(SW_DIR)/%.c, $(SW_BUILD_DIR)/%.o, $(SW_TEST_SRCS))

SW_ALL_OBJS    := $(SW_MAIN_OBJS) $(SW_DRIVER_OBJS) $(SW_TEST_OBJS)

# -------------------------------------------
# Target Definitions
# -------------------------------------------

# Main firmware
FIRMWARE_ELF  := $(SW_BUILD_DIR)/firmware.elf
FIRMWARE_BIN  := $(SW_BUILD_DIR)/firmware.bin
FIRMWARE_HEX  := $(SW_BUILD_DIR)/firmware.hex
FIRMWARE_MAP  := $(SW_BUILD_DIR)/firmware.map
FIRMWARE_DUMP := $(SW_BUILD_DIR)/firmware.dump
FIRMWARE_MEM  := $(SW_BUILD_DIR)/firmware.mem
FIRMWARE_SYM  := $(SW_BUILD_DIR)/firmware.sym

# Test programs
GPIO_TEST_ELF        := $(SW_BUILD_DIR)/tests/gpio/gpio_test.elf
TIMER_TEST_ELF       := $(SW_BUILD_DIR)/tests/timer/timer_test.elf
UART_TEST_ELF        := $(SW_BUILD_DIR)/tests/uart/uart_test.elf
INTEGRATION_TEST_ELF := $(SW_BUILD_DIR)/tests/integration_test.elf

TEST_ELFS := $(GPIO_TEST_ELF) $(TIMER_TEST_ELF) $(UART_TEST_ELF) $(INTEGRATION_TEST_ELF)

# -------------------------------------------
# Build Rules
# -------------------------------------------

# Main firmware build
$(FIRMWARE_ELF): $(SW_MAIN_OBJS) $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@mkdir -p $(dir $@)
	$(Q)echo "  [LD]        $@"
	$(Q)$(CC) -Wl,-T$(SW_DIR)/linker.ld -nostdlib -static -Wl,--gc-sections -Wl,-Map=$(FIRMWARE_MAP) -o $@ $(SW_MAIN_OBJS) $(SW_DRIVER_OBJS) -lgcc
	@$(SIZE) $@

$(FIRMWARE_BIN): $(FIRMWARE_ELF)
	$(Q)echo "  [OBJCOPY]   $@"
	$(Q)$(OBJCOPY) -O binary $< $@

$(FIRMWARE_HEX): $(FIRMWARE_ELF)
	$(Q)echo "  [OBJCOPY]   $@"
	$(Q)$(OBJCOPY) -O ihex $< $@

$(FIRMWARE_DUMP): $(FIRMWARE_ELF)
	$(Q)echo "  [OBJDUMP]   $@"
	$(Q)$(OBJDUMP) -d $< > $@

$(FIRMWARE_MEM): $(FIRMWARE_HEX)
	$(Q)echo "  [HEX2MEM]   $@"
	$(Q)python3 $(TOP_DIR)/scripts/convert/hex2mem.py $< $@

$(FIRMWARE_SYM): $(FIRMWARE_ELF)
	$(Q)echo "  [NM]        $@"
	$(Q)$(NM) -n $< > $@

# Test program builds
$(GPIO_TEST_ELF): $(SW_BUILD_DIR)/tests/gpio/gpio_usage.o $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@mkdir -p $(dir $@)
	$(Q)echo "  [LD]        $@"
	$(Q)$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

$(TIMER_TEST_ELF): $(SW_BUILD_DIR)/tests/timer/timer_usage.o $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@mkdir -p $(dir $@)
	$(Q)echo "  [LD]        $@"
	$(Q)$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

$(UART_TEST_ELF): $(SW_BUILD_DIR)/tests/uart/uart_usage.o $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@mkdir -p $(dir $@)
	$(Q)echo "  [LD]        $@"
	$(Q)$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

$(INTEGRATION_TEST_ELF): $(SW_BUILD_DIR)/tests/integration_test.o $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@mkdir -p $(dir $@)
	$(Q)echo "  [LD]        $@"
	$(Q)$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

# Pattern rule for object files
$(SW_BUILD_DIR)/%.o: $(SW_DIR)/%.c
	@mkdir -p $(dir $@)
	$(Q)echo "  [CC]        $<"
	$(Q)$(CC) $(CFLAGS) -c $< -o $@

$(SW_BUILD_DIR)/%.o: $(SW_DIR)/%.S
	@mkdir -p $(dir $@)
	$(Q)echo "  [AS]        $<"
	$(Q)$(CC) $(ASFLAGS) -c $< -o $@

# Automatic inclusion of dependencies to recompile if a .h file is modified
-include $(SW_ALL_OBJS:.o=.d)

# -------------------------------------------
# Top-level Software Targets
# -------------------------------------------
.PHONY: sw.all sw.clean sw.firmware sw.test sw.drivers sw.info

sw.all: sw.firmware sw.test

sw.firmware: $(FIRMWARE_BIN) $(FIRMWARE_HEX) $(FIRMWARE_DUMP) $(FIRMWARE_MEM) $(FIRMWARE_SYM)
	$(Q)echo "  [SW]        Firmware build complete"

sw.test: $(TEST_ELFS)
	$(Q)echo "  [SW]        Test programs built:"
	$(Q)for test in $(TEST_ELFS); do \
		echo "              - $$test"; \
	done

sw.drivers: $(SW_DRIVER_OBJS)
	$(Q)echo "  [SW]        Driver objects built"

sw.clean:
	$(Q)echo "  [CLEAN]     Software artifacts"
	$(Q)rm -rf $(SW_BUILD_DIR)

sw.info:
	@echo "=================================================="
	@echo "Software Build Configuration"
	@echo "=================================================="
	@echo "  SW_DIR:          $(SW_DIR)"
	@echo "  SW_BUILD_DIR:    $(SW_BUILD_DIR)"
	@echo "  CROSS_COMPILE:   $(CROSS_COMPILE)"
	@echo "  Sources:         $(words $(SW_ALL_SRCS)) files"
	@echo "  Firmware output: $(FIRMWARE_BIN)"
	@echo "=================================================="

# -------------------------------------------
# Simulation Integration Targets
# -------------------------------------------
.PHONY: sw.firmware.for_sim

sw.firmware.for_sim: $(FIRMWARE_BIN)
	$(Q)echo "  [SW]        Copying firmware for simulation..."
	$(Q)cp $(FIRMWARE_BIN) $(SIM_BUILD_DIR)/firmware.bin
	$(Q)cp $(FIRMWARE_HEX) $(SIM_BUILD_DIR)/firmware.hex
	$(Q)echo "  [SW]        Firmware ready for simulation"