# Mini RV32I SoC - Software Documentation

## Overview
Welcome to the software documentation for the Mini RV32I SoC. This directory contains the details of the Hardware Abstraction Layer (HAL), device drivers, and the "Bare-Metal" build system designed to run on the custom RISC-V core.

## Design Philosophy
The software stack is written with industrial-grade quality requirements in mind, strictly adhering to the Barr Group Embedded C Coding Standard.
It is designed to be 100% memory-safe, free of dangerous hidden macros, and highly modular through an Object-Oriented Programming (OOP) approach in pure C.

## Quick Navigation

### 1. Getting Started & Architecture
- **[Getting Started](01_GETTING_STARTED.md)**              - Prerequisites, toolchain setup, and step-by-step guides.
- **[Architecture Overview](02_ARCHITECTURE_OVERVIEW.md)**  -  OOP model (`peripheral_t` inheritance), Hardware/Software separation, and coding conventions.
- **[Diagrams](../diagrams/)**                              - Visual documentation of the software stack.

### 2. Memory & Build System
- **[Memory Map](03_MEMORY_MAP.md)**                        - RAM layout (IMEM/DMEM) and Memory-Mapped I/O (MMIO) addresses.
- **[Build System](04_BUILD_SYSTEM.md)**                    - Makefile structure and hex binary generation for Verilog Simulation.
- **[Linker Script](05_LINKER_SCRIPT.md)**                  - Memory layout and `.text`, `.data`, `.bss` sections placement.
- **[Boot Process](06_BOOT_PROCESS.md)**                    - Firmware startup execution.

### 3. Device Drivers & API
- **[System & Memory API](07_DRIVERS/01_SYSTEM_API.md)**    - Software math functions (`math.c`) and safe memory management (`memory.c`)
- **[UART Driver](07_DRIVERS/02_UART_DRIVER.md)**           - Serial communication.
- **[TIMER Driver](07_DRIVERS/03_TIMER_DRIVER.md)**         - Timebase, blocking and non-blocking delays.
- **[GPIO Driver](07_DRIVERS/04_GPIO_DRIVER.md)**           - I/O control and hardware atomic operations.

### 4. Robustness & Validation
- **[Error Handling](08_ERROR_HANDLING.md)**                - `system_error_t` propagation and safe error handling.
- **[API Examples & Tests](09_EXAMPLES_TESTS.md)**          - Unit and integration tests usage.

### 5. Guides
- **[RISC-V Toolchain & Compiler Guide](10_TOOLCHAIN_GUIDE.md)**


## Building the Software

```bash
# Navigate to project root
cd MiniSoC_RV32I

# Build all firmware and tests
make sw.all

# Build specific firmware only
make sw.firmware

# Run software integration tests
make sw.test
```