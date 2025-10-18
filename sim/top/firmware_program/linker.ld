/* Simple linker script for test firmware */

/* ---------------------------------------------------
 * Output Format
 * --------------------------------------------------- */
/* OUTPUT_FORMAT("elf32-little")    RISC-V RV32 little-endian */
OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv", "elf32-littleriscv")
OUTPUT_ARCH(riscv)

MEMORY 
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 8K
    DMEM (rwx) : ORIGIN = 0x10000000, LENGTH = 4K
}

/* ---------------------------------------------------
 * Entry Point
 * --------------------------------------------------- */
ENTRY(_start)

SECTIONS
{
    .text : ALIGN(4) {
        KEEP(*(.init)) 
        KEEP(*(.vector))

        *(.text)
        *(.rodata)
        . = ALIGN(4); 
        _etext = .;
    } > IMEM
    
    . = ORIGIN(DMEM);
    .data : ALIGN(4) {
        _sdata = .; 
        *(.data)
        *(.sdata)
        . = ALIGN(4);
        _edata = .;  
    } > DMEM AT > IMEM

    _sidata = LOADADDR(.data);
    
    .bss (NOLOAD) : ALIGN(4)
    {
        _sbss = .;                          
        *(.bss .bss.*)
        *(COMMON)
        *(.sbss .sbss.*)                    
        . = ALIGN(4);
        _ebss = .;                         
    } > DMEM

    . = ORIGIN(DMEM) + 0x800;

    .heap (NOLOAD) : ALIGN(8)
    {
        _heap_start = .;                    /* Start of heap */
        . += 0x400;                         /* 1KB = 0x400 bytes */
        _heap_end   = .;                    /* End of heap */
    } > DMEM
    
    /* Stack at end of DMEM */
    .stack (NOLOAD) : ALIGN(8)
    {   
        _sstack = .;                        /* Stack bottom: 0x10000C00 */
        . += 0x400;                         /* Reserve 1KB stack */
        _estack = .;                        /* Stack top: 0x10001000 (just past DMEM) */
    } > DMEM

    /* End of all allocated sections */
    _end = .;
}