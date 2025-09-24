/* MiniSoc-RV32I Linker Script */ 

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
 * Output Sections
 * --------------------------------------------------- */
SECTIONS
{
    /* ==================================================
     * Code Section (Placed in IMEM)
     * ================================================== */
    .text :
    {
        /* Startup code first */
        KEEP(*(.init))          /* Startup Code */
        KEEP(*(.vector))        /* Interrupt vectors (if any) */
        
        /* Main program code */
        *(.text .text.*)        /* Program Code */
        
        /* Read-only data (constants, strings) */
        *(.rodata .rodata.*)
        
        /* Ensure section alignment */
        . = ALIGN(4);
    } > IMEM

    /* ==================================================
     * Initialized Data Section 
     * (goes into DMEM, but initial values stored in IMEM)
     * ================================================== */
    .data : 
    {
        __data_start = .;       /* Start of data in DMEM */
        
        *(.data .data.*)
        *(.sdata .sdata.*)      /* Small data */
        
        . = ALIGN(4);
        __data_end = .;         /* End of data in DMEM */
    } > DMEM AT > IMEM
    
    /* Load address of data section (in IMEM) */
    __data_load_start = LOADADDR(.data);

    /* ==================================================
     * Uninitialized Data Section (BSS, zero-filled)
     * ================================================== */
    .bss (NOLOAD) : 
    {
        __bss_start = .;        /* Start of BSS */
        
        *(.bss .bss.*)
        *(COMMON)
        *(.sbss .sbss.*)        /* Small BSS */
        
        . = ALIGN(4);
        __bss_end = .;          /* End of BSS */
    } > DMEM

    /* ==================================================
     * Heap Section (for dynamic memory allocation)
     * ================================================== */
    .heap (NOLOAD) :
    {
        . = ALIGN(8);           /* 8-byte alignment for heap */
        __heap_start = .;       /* Start of heap */
        
        /* Reserve 1KB for heap (matches system.h) */
        . += 0x400;             /* 1KB = 0x400 bytes */
        
        __heap_end = .;         /* End of heap */
    } > DMEM

    /* ==================================================
     * Stack Section (at top of DMEM, grows downward)
     * ================================================== */
    .stack (NOLOAD) : 
    {
        . = ALIGN(8);           /* 8-byte alignment for stack */
        
        /* Stack starts at top of DMEM and grows downward */
        . = ORIGIN(DMEM) + LENGTH(DMEM);    /* Top of DMEM */
        __stack_top = .;                    /* Stack pointer initial value */
        
        /* Reserve 1KB for stack (matches system.h) */
        . -= 0x400;                         /* 1KB = 0x400 bytes */
        __stack_bottom = .;                 /* Bottom of stack area */
    } > DMEM

    /* ==================================================
     * Memory Usage Validation
     * ================================================== */
    
    /* Calculate total used DMEM */
    __dmem_used = __heap_end - ORIGIN(DMEM);
    
    /* Ensure we don't exceed DMEM size */
    ASSERT(__dmem_used <= LENGTH(DMEM), "Error: DMEM overflow!")
    
    /* Ensure stack doesn't overlap heap */
    ASSERT(__stack_bottom >= __heap_end, "Error: Stack overlaps heap!")
    
    /* ==================================================
     * Provide symbols for C code usage
     * ================================================== */
    
    /* End of all allocated sections */
    _end = .;
}