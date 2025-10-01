#  RISC-V Toolchain Guide: ELF vs Linux-GNU for Embedded Systems

## Introduction
During the development of the MiniSoC-RV32I project, I encountered linker errors that revealed important differences between RISC-V toolchain variants. This document explains the distinction between `riscv32-unknown-elf-` and `riscv32-unknown-linux-gnu-` toolchains and why the choice matters for bare-metal embedded systems.

---

## The Problem Encountered
When building firmware for our MiniSoC, we faced linking errors:

```text
can't link double-float modules with soft-float modules
undefined reference to `__muldi3', `__udivdi3'
```

These errors occured because **our bare-metal RV32I system** (soft-float, no OS) was using a **Linux-oriented toolchain** with incompatible ABI assumptions.

---

## Toolchain Variants Explained

### 1. `riscv32-unknown-elf-` **(Bare-metal/Embedded)**

**Target Environment:** Systems without any operating system

- **ABI**: `ilp32` (Integer, Long, Pointer = 32-bit, soft-float)
- **C Library**: newlib or picolibc (minimal, embedded-focused)
- **Startup**: Custom startup code (startup.S) handles initialization
- **System Calls**: None available - you implement what you need
- **Linking**: Static only, no dynamic libraries
- **Use Case**: Microcontrollers, custom SoCs, embedded systems

### 2. `riscv32-unknown-linux-gnu-` **(Linux Systems)**

**Target Environment:** Linux operating system

- **ABI**: `ilp32d` or `ilp32f` (with hardware floating-point)
- **C Library**: glibc (full-featured, Linux-dependent)
- **Startup**: Linux dynamic loader handles initialization
- **System Calls**: Full POSIX support (open, read, write, etc.)
- **Linking**: Supports dynamic libraries
- **Use Case**: Applications running on RISC-V Linux

---

## Technical Comparison

| Aspect                | ELF Toolchain         | Linux-GNU Toolchain       |
|-----------------------|-----------------------|---------------------------|
| **Target**            | Bare-metal            | Linux OS                  |
| **Default ABI**       | `ilp32` (soft-float)  | `ilp32d/f`(hard-float)    |
| **C Library**         | newlib/picolibc       | glibc                     |
| **Startup Code**      | Custom `startup.C`    | OS Loader                 |
| **System Calls**      | None                  | POSIX Compliant           |
| **Memory Usage**      | Minimal               | Larger footprint          |
| **Dependencies**      | None                  | Linux Kernel              |

---

## Why It Matters for MiniSoC-RV32I

Our system has these characteristics that make elf toolchain essential:

1. **Noo Operating System**

```asm
// Our startup sequence (startup.S)
_start:
    la sp, _estack    // Setup stack pointer
    // Clear .bss section
    // Copy .data from ROM to RAM  
    call main         // Jump to application
```

2. **Memory Constraints**

- IMEM: 8KB instruction memory
- DMEM: 4KB data memory
- No room for Linux runtime overhead

3. **Custom Peripherals**

```c
// We access hardware directly
#define UART_BASE_ADDRESS 0x20000000U
WRITE_REG(UART_BASE_ADDRESS, data);  // Memory-mapped I/O
```

4. **Soft-float Requirement**
Our RV32I core has no floating-point unit so we need soft-float ABI.