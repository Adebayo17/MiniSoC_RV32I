# 08. RISC-V Toolchain & Compiler Guide

## 1. Introduction

During the development of bare-metal projects like the MiniSoC-RV32I, configuring the compiler is just as critical as writing the code itself.

This document explains two major concepts that often trip up embedded developers on RISC-V:

1. The difference between `unknown-elf` and `linux-gnu` toolchains.

2. How the compiler handles missing hardware features (like the `M` extension) using invisible software fallbacks (`libgcc`).

---

## 2. Toolchain Variants: ELF vs Linux-GNU

When downloading or building a RISC-V GCC toolchain, you will generally face two main variants. Choosing the wrong one will lead to severe linker errors *(e.g., undefined reference to standard functions, incompatible ABIs, or massive binary bloat)*.

### 2.1 `riscv32-unknown-elf-` **(Bare-metal/Embedded)**

**Target Environment:** Systems without any operating system (like our MiniSoC).

- **ABI (Application Binary Interface)**: Typically `ilp32` (Integer, Long, Pointer = 32-bit, soft-float)
- **C Library**: Uses `newlib` or `picolibc` (minimal, embedded-focused librairies).
- **Startup**: Expects a custom startup code (`startup.S`) to initialize the stack and RAM.
- **System Calls**: None available. `printf`, `malloc`, or file I/O operations will fail unless you explicitly implement lower-level hooks (like `_write` routing to your UART).
- **Linking**: Static linking only, no dynamic libraries.
- **Use Case**: Microcontrollers, custom SoCs, and strict bare-metal systems.

### 2.2 `riscv32-unknown-linux-gnu-` **(Linux Systems)**

**Target Environment:** Systems running a full Linux OS kernel.

- **ABI**: Typically `ilp32d` or `ilp32f` (Hardware double-precision floating-point expected).
- **C Library**: Uses `glibc` (full-featured, heavily dependent on Linux).
- **Startup**: Expects the Linux dynamic loader to handle initialization before calling `main()`.
- **System Calls**: Expects full POSIX support from an underlying OS kernel.
- **Linking**: Supports dynamic libraries.
- **Use Case**:Applications running on Raspberry Pi-like RISC-V boards or Linux emulators.

### 2.3 Why the MiniSoC demands the `elf` toolchain

Our architecture imposes strict limitations:

1. **No Operating System**: We jump straight from hardware reset to `startup.S`. There is no OS to handle dynamic linking or `glibc` initialization.

2. **Memory Constraints**: We only have 32 KB of IMEM and 16 KB of DMEM. `glibc` overhead would instantly overflow this memory.

3. **No Hardware Float**: Our CPU is purely integer-based.

---

## 3. The "Missing M-Extension" Phenomenon

The MiniSoC implements the **RV32I** base instruction set. It does not include the `M` extension (Hardware Multiply/Divide).

### 3.1 The Mystery of `__muldi3` and `__udivdi3`

If you write standard C code using the multiplication * or division / operators, the code will compile perfectly. However, if you inspect the generated binary or encounter linker errors, you might notice strange function names appearing out of nowhere, such as `__mulsi3`, `__muldi3`, or `__udivdi3`.

**Example in `timer.c`:**
```c
/* This line seems innocent... */
uint64_t ticks64 = ((uint64_t)timeout_us * (uint64_t)timer_freq) / 1000000ULL;
```

**What happens under the hood:**
1. GCC looks at the target architecture flag (`-march=rv32i`).

2. It realizes the CPU does not have a `mul` or `div` hardware instruction.

3. To prevent crashing the CPU with an "Illegal Instruction" exception, GCC automatically replaces the `*` and `/` operators with function calls to its internal math library, called `libgcc`.

4. Because the operands were cast to `uint64_t` (64-bit), GCC injects calls to `__muldi3` (Double Integer Multiply) and `__udivdi3` (Unsigned Double Integer Divide).

### 3.2 Bare-Metal Architectural Decisions

In an industrial bare-metal environment, relying on implicit `libgcc` calls can be problematic:

- **Non-Deterministic Timing**: You don't know exactly how many clock cycles the division will take, which is bad for real-time systems.

- **Code Size**: Linking `libgcc` can silently bloat the binary.

**The MiniSoC Solution:**
To maintain 100% transparency and control over the execution, this project avoids using standard `*` and `/` operators.

Instead, the codebase provides explicit software implementations in `sw/src/math.c` (`system_umul32`, `system_udiv32`, `system_umul64`).

If you are developing a driver for this SoC:

```c
/* AVOID: Will inject hidden libgcc dependencies */
uint32_t baud_divider = SYSTEM_CLOCK_FREQ / config->baudrate;

/* PREFERRED: Explicit software math call (Barr Group compliant) */
uint32_t baud_divider = system_udiv32(SYSTEM_CLOCK_FREQ, config->baudrate);
```

### 3.3 Linking `libgcc` (If strictly necessary)

If you decide to allow standard operators and rely on the compiler's fallbacks, you must ensure your Makefile links the compiler's internal math library. This is done by adding `-lgcc` to your linker command:

```makefile
# In sw/include.sw.mk
LDFLAGS += -lgcc
```

*Note: The GCC toolchain provides `libgcc.a` pre-compiled for various `-march` targets, meaning the injected `__mulsi3` code will be perfectly compatible with our RV32I core.*