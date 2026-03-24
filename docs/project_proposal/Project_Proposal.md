# Project Proposal : MiniSoC-RV32I

## Project Title: 

### **"MiniSoC-RISC32I:  A Learning-Oriented RISC-V SoC with Wishbone Interconnect and Industrial Bare-Metal Stack"**


## Objective

To design, implement, and verify a synthesizable RISC-V based System-On-Chip (SoC) using Verilog, paired with a robust bare-metal C software stack. The project aims to provide a clean, modular architecture with an open interconnect (Wishbone B4) tailored for educational purposes, hardware/software co-design, and real-world FPGA/ASIC readiness.


## Project Scope

The SoC will contain:

-   A **custom RV32I CPU core** (5-stage pipeline, forwarding unit, static branch prediction).

-   **Memory Subsystem**: 
    -   Instruction memory (IMEM) and data memory (DMEM).
    -   Hardware Bootloader (`mem_init`) for automated firmware loading.

-   A Wishbone B4 Pipelined Interconnect mapping a unified address space.

-   **Memory-mapped peripherals**:
    -   **UART**: Configurable baud rate, 8N1, metastability protection.
    -   **Timer**: 32-bit counter, prescaler, system timebase provider.
    -   **GPIO**: 8-bit bidirectional, hardware-accelerated atomic operations (SET/CLEAR/TOGGLE).

-   An **Industrial-Grade Software Stack**:
    -   Written in C adhering to the **Barr Group Embedded C Coding Standard**.
    -   Object-Oriented Programming (OOP) patterns for drivers (inheritance via `peripheral_t`).
    -   Zero-dynamic-allocation (no `malloc`) and strict memory safety (`system_validate_address`).

-   A **Simulation environment**: `iverilog` and `gtkwave` testbenches.


## Learning Outcomes

-   Deep understanding of **pipelined CPU design** (RV32I) and hazard resolution.
-   Practical experience in **Wishbone bus protocol** (Pipelined transactions).
-   Implementing **Hardware/Software Co-design** (e.g., hardware atomic registers to avoid software Read-Modify-Write bugs).
-   Writing robust **Bare-Metal C Firmware** (custom linker scripts, startup assembly, shadow caching).
-   Structuring a **scalable, synthesis-ready digital hardware** project (clock domain management, synchronized multi-stage reset tree).


## Design Constraints

-   **Verilog-2001**: SystemVerilog avoided for maximal toolchain compatibility and simplicity.
-   **FPGA/ASIC Ready**: Uses generic Verilog constructs, explicit synchronization (double-flop synchronizers on inputs), and physical I/O pads (`inout` tristate buffers).
-   **Toolchain**: `iverilog`, `gtkwave`, `yosys`, `riscv32-unknown-elf-gcc`, `make`, `python3`


## Out-of-Scope Features

-   **Hardware Interrupts (IRQs) and Exceptions**: The system relies entirely on software polling and deterministic state machines (timeout loops) to handle events and errors.
-   **Compressed Instructions**: No RV32C extension.
-   **Advanced CPU Features**: No MMU, no caches (direct SRAM access), no privilege levels (Machine mode only).
