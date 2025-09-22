/* MiniSoc-RV32I Linker Script*/ 

/* ---------------------------------------------------
 * Memory Map (matches SoC specification)
 * --------------------------------------------------- */
MEMORY 
{
    IMEM  (rx)      : ORIGIN = 0x00000000, LENGTH = 4K    /* Instruction Memory */
    DMEM  (rwx)     : ORIGIN = 0x10000000, LENGTH = 4K    /* Data Memory */

    /* Peripherals (not used for rection placement, only for reference) */
    UART  (rw)      : ORIGIN = 0x20000000, LENGTH = 4K
    TIMER (rw)      : ORIGIN = 0x30000000, LENGTH = 4K
    GPIO  (rw)      : ORIGIN = 0x40000000, LENGTH = 4K    
}


/* ---------------------------------------------------
 * Entry Point
 * --------------------------------------------------- */
ENTRY(_start)


/* ---------------------------------------------------
 * Sections
 * --------------------------------------------------- */
SECTIONS
{
    /* Code (Placed in IMEM) */
    .text :
    {
        KEEP(*(.init))          /* Startup Code */
        *(.text .text.*)        /* Program Code */
        *(.rodata .rodata.*)    /* Read-only data (constants, strings) */
    } > IMEM

    /* Initialized Data (goes into DMEM) */ 
    .data : 
    {
        *(.data .data.*)
    } > DMEM AT > IMEM

    /* Uninitialized date (BSS, zero-filled) */
    .bss (NOLOAD) : 
    {
        *(.bss .bss.*)
        *(COMMON)
    } > DMEM

    /* Stack (at top of DMEM) */
    .stack (NOLOAD) : 
    {
        . = ORIGIN(DMEM) + LENGTH(DMEM);    /* End of DMEM */
        . -= 0x100;                         /* Reserve 256 Bytes for stack */
        __stack_top = .;                    /* Symbol for stack pointer init*/
    } > DMEM
}
