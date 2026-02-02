# Build System Guide

## Introduction
This document describes the build system for the Mini RV32I SoC software. The build system uses GNU Make to automate compilation, linking, and binary generation for the bare-metal RISC-V RV32I target.

## Build System Architecture

### Directory Structure
```text
MiniSoC_RV32I/
├── Makefile # Top-level entry point
├── build/ # Build artifacts directory
│ ├── sw/ # Software build outputs
│ │ ├── firmware.elf # ELF executable
│ │ ├── firmware.bin # Raw binary
│ │ ├── firmware.hex # Intel HEX format
│ │ ├── firmware.mem # Verilog memory format
│ │ ├── firmware.disasm # Disassembly listing
│ │ ├── firmware.map # Linker map file
│ │ └── tests/ # Test program outputs
│ └── sim/ # Simulation outputs
├── scripts/ # Build utilities
│ ├── setup/ # Setup scripts
│ └── convert/ # File format converters
├── sw/ # Software source
│ ├── include.sw.mk # Software build definitions
│ ├── linker.ld # Linker script
│ └── ... # Source code
└── src/ # Hardware sources
```


### Build System Components
```text
┌─────────────────────────────────────┐
│ Top-Level Makefile 				  │
│ • Orchestrates build process 		  │
│ • Includes sub-makefiles 			  │
│ • Defines common targets 			  │
├─────────────────────────────────────┤
│ Software Makefile (include) 		  │
│ • Compiler toolchain configuration  │
│ • Source file discovery 			  │
│ • Object file generation rules 	  │
│ • Linking and binary conversion 	  │
├─────────────────────────────────────┤
│ Hardware Makefile (include) 		  │
│ • RTL synthesis rules 			  │
│ • Simulation rules 				  │
│ • FPGA bitstream generation 		  │
└─────────────────────────────────────┘
```


## Toolchain Configuration

### Required Tools
| Tool 							| Purpose 			| Minimum Version 	|
|-------------------------------|-------------------|-------------------|
| `riscv32-unknown-elf-gcc` 	| C Compiler 		| 10.2.0 			|
| `riscv32-unknown-elf-as` 		| Assembler 		| 10.2.0 			|
| `riscv32-unknown-elf-ld` 		| Linker 			| 10.2.0 			|
| `riscv32-unknown-elf-objcopy` | Binary conversion | 10.2.0 			|
| `riscv32-unknown-elf-objdump` | Disassembly 		| 10.2.0 			|
| `riscv32-unknown-elf-size` 	| Memory usage 		| 10.2.0 			|
| `make` 						| Build automation 	| 3.81 				|
| `python3` (optional) 			| Script utilities 	| 3.6 				|

### Toolchain Installation

#### Option A: Package Manager (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install gcc-riscv64-unknown-elf
```


#### Option B: Build from Source
```bash
git clone --recursive https://github.com/riscv-collab/riscv-gnu-toolchain
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv --with-arch=rv32i --with-abi=ilp32
make -j$(nproc)
export PATH=/opt/riscv/bin:$PATH
```

### Toolchain Verification
```bash
# Verify installation
riscv32-unknown-elf-gcc --version
# Expected: riscv32-unknown-elf-gcc (GCC) 10.2.0

# Check architecture support
riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -dM -E - < /dev/null | grep -i riscv
# Should show RV32I support
```

## Build Configuration Files

### 1. Top-Level Makefile  (`Makefile`)
```makefile
# Central Makefile for MiniSoC-RV32I Project

.PHONY: all check_env help clean

# -------------------------------------------
# Configuration
# -------------------------------------------
TOP_DIR 			:= $(shell pwd)
BUILD_DIR 			?= $(TOP_DIR)/build
MINISOC_BUILD_DIR 	?= $(BUILD_DIR)/minisoc
export TOP_DIR BUILD_DIR MINISOC_BUILD_DIR


# -------------------------------------------
# Include Sub-Makefiles
# -------------------------------------------
include src/include.src.mk 
include sim/include.sim.mk 
include sw/include.sw.mk
include synth/include.synth.mk
include sim_minisoc/include.sim_minisoc.mk


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
```

### 2. Software Build Configuration (`sw/include.sw.mk`)
```makefile
# Software Build System
SW_DIR := $(TOP_DIR)/sw
SW_BUILD_DIR := $(BUILD_DIR)/sw
SW_SRC_DIR := $(SW_DIR)/src
SW_DRIVERS_DIR := $(SW_DIR)/drivers
SW_TESTS_DIR := $(SW_DIR)/tests
SW_INCLUDE_DIR := $(SW_DIR)/include

# Toolchain
CROSS_COMPILE ?= riscv32-unknown-elf-
CC := $(CROSS_COMPILE)gcc
AS := $(CROSS_COMPILE)as
LD := $(CROSS_COMPILE)ld
OBJCOPY := $(CROSS_COMPILE)objcopy
OBJDUMP := $(CROSS_COMPILE)objdump
SIZE := $(CROSS_COMPILE)size

# Architecture flags
ARCH_FLAGS := -march=rv32i -mabi=ilp32

# Compiler flags
CFLAGS := $(ARCH_FLAGS) -Os -Wall -Wextra -ffreestanding -nostartfiles
CFLAGS += -I$(SW_INCLUDE_DIR)
CFLAGS += -I$(SW_DRIVERS_DIR)/gpio/include
CFLAGS += -I$(SW_DRIVERS_DIR)/timer/include
CFLAGS += -I$(SW_DRIVERS_DIR)/uart/include

# Assembler flags
ASFLAGS := $(ARCH_FLAGS)

# Linker flags
LDFLAGS := -T $(SW_DIR)/linker.ld -nostdlib -static -Wl,--gc-sections
```


## Source File Organization

### Source File Discovery
```makefile
# Main application sources
SW_MAIN_SRCS := $(SW_SRC_DIR)/startup.S
SW_MAIN_SRCS += $(SW_SRC_DIR)/system.c
SW_MAIN_SRCS += $(SW_SRC_DIR)/memory.c
SW_MAIN_SRCS += $(SW_SRC_DIR)/peripheral.c
SW_MAIN_SRCS += $(SW_SRC_DIR)/math.c
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
```

### Object File Generation Rules
```makefile
# Pattern rule for .c files
$(SW_BUILD_DIR)/%.o: $(SW_DIR)/%.c
	@echo "[SW] Compiling: $<"
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Pattern rule for .S files
$(SW_BUILD_DIR)/%.o: $(SW_DIR)/%.S
	@echo "[SW] Assembling: $<"
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -c $< -o $@

# Generate object file lists
SW_MAIN_OBJS := $(patsubst $(SW_DIR)/%, $(SW_BUILD_DIR)/%, $(SW_MAIN_SRCS:.c=.o))
SW_MAIN_OBJS := $(SW_MAIN_OBJS:.S=.o)
SW_DRIVER_OBJS := $(patsubst $(SW_DIR)/%, $(SW_BUILD_DIR)/%, $(SW_DRIVER_SRCS:.c=.o))
SW_TEST_OBJS := $(patsubst $(SW_DIR)/%, $(SW_BUILD_DIR)/%, $(SW_TEST_SRCS:.c=.o))
```


## Build Targets

### Firmware Targets
```makefile
# Firmware ELF file
FIRMWARE_ELF := $(SW_BUILD_DIR)/firmware.elf
$(FIRMWARE_ELF): $(SW_MAIN_OBJS) $(SW_DRIVER_OBJS) $(SW_DIR)/linker.ld
	@echo "[SW] Linking firmware: $@"
	@mkdir -p $(dir $@)
	$(CC) $(LDFLAGS) -Wl,-Map=$(SW_BUILD_DIR)/firmware.map -o $@ \
		$(SW_MAIN_OBJS) $(SW_DRIVER_OBJS) -lgcc
	$(SIZE) $@

# Firmware binary
FIRMWARE_BIN := $(SW_BUILD_DIR)/firmware.bin
$(FIRMWARE_BIN): $(FIRMWARE_ELF)
	@echo "[SW] Creating binary: $@"
	$(OBJCOPY) -O binary $< $@

# Firmware HEX
FIRMWARE_HEX := $(SW_BUILD_DIR)/firmware.hex
$(FIRMWARE_HEX): $(FIRMWARE_ELF)
	@echo "[SW] Creating hex: $@"
	$(OBJCOPY) -O ihex $< $@

# Disassembly
FIRMWARE_DISASM := $(SW_BUILD_DIR)/firmware.disasm
$(FIRMWARE_DISASM): $(FIRMWARE_ELF)
	@echo "[SW] Creating disassembly: $@"
	$(OBJDUMP) -d $< > $@

# Verilog memory format
FIRMWARE_MEM := $(SW_BUILD_DIR)/firmware.mem
$(FIRMWARE_MEM): $(FIRMWARE_HEX)
	@echo "[SW] Converting HEX to MEM format: $@"
	@python3 $(TOP_DIR)/scripts/convert/hex2mem.py $< $@
```


### Test Program Targets
```makefile
# Test ELF files
GPIO_TEST_ELF := $(SW_BUILD_DIR)/tests/gpio/gpio_test.elf
TIMER_TEST_ELF := $(SW_BUILD_DIR)/tests/timer/timer_test.elf
UART_TEST_ELF := $(SW_BUILD_DIR)/tests/uart/uart_test.elf
INTEGRATION_TEST_ELF := $(SW_BUILD_DIR)/tests/integration_test.elf

# Build rules for tests
$(GPIO_TEST_ELF): $(SW_BUILD_DIR)/tests/gpio/gpio_usage.o $(SW_DRIVER_OBJS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

$(TIMER_TEST_ELF): $(SW_BUILD_DIR)/tests/timer/timer_usage.o $(SW_DRIVER_OBJS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

$(UART_TEST_ELF): $(SW_BUILD_DIR)/tests/uart/uart_usage.o $(SW_DRIVER_OBJS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)

$(INTEGRATION_TEST_ELF): $(SW_BUILD_DIR)/tests/integration_test.o $(SW_DRIVER_OBJS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(SW_DRIVER_OBJS) $(LDFLAGS)
```


### Convenience Targets 
```makefile
# Main software targets
.PHONY: sw.all sw.firmware sw.test sw.clean sw.info

sw.all: sw.firmware sw.test
	@echo "[SW] All software built successfully"

sw.firmware: $(FIRMWARE_BIN) $(FIRMWARE_HEX) $(FIRMWARE_DISASM) $(FIRMWARE_MEM)
	@echo "[SW] Firmware build complete"
	@echo "    Binary: $(FIRMWARE_BIN)"
	@echo "    Hex:    $(FIRMWARE_HEX)"
	@echo "    ELF:    $(FIRMWARE_ELF)"
	@echo "    Mem:    $(FIRMWARE_MEM)"

sw.test: $(GPIO_TEST_ELF) $(TIMER_TEST_ELF) $(UART_TEST_ELF) $(INTEGRATION_TEST_ELF)
	@echo "[SW] Test programs built"

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
```


## Build Process Details

### Step 1: Compilation
```text
Source files (.c, .S)
     ↓ (Compiler: riscv32-unknown-elf-gcc)
     ↓ Flags: -march=rv32i -mabi=ilp32 -Os -Wall
Object files (.o) in build/sw/
```


### Step 2: Linking
```text
Object files (.o) + linker.ld
     ↓ (Linker: riscv32-unknown-elf-ld)
     ↓ Flags: -T linker.ld -nostdlib -static
ELF executable (firmware.elf)
```


### Step 3: Binary Conversion
```text
ELF executable (firmware.elf)
     ↓ (Objcopy: riscv32-unknown-elf-objcopy)
     ↓ Format: binary, hex, etc.
Output files (.bin, .hex, .mem)
```


### Step 4: Memory Format Generation
```text
Intel HEX file (firmware.hex)
     ↓ (Python script: hex2mem.py)
Verilog memory format (firmware.mem)
```


## Build Output Files

### Generated Files in `build/sw/`

| File 				| Format 		| Purpose 						| Generated By 		|
|-------------------|---------------|-------------------------------|-------------------|
| `firmware.elf` 	| ELF 			| Executable with debug info 	| Linker 			|
| `firmware.bin` 	| Binary 		| Raw binary for loading 		| objcopy 			|
| `firmware.hex` 	| Intel HEX 	| Human-readable hex format 	| objcopy 			|
| `firmware.mem` 	| Verilog MEM	| Simulation memory image 		| hex2mem.py 		|
| `firmware.disam` 	| Text 			| Disassembly listing 			| objdump 			|
| `firmware.map` 	| Text 			| Linker Memory Map 			| Linker (Map) 		|
| `*.o*` 			| Object 		| Intermediate compiled objects | Compiler 			|


### Memory Usage Report
Running `make sw.firmware` produces:

```text
[SW] Linking firmware: build/sw/firmware.elf
   text    data     bss     dec     hex filename
   1856     256     128    2240     8c0 build/sw/firmware.elf
```

- **text**: Code size in IMEM (bytes)
- **data**: Initialized data size (bytes)
- **bss**: Zero-initialized data size (bytes)
- **dec/hex**: Total size in decimal/hex


## Troubleshooting

### Common Issues and Solutions

#### Issue: "riscv32-unknown-elf-gcc: command not found"
**Solution**:

```bash
# Check if toolchain is installed
which riscv32-unknown-elf-gcc

# If not found, install or set PATH
export PATH=/opt/riscv/bin:$PATH
# Or specify full path
make CROSS_COMPILE=/opt/riscv/bin/riscv32-unknown-elf-
```

#### Issue: "Error: selected processor does not support mul"
**Solution**: RV32I doesn't have hardware multiply. Use software math functions:
```c
// Instead of: a * b
// Use: system_mul32(a, b)
```


#### Issue: "undefined reference to _estack or _sdata"
**Solution**: Check linker script and startup code alignment:
```bash
# Verify symbols exist
riscv32-unknown-elf-nm build/sw/firmware.elf | grep -E "_estack|_sdata|_edata"

# Check linker script includes these symbols
# In sw/linker.ld:
# _estack = .;  # Stack top
# _sdata = .;   # Data start
```


#### Issue: "DMEM overflow" or "section .text will not fit"
**Solution**: Reduce code/data size:

1. Enable optimization: `make CFLAGS_EXTRA="-Os"`
2. Remove unused code: Ensure `-Wl,--gc-sections` is used
3. Increase memory in linker script (if hardware supports)
4. Optimize data structures


#### Issue: Build artifacts not updating
**Solution**: Clean and rebuild:
```bash
make sw.clean
make sw.firmware
```