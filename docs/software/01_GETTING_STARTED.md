# Getting Started with Mini RV32I SoC Software

## Overview
Welcome to the Mini RV32I SoC software development guide. This document provides everything you need to start developing bare-metal firmware for the custom Mini RV32I system-on-chip.

Since this is a strict bare-metal environment (no OS, no standard C library, no hardware interrupts), the software stack is built with high reliability in mind, adhering to the **Barr Group Embedded C Coding Standard**.

## Prerequisites

### 1. Software Requirements
- **RISC-V 32-bit Toolchain**: GCC compiler for RV32I architecture.
- **Make**: Build automation tool (version 3.81 or later).
- **Python 3**: For memory generation scripts (HEX/MEM conversion).
- **Git**: Version control (recommended).

### 2. Hardware Understanding
Familiarity with:
- RISC-V RV32I instruction set.
- Bare-metal C programming (pointers, volatile keywords).
- Memory-mapped I/O concepts.
- Wishbone bus protocol (basic understanding).
- *Note: This SoC does not implement interrupts (IRQs). All peripheral management relies on status polling.*


---

## Quick Installation Guide

### Option A: Ubuntu/Debian (Recommended)
You can use the standard 64-bit RISC-V toolchain package. Our Makefile automatically passes the `-march=rv32i -mabi=ilp32` flags to force 32-bit compilation.

```bash
# Update and install the RISC-V toolchain and make
sudo apt-get update
sudo apt-get install gcc-riscv64-unknown-elf make python3

# Clone the repository
git clone [https://github.com/Adebayo17/MiniSoC_RV32I.git](https://github.com/Adebayo17/MiniSoC_RV32I.git)
cd MiniSoC_RV32I

# Verify installation (Check that the compiler is accessible)
riscv64-unknown-elf-gcc --version
```

### Option B: Manual Toolchain Installation (Build from source)
```bash
# Download and build RISC-V toolchain tailored exactly for rv32i
git clone --recursive [https://github.com/riscv-collab/riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv --with-arch=rv32i --with-abi=ilp32
make -j$(nproc)

# Add to PATH
export PATH=/opt/riscv/bin:$PATH
echo 'export PATH=/opt/riscv/bin:$PATH' >> ~/.bashrc
```


---

## Project Structure Overview
```text
MiniSoC_RV32I/
├── sw/                         # Software source code
│   ├── include/                # System-wide headers
│   │   ├── errors.h            # Standardized system_error_t codes
│   │   ├── system.h            # Memory map and timebase API
│   │   ├── memory.h            # Safe memcopy/memset routines
│   │   ├── peripheral.h        # Base OOP structure for drivers
│   │   └── register_access.h   # Safe bitwise macros (SET, CLEAR)
│   ├── src/                    # Core system implementation
│   │   ├── startup.S           # Assembly boot code (Stack & PC setup)
│   │   ├── system.c            # Validation and delay logic
│   │   └── main.c              # Main application entry point
│   ├── drivers/                # Hardware Abstraction Layer (HAL)
│   │   ├── gpio/               # GPIO Driver (gpio.h, gpio_hw.h, gpio.c)
│   │   ├── timer/              # Timer Driver
│   │   └── uart/               # UART Driver
│   ├── tests/                  # Integration and Unit tests
│   └── linker.ld               # Memory layout definition (IMEM/DMEM)
├── docs/software/              # Documentation
├── sim/                        # Verilog Simulation testbenches
└── Makefile                    # Top-level build control
```


---

## Your First Build

### 1. Build the Firmware
```bash
# Navigate to project root
cd MiniSoC_RV32I

# Build th complete software stack (Application)
make sw.firmware
```

**Expected Output:**
```text
  [LD]        MiniSoC_RV32I/build/sw/firmware.elf
   text	   data	    bss	    dec	    hex	filename
  13858	      4	   8288	  22150	   5686	MiniSoC_RV32I/build/sw/firmware.elf
  [OBJCOPY]   MiniSoC_RV32I/build/sw/firmware.bin
  [OBJCOPY]   MiniSoC_RV32I/build/sw/firmware.hex
  [OBJDUMP]   MiniSoC_RV32I/build/sw/firmware.dump
  [HEX2MEM]   MiniSoC_RV32I/build/sw/firmware.mem
Success: Converted MiniSoC_RV32I/build/sw/firmware.hex to MiniSoC_RV32I/build/sw/firmware.mem
  [NM]        MiniSoC_RV32I/build/sw/firmware.sym
  [SW]        Firmware build complete
```
*Note: The `.mem` and `.hex` files are automatically generated. They are used by the Verilog testbenches to initialize the simulated ROM (IMEM).*


### 2. Run the Test Suite
```bash
# Compile the bare-metal tests to ensure drivers are working
make sw.test

```

**Expected Output:**
```text
  [SW]      Test programs built:
            - MiniSoC_RV32I/build/sw/tests/gpio/gpio_test.elf
            - MiniSoC_RV32I/build/sw/tests/timer/timer_test.elf
            - MiniSoC_RV32I/build/sw/tests/uart/uart_test.elf
            - MiniSoC_RV32I/build/sw/tests/integration_test.elf
```

---

## Your First application

### Understanding the Standard
This project enforces a strict coding standard. Functions returning `system_error_t` must be checked using `is_success()` or `is_error()`. Hardware addresses are hidden behind the Driver APIs.


### Creating a Simple Blink Application
Create or overwrite `sw/src/main.c` with the following Barr Group-compliant code:

```c
#include "system.h"
#include "errors.h"
#include "gpio.h"
#include "timer.h"

int main(void) 
{
    system_error_t status = SYSTEM_SUCCESS;
    gpio_t gpio_dev;
    timer_t timer_dev;
    
    /* 1. Initialize system essentials */
    system_init();
    
    /* 2. Initialize Peripherals */
    status = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    
    if (is_success(status)) 
    {
        status = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    }
    
    /* 3. Configure Pin 0 as Output */
    if (is_success(status)) 
    {
        gpio_pin_config_t config;
        config.pin = GPIO_PIN_0;
        config.direction = GPIO_DIR_OUTPUT;
        config.initial_value = false;
        
        status = gpio_configure_pin(&gpio_dev, &config);
    }
    
    /* 4. Error Trap */
    if (is_error(status)) 
    {
        /* Infinite loop to halt the CPU on initialization failure */
        while(1) { }
    }
    
    /* 5. Main Superloop */
    while(1) 
    {
        (void)gpio_toggle_pin(&gpio_dev, GPIO_PIN_0);
        
        /* Safe blocking delay (requires the Timer to be running) */
        (void)system_delay_ms_safe(500U);  
    }
    
    return 0;
}
```

---

## Development Workflow

### Typical Development Cycle
1. **Edit** your C code in `sw/src` or `sw/drivers`.
2. **Build** with `make sw.firmware`.
3. **Test** with `make sw.test`
4. **Simulate** by switching to your hardware simulation tool (e.g., `make sim` or running Icarus Verilog), which will load the newly generated `firmware.mem`.
5. **Debug** using generated files (like `build/sw/firmware.disasm` to view the compiled assembly).


### Useful Debugging Commands
```bash
# Check memory usage per section
riscv64-unknown-elf-size build/sw/firmware.elf

# Examine the symbol table (useful to find where functions are placed)
riscv64-unknown-elf-nm build/sw/firmware.elf | grep main
```

## Common Issues and Solutions

### Issue: "riscvXX-unknown-elf-gcc: command not found"
**Solution**: The compiler is not in your PATH. If you installed manually in `/opt/riscv`, export it:

```bash
export PATH=/opt/riscv/bin:$PATH
```

*Note: Depending on your OS, the prefix might be `riscv64` or `riscv32`. Check your Makefile's CROSS_COMPILE variable.*


### Issue: "Error: DMEM overflow!"
**Solution**: Your code's variables (`.data` + `.bss` + Heap + Stack) exceed the available 16KB DMEM.

1. Reduce the size of global arrays or buffers.
2. Check `sw/include/system.h` and `sw/linker.ld` if you recently upgraded the physical memory in Verilog but forgot to update the software limits.


### Issue: The code compiles, but does nothing in simulation
**Solution:** Since there is no debugger attached to the Verilog simulation, check the `verification_canary` at the start of `main.c`. If your stack overflows into the `.data` section, the canary is corrupted, and the system triggers a `system_reset()`.

---

## Next Steps

### Recommended Learning Path

1. **Understand the Architecture**: Read [02_ARCHITECTURE_OVERVIEW.md](./02_ARCHITECTURE_OVERVIEW.md) to grasp the OOP concepts applied here.
2. **Study Memory Layout**: Read [03_MEMORY_MAP.md](./03_MEMORY_MAP.md).
3. **Explore Error Handling**: Learn how to write safe code in [08_ERROR_HANDLING.md](./08_ERROR_HANDLING.md).


### Hands-On Exercices
1. Modify the blink rate in the example above (e.g., fast blink, slow blink).
2. Add the UART driver to print `"Hello World!\r\n"` on boot.
3. Implement a **non-blocking delay** using `system_delay_us_start_safe()` and a state machine, allowing the CPU to read the UART while the LED blinks.
