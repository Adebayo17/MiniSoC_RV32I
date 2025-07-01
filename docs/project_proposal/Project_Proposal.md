# Project Proposal : RISC-V Mini SoC

## Project Title: 

### **"MiniSoC-RISC32I: A Learning-Oriented RISC-V SoC  with Wishbone Interconnect"**

## Objective

To design and implement a synthesizable and simulation-ready RISC-V based System-On-Chip (SoC) using Verilog, with a clean modular architecture and open interconnect (Wishbone), tailored for educational purposes.

## Project Scope

The SoC will contain:
-   A **custom RV32I CPU core** written in Verilog
-   **Memory modules**: instruction memory (IMEM), data memory (DMEM)
-   **Memory-mapped peripherals**:
    -   UART
    -   Timer
    -   GPIO (8-bit input/output)
-   A **Wishbone bus interconnect**
-   A **testbench-driver simulation environment** with Iverilog and GTKWave

## Learning Outcomes

-   Deep understanding of **CPU design** (RV32I)
-   Practical experience in **Wishbone bus protocol**
-   Implementing and verifying **memory-mapped I/O**
-   Writing and integrating basic peripherals
-   Structuring a **scalable digital hardware** project

## Design Constraints

-   Verilog-only (SystemVerilog avoided for simplicity)
-   100% simulation-friendly (no FPGA/ASIC integration yet)
-   Toolchain: `iverilog`, `gtkwave`, `yosys`, `riscv32-unknown-elf-gcc`

## Out-of-Scope Features

-   Interrupts, traps, and exceptions
-   Compressed instructions (RV32C)
-   MMU, cache, privilege levels
