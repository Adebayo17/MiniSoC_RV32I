# Getting Started with Mini RV32I SoC Software

## Overview
Welcome to the Mini RV32I SoC software development guide. This document provides everything you need to start developing bare-metal firmware for the Mini RV32I system-on-chip.

## Prerequisites

### 1. Software Requirements
- **RISC-V 32-bit Toolchain**: GCC compiler for RV32I architecture
- **Make**: Build automation tool (version 3.81 or later)
- **Python 3**: For build scripts (optional)
- **Git**: Version control (recommended)

### 2. Hardware Understanding
Familiarity with:
- RISC-V RV32I instruction set
- Bare-metal C programming
- Memory-mapped I/O concepts
- Wishbone bus protocol (basic understanding)

## Quick Installation Guide

### Option A: Ubuntu/Debian (Recommended)
```bash
# Install RISC-V toolchain
sudo apt-get update
sudo apt-get install gcc-riscv64-unknown-elf

# Clone the repository
git clone https://github.com/your-org/MiniSoC_RV32I.git
cd MiniSoC_RV32I

# Run setup script
./scripts/setup/setup.sh

# Verify installation
make sw.info
```

### Option B: Manual Toolchain Installation
```bash
# Download and build RISC-V toolchain
git clone --recursive https://github.com/riscv-collab/riscv-gnu-toolchain
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv --with-arch=rv32i --with-abi=ilp32
make -j$(nproc)

# Add to PATH
export PATH=/opt/riscv/bin:$PATH
echo 'export PATH=/opt/riscv/bin:$PATH' >> ~/.bashrc
```

## Project Structure Overview
```text
MiniSoC_RV32I/
├── sw/                    # Software source code
│   ├── include/          # System headers (errors.h, system.h, etc.)
│   │   ├── errors.h      # Error codes and handling
│   │   ├── system.h      # System-wide definitions
│   │   ├── memory.h      # Memory access functions
│   │   ├── math.h        # Software math routines
│   │   ├── peripheral.h  # Peripheral base structure
│   │   └── register_access.h # Register access macros
│   ├── src/             # Core system implementation
│   │   ├── startup.S    # Boot and initialization
│   │   ├── system.c     # System functions
│   │   ├── memory.c     # Memory operations
│   │   ├── main.c       # Example application
│   │   └── ...
│   ├── drivers/         # Peripheral drivers
│   │   ├── uart/        # UART driver
│   │   ├── gpio/        # GPIO driver
│   │   └── timer/       # Timer driver
│   ├── tests/           # Test applications
│   │   ├── gpio/        # GPIO tests
│   │   ├── timer/       # Timer tests
│   │   ├── uart/        # UART tests
│   │   └── integration_test.c # Combined tests
│   └── linker.ld        # Memory layout definition
├── docs/software/       # This documentation
│   ├── 01_GETTING_STARTED.md    # You are here
│   ├── 02_ARCHITECTURE_OVERVIEW.md
│   ├── 03_MEMORY_MAP.md
│   └── ...
├── src/                # Hardware RTL sources
├── sim/                # Simulation testbenches
├── scripts/            # Build and utility scripts
└── Makefile           # Top-level build control
```

## Your First Build

### 1. Build the Firmware
```bash
# Navigate to project root
cd MiniSoC_RV32I

# Build complete software stack
make sw.all

# Or build just the firmware
make sw.firmware
```

**Expected Output**
```text
[SW] Linking firmware: build/sw/firmware.elf
   text    data     bss     dec     hex filename
   1856     256     128    2240     8c0 build/sw/firmware.elf

[SW] Firmware build complete
    Binary: build/sw/firmware.bin
    Hex:    build/sw/firmware.hex
    ELF:    build/sw/firmware.elf
    Mem:    build/sw/firmware.mem
```

### 2. Run the Test Suite
```bash
# Build and verify all tests
make sw.test

# Expected: Test programs compiled without errors
```

## Your First application

### Understanding the Default Application
The default application (`sw/src/main.c`) demonstrates:
- System initialization
- Peripheral driver usage (UART, GPIO, TIMER)
- Error handling
- Timer management


### Creating a Simple Blink Application
Create a new file `sw/src/blink.c`:

```c
#include "../include/system.h"
#include "../drivers/gpio/include/gpio.h"

int main(void) {
    gpio_t gpio_dev;
    
    // Initialize system
    system_init();
    
    // Initialize GPIO
    if (gpio_init(&gpio_dev, GPIO_BASE_ADDRESS) != SYSTEM_SUCCESS) {
        // Handle error - blink rapidly
        while(1) {
            // Error pattern
        }
    }
    
    // Configure pin 0 as output
    gpio_pin_config_t config = {
        .pin = GPIO_PIN_0,
        .direction = GPIO_DIR_OUTPUT,
        .initial_value = false
    };
    gpio_configure_pin(&gpio_dev, &config);
    
    // Blink loop
    while(1) {
        gpio_toggle_pin(&gpio_dev, GPIO_PIN_0);
        system_delay_ms(500);  // 500ms delay
    }
    
    return 0;
}
```

### Building Your Custom Application
```bash
# Method 1: Replace main.c
cp blink.c sw/src/main.c
make sw.firmware

# Method 2: Add to build system (advanced)
# Edit sw/include.sw.mk to add your source file
```

## Simulation and Testing

### 1. Software Simulation 
```bash
# Build firmware for simulation
make sw.firmware.for_sim

# This creates firmware.mem in sim/build/
```

### 2. Running in Verilog Simulation
```bash
# Using Icarus Verilog (if configured)
make sim

# Or manually
cd sim
iverilog -o minisoc_tb .../top/tb_minisoc_c_firmware.v
vvp minisoc_tb
```

## Development Workflow

### Typical Development Cycle
1. **Edit** your C code in `sw/src` or `sw/drivers`
2. **Build** with `make sw.firmware`
3. **Test** with `make sw.test`
4. **Simulate** with `make sim` (hardware simulation)
5. **Debug** using generated files (`firmware.disam`, etc.)


### Debugging Tools
```bash
# Generate disassembly
make sw.firmware  # Creates firmware.disasm

# Check memory usage
riscv32-unknown-elf-size build/sw/firmware.elf

# Examine symbol table
riscv32-unknown-elf-nm build/sw/firmware.elf | grep main
```

## Common Issues and Solutions

### Issue: "riscv32-unknown-elf-gcc: command not found"

**Solution**: Install RISC-V toolchain or set PATH:
```bash
export PATH=/opt/riscv/bin:$PATH
# Or specify full path in Makefile
make CROSS_COMPILE=/opt/riscv/bin/riscv32-unknown-elf-
```

### Issue: "Error: DMEM overflow!"

**Solution**: Your code is too large. Options:
1. Optimize code size with `-Os` flag
2. Reduce data usage
3. Modify memory layour in `sw/linker.ld`


### Issue: "undefined reference to `_estack`"

**Solution**: Ensure your startup code matches linker script symbols:
```assembly
# In startup.S
la sp, _estack  # Correct
# Not: la sp, __stack or la sp, stack_top
```


## Next Steps

### Recommended Learning Path

1. **Understand the Architecture**: Read [02_ARCHITECTURE_OVERVIEW.md](./02_ARCHITECTURE_OVERVIEW.md)
2. **Study Memory Layout**: Read [03_MEMORY_MAP.md](./03_MEMORY_MAP.md)
3. **Learn Build System**: Read [04_BUILD_SYSTEM.md](./04_BUILD_SYSTEM.md)
4. **Explore Drivers**: Check [06_DRIVERS/](./06_DRIVERS/)
5. **Try Examples**: See [08_EXAMPLES_TESTS.md](./08_EXAMPLES_TESTS.md)


### Hands-On Exercices
1. Modify the blink rate in the example
2. Add UART output to print "Hello World!"
3. Create a timer-based interrupt handler (advanced)
4. Implement a simple command-line interface over UART



## Getting Help 

### Documentation Resources
- [Architecture Overview](./02_ARCHITECTURE_OVERVIEW.md)
- [API Reference](./06_DRIVERS/)
- [Memory Map](./03_MEMORY_MAP.md)
- [Build system](./04_BUILD_SYSTEM.md)


### Code Examples
- `sw/src/main.c` - Complete example application
- `sw/tests/` - Various test programs
- `sw/drivers/` - Driver implementation examples


### Tool References
- [RISC-V GNU Toolchain Documentation](https://github.com/riscv-collab/riscv-gnu-toolchain)
- [GNU Make Manual](https://www.gnu.org/software/make/manual/)
