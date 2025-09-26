# Linker Script Guide for Embedded System (MiniSoC-RV32I example)

## 📌 What is a Linker Script
A **linker script** (`.ld` file) tells the **linker** (GNU `ld`) **how to organize the code and data in memory**.

- In hosted environment (Linux, Windows) the OS (Operating System) loads programs into virtual memory, so programmers don't care about physical addresses.

- In **bare-metal embedded systems**, we must explicity place code and data into real physical memories (flash, SRAM, peripheral regions).

- Without a linker script, the linker would not know:
    - Where to put instructions (`.text`).
    - Where global/static variables should live (`.data`, `.bss`).
    - Where the stack and heap can safely grow.


---

## 📌 Core Memory Concepts
Embedded programs are split into different sections:

- `.text`   &rarr; Program code and constants (read-only)
- `.rodata` &rarr; Read-only data (e.g., string literals)
- `.data`   &rarr; Initialized global/static variables (copied from FLASH &rarr; RAM at startup)
- `.bss`    &rarr; Uninitialized globals/statics (zero-filled at startup) 
- `.stack`  &rarr; Function call frames, local variables
- `.heap`   &rarr; Dynamic memory (`malloc/free`)

### Typical Layout in Embedded RAM
```lua
High addresses (top of RAM)
+---------------------------+
|         Stack             |  grows downward
+---------------------------+
|         Heap              |  grows upward
+---------------------------+
| .bss  (zero-initialized)  |
+---------------------------+
| .data (init from flash)   |
+---------------------------+
Low addresses (bottom of RAM)

```

---

## 📌 Key Parts of a Linker Script

A linker script generally has these sections:

1. **Entry Point**
```ld
ENTRY(_start)
```
Defines the **symbol where execution begins** after reset. Usually `_start` in `startup.S`.

2. **Memory Regions**
```ld
MEMORY
{
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K   /* instruction memory */
  DMEM (rwx) : ORIGIN = 0x10000000, LENGTH = 4K   /* data memory */
}
```
Defines **physical memory regions**: start address `ORIGIN` and size `LENGTH`.

3. **Section Placement**
```ld
SECTIONS
{
    . = ORIGIN(IMEM);
    .text : ALIGN(4)
    {
        KEEP(*(.init))                          /* Startup Code */
        KEEP(*(.vector))                        /* Interrupt vectors (if any) */
        
        *(.text .text.*)                        /* Main Program Code */
        *(.rodata .rodata.*)                    /* Read-only data */
        
        . = ALIGN(4);                           /* Ensure section alignment */
        _etext = .;                             /* End of text section */
    } > IMEM

    . = ORIGIN(DMEM);
    .data : ALIGN(4)
    {
        _sidata = LOADADDR(.data);              /* Load address of data section (in IMEM) */

        _sdata = .;                             /* Start of data in DMEM */
        *(.data .data.*)
        *(.sdata .sdata.*)                      /* Small data */
        _edata = .;                             /* End of data in DMEM */
    } > DMEM AT > IMEM
    
    .bss (NOLOAD) : ALIGN(4)
    {
        _sbss = .;                              /* Start of BSS */
        *(.bss .bss.*)
        *(COMMON)
        *(.sbss .sbss.*)                        /* Small BSS */
        _ebss = .;                              /* End of BSS */
    } > DMEM

    /* Force . = start of heap region (0x1000_0800) */
    . = ORIGIN(DMEM) + 0x800;

    .heap (NOLOAD) : ALIGN(8)
    {
        _heap_start = .;                        /* Start of heap */
        . += 0x400;                             /* 1KB = 0x400 bytes */
        _heap_end   = .;                        /* End of heap */
    } > DMEM

    .stack (NOLOAD) : ALIGN(8)
    {   
        . = ORIGIN(DMEM) + LENGTH(DMEM);        /* Top of DMEM : 0x1000_1000 */
        _estack = .;                            /* Stack pointer initial value */
        . -= 0x400;                             /* 1KB = 0x400 bytes */
        __sstack = .;                           /* Bottom of stack area */
    } > DMEM

    /* End of all allocated sections */
    _end = .;
}
```


---

## 📌 Important key words

- `>`: Places a section into a memory region.
- `AT`: Specifies load address (useful when copying `.data` from flash to RAM).
- `NOLOAD`: Reserves RAM space but does not put contents in the binary (for `.bss`, `.stack`, `.heap`).
- `ALIGN(n)`: Aligns memory addresses (e.g., word alignment for 32-bit systems).
- `KEEP()`: Prevents the linker from discarding unused sections (important for vector tables, startup code).


---

## 📌 Symbols and their roles

The linker can export symbols that your C/assembly code uses:

- `_sdata` / `_edata`           : Start/end of initialized data in RAM .
- `_sidata`                     : Address in flash where init values are stored.
- `_sbss` / `_ebss`             : Start/end of zeroed memory region.
- `_estack`, `_sstack=`         : Stack bounds.
- `_heap_start`, `_heap_end`    : Heap bounds.

These aren’t automatically generated — you define them in the linker script, then reference them in `startup.S` and `system.c`.

Example in `startup.S`:

```asm
la sp, _estack    # set stack pointer to top of RAM

la t0, _sdata
la t1, _edata
la t2, _sidata
```


---

## 📌 How Startup Code Uses It

The **startup assembly file** (`startup.S`) relies on linker symbols to:

1. Set stack pointer (`sp = _estack`).
1. Copy `.data` initializers from flash (`_sidata`) to RAM (`_sdata` &rarr; `_edata`).
1. Zero `.bss` (`_sbss` &rarr; `_ebss`).
1. Call `main()`.


---

## 📌 Common Pitfalls

- Forgetting `NOLOAD`           &rarr; linker puts useless zeros in flash image.
- Not reserving enough space    &rarr; `.data + .bss` may overlap heap or stack.
- Misaligned addresses          &rarr; causes CPU exceptions on 32-bit/64-bit cores.
- Using wrong `ENTRY()` symbol  &rarr; program won’t start.


---

## 📌 Good Practices

- Keep **heap and stack flexible** (let them share free space).
- Use `ALIGN(4)` (or `ALIGN(8)` on 64-bit) to avoid misalignment.
- Add **linker assertions**:
    ```ld
    ASSERT(_sstack >= _heap_end, "Error: Stack overlaps heap!")
    ```
- Keep symbol names conventional (`_sdata`, `_sbss`, `_estack`) for readability.
- Document your memory map alongside the script.


---

## 📌 Learning Resources

- [GNU ld Linker Script Documentation](https://sourceware.org/binutils/docs/ld/Scripts.html)
- RISC-V GCC bare-metal examples (e.g., SiFive SDKs)
- ARM CMSIS startup/linker scripts (similar structure, different addresses)