/* ==================================================
 * MiniSoc-RV32I Linker Script
 *   IMEM = 4 KB @ 0x0000_0000 (instructions, constants)
 *   DMEM = 4 KB @ 0x1000_0000 (data, heap, stack)
 *
 * DMEM partitioning:
 *   [0x1000_0000 - 0x1000_07FF]  2 KB = .data + .bss
 *   [0x1000_0800 - 0x1000_0BFF]  1 KB = .heap
 *   [0x1000_0C00 - 0x1000_0FFF]  1 KB = .stack (grows downward)
 * ================================================== */

/* ---------------------------------------------------
 * Memory Map (matches SoC specification)
 * --------------------------------------------------- */
MEMORY 
{
    IMEM  (rx)      : ORIGIN = 0x00000000, LENGTH = 4K    /* Instruction Memory */
    DMEM  (rwx)     : ORIGIN = 0x10000000, LENGTH = 4K    /* Data Memory */

    /* Peripherals (not used for section placement, only for reference) */
    UART  (rw)      : ORIGIN = 0x20000000, LENGTH = 4K
    TIMER (rw)      : ORIGIN = 0x30000000, LENGTH = 4K
    GPIO  (rw)      : ORIGIN = 0x40000000, LENGTH = 4K    
}


/* ---------------------------------------------------
 * Entry Point
 * --------------------------------------------------- */
ENTRY(_start)


/* ---------------------------------------------------
 * Output Format
 * --------------------------------------------------- */
OUTPUT_FORMAT("elf32-little")    /* RISC-V RV32 little-endian */
OUTPUT_ARCH(riscv:rv32)


/* ---------------------------------------------------
 * Output Sections
 * --------------------------------------------------- */
SECTIONS
{
    /* ==================================================
     * Code Section (Placed in IMEM)
     * ================================================== */
    . = ORIGIN(IMEM);
    .text : ALIGN(4)
    {
        KEEP(*(.init))                      /* Startup Code */
        KEEP(*(.vector))                    /* Interrupt vectors (if any) */
        
        *(.text .text.*)                    /* Main Program Code */
        *(.rodata .rodata.*)                /* Read-only data (constants, strings) */
        
        . = ALIGN(4);                       /* Ensure section alignment */
        _etext = .;                         /* End of text section */
    } > IMEM

    /* ==================================================
     * Initialized Data Section 
     * (goes into DMEM, but initial values stored in IMEM)
     * ================================================== */
    . = ORIGIN(DMEM);
    .data : ALIGN(4)
    {
        _sidata = LOADADDR(.data);          /* Load address of data section (in IMEM) */

        _sdata = .;                         /* Start of data in DMEM */
        *(.data .data.*)
        *(.sdata .sdata.*)                  /* Small data */
        _edata = .;                         /* End of data in DMEM */
    } > DMEM AT > IMEM
    
    
    /* ==================================================
     * Uninitialized Data Section (BSS, zero-filled)
     * ================================================== */
    .bss (NOLOAD) : ALIGN(4)
    {
        _sbss = .;                          /* Start of BSS */
        *(.bss .bss.*)
        *(COMMON)
        *(.sbss .sbss.*)                    /* Small BSS */
        _ebss = .;                          /* End of BSS */
    } > DMEM

    /* Force . = start of heap region (0x1000_0800) */
    . = ORIGIN(DMEM) + 0x800;


    /* ==================================================
     * Heap Section (for dynamic memory allocation)
     * ================================================== */
    .heap (NOLOAD) : ALIGN(8)
    {
        _heap_start = .;                    /* Start of heap */
        . += 0x400;                         /* 1KB = 0x400 bytes */
        _heap_end   = .;                    /* End of heap */
    } > DMEM


    /* ==================================================
     * Stack Section (at top of DMEM, grows downward)
     * ================================================== */
    .stack (NOLOAD) : ALIGN(8)
    {   
        . = ORIGIN(DMEM) + LENGTH(DMEM);    /* Top of DMEM : 0x1000_1000 */
        _estack = .;                        /* Stack pointer initial value */
        . -= 0x400;                         /* 1KB = 0x400 bytes */
        _sstack = .;                        /* Bottom of stack area */
    } > DMEM

    /* ==================================================
     * Memory Usage Validation
     * ================================================== */
    
    /* Calculate total used DMEM */
    __dmem_used = _heap_end - ORIGIN(DMEM);
    
    /* Ensure we don't exceed DMEM size */
    ASSERT(__dmem_used <= LENGTH(DMEM), "Error: DMEM overflow!")
    
    /* Ensure stack doesn't overlap heap */
    ASSERT(_sstack >= _heap_end, "Error: Stack overlaps heap!")
    
    /* ==================================================
     * Provide symbols for C code usage
     * ================================================== */
    
    /* End of all allocated sections */
    _end = .;
}