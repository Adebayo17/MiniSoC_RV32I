/* Simple linker script for test firmware */
MEMORY 
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 8K
    DMEM (rwx) : ORIGIN = 0x10000000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        *(.text)
    } > IMEM
    
    .data : {
        *(.data)
        *(.rodata)
    } > DMEM
    
    .bss : {
        *(.bss)
    } > DMEM
    
    /* Stack at end of DMEM */
    .stack (NOLOAD) : {
        . = ORIGIN(DMEM) + LENGTH(DMEM) - 4;
        _stack = .;
    } > DMEM
}