# Linker Script & Memory Layout

## 📌 Introduction 
This document explains the role of the Linker Script (`linker.ld`) in the Mini RV32I SoC project.

In a hosted environment (Linux, Windows), the Operating System loads programs into virtual memory, so programmers rarely worry about physical addresses. However, in **bare-metal embedded systems**, we must explicitly tell the compiler and linker exactly where to place code and data in real physical memory (IMEM, DMEM).

Without a linker script, the GNU Linker (`ld`) would not know:

- Where the entry point (`_start`) is located.
- Where instructions (`.text`) should reside.
- Where global and static variables (`.data`, `.bss`) should be placed.
- Where the stack and heap can safely grow without colliding.


---

## 📌 Core Memory Concepts
Embedded programs are split into different sections:

- `.text`   &rarr; Program instructions and executable code (Read-Only).
- `.rodata` &rarr; Read-only data (e.g., string literals, `const` variables).
- `.data`   &rarr; Initialized global/static variables. These are stored in non-volatile memory (IMEM) but copied to RAM (DMEM) at startup.
- `.bss`    &rarr; Uninitialized globals/statics variables. These take no space in the binary file but are allocated and zero-filled in RAM at startup. 
- `.stack`  &rarr; LIFO memory for function call frames, local variables, and context saving.
- `.heap`   &rarr; Memory for dynamic allocation (`malloc/free`). *Note: Dynamic allocation is generally discouraged in strict embedded systems.*

### Typical Layout in Embedded RAM
```lua
High addresses (0x1000_3FFF - Top of DMEM)
+---------------------------+
|         .stack            |  Grows downward (↓)
+---------------------------+
|          ...              |  Free Space / Buffer
+---------------------------+
|         .heap             |  Grows upward (↑)
+---------------------------+
|         .bss              |  Zero-initialized variables
+---------------------------+
|         .data             |  Initialized from IMEM at boot
+---------------------------+
Low addresses (0x1000_0000 - Bottom of DMEM)

```


---

## 📌 The Mini RV32I Linker Script Explained
Below is the breakdown of the actual sw/linker.ld file used in this project.

### 1. Architecture and Entry Point
```ld
OUTPUT_ARCH(riscv)
ENTRY(_start)
```
- Defines the target architecture.
- `ENTRY(_start)` tells the linker that execution begins at the `_start` symbol (defined in `startup.S`)

### 2. Physical Memory Regions
```ld
MEMORY
{
    /* Instruction Memory: 32 KB at base address 0x00000000 */
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 32K

    /* Data Memory: 16 KB at base address 0x10000000 */
    DMEM (rwx) : ORIGIN = 0x10000000, LENGTH = 16K
}
```
Defines the hardware reality of our SoC. `(rx)` means Read/Execute, `(rwx)` means Read/Write/Execute.

### 3. Section Placement

**The Executable Code (IMEM)**
```ld
SECTIONS
{
    .text : ALIGN(4)
    {
        KEEP(*(.init))           /* Startup Code (MUST be first) */
        *(.text .text.*)         /* Main Program Code */
        *(.rodata .rodata.*)     /* Read-only data */
        . = ALIGN(4);
    } > IMEM
    ...
}
```
- `KEEP(*(.init))` ensures the initialization code is never optimized away by Garbage Collection (`--gc-sections`).
- `> IMEM` forces this entire block into the Instruction Memory.


**The Initialized Data (.data)**
```ld
    .data : ALIGN(4)
    {
        _sdata = .;              /* Start of data in DMEM */
        *(.data .data.*)
        *(.sdata .sdata.*)       /* Small data */
        . = ALIGN(4);
        _edata = .;              /* End of data in DMEM */
    } > DMEM AT > IMEM

    _sidata = LOADADDR(.data);   /* Load address of data section (in IMEM) */
```
- **The `AT > IMEM` Magic**: This tells the linker: *"Allocate virtual addresses for these variables in `DMEM`, but store their initial values in the physical `IMEM` binary."*
- `LOADADDR(.data)` retrieves the IMEM physical address where the startup script will copy the values from.


**The Uninitialized Data (.bss)**
```ld
    .bss (NOLOAD) : ALIGN(4)
    {
        _sbss = .;               /* Start of BSS */
        *(.bss .bss.*)
        *(.sbss .sbss.*)         /* Small BSS */
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;               /* End of BSS */
    } > DMEM

```
- `NOLOAD`: Instructs the linker to reserve address space in DMEM but NOT to put millions of zeros into the .bin output file. The startup code will zero this memory at runtime.


**Heap and Stack**
```ld
    /* Set Heap start immediately after BSS */
    _heap_start = .;
    _heap_end = . + 0x1000;      /* Reserve 4KB for Heap (Optional) */

    /* Place Stack exactly at the top of DMEM */
    _estack = ORIGIN(DMEM) + LENGTH(DMEM); 
    _sstack = _estack - 0x1000;  /* Reserve 4KB for Stack */
```


---

## 📌 Symbols and Boot Process Interaction
The linker script exports special symbols (`_sdata`, `_sbss`, `_estack`) that act as coordinates for the Assembly code. These are not variables; they are **memory addresses**.

Here is how startup.S uses them during the **Cold Boot Sequence**:

```ld
_start:
    /* 1. Set the Stack Pointer to the very top of DMEM */
    la sp, _estack

    /* 2. Copy .data from IMEM to DMEM */
    la t0, _sidata    /* Source in IMEM */
    la t1, _sdata     /* Destination in DMEM */
    la t2, _edata     /* End of destination */
copy_loop:
    bge t1, t2, end_copy
    lw t3, 0(t0)
    sw t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j copy_loop
end_copy:

    /* 3. Zero out the .bss section */
    la t0, _sbss
    la t1, _ebss
    /* ... loop to store 0 ... */
    
    /* 4. Jump to C Application */
    call main
```

--- 

## 📌 Linker Assertions (Safety Guards)
Following strict embedded safety standards, we use linker `ASSERT` commands to detect memory collisions at compile time. If your arrays are too large, the build will fail immediately instead of crashing randomly at runtime.

```ld
    /* Check 1: Ensure DMEM isn't overflowing */
    ASSERT((_ebss - ORIGIN(DMEM)) <= LENGTH(DMEM), 
           "Error: .data and .bss exceed DMEM capacity!")

    /* Check 2: Ensure Stack does not collide with Heap or BSS */
    ASSERT(_sstack >= _heap_end, 
           "Error: Stack overlaps with Heap or BSS!")
```

---

## 📌 Common Pitfalls
- **Forgetting `NOLOAD` on `.bss`**: The linker puts useless zeros in the flash/IMEM image, creating a massive, bloated `.bin` file.

- **Misaligned Addresses**: Missing `ALIGN(4)` causes CPU exceptions (`store_misaligned`) on 32-bit cores when the startup code tries to copy words (`lw`/`sw`) on non-multiples of 4.

- **Incorrect `_estack`**: Pointing the stack outside of valid RAM results in immediate hardware traps on the very first function call (`call main`).

- **Missing `KEEP(*(.init))`**: If the linker's garbage collector (`--gc-sections`) cannot find a reference to your startup code from `main`, it will delete the boot sequence entirely.


---

## 📌 Learning Resources

- [GNU ld Linker Script Documentation](https://sourceware.org/binutils/docs/ld/Scripts.html)
- RISC-V GCC bare-metal examples (e.g., SiFive SDKs)