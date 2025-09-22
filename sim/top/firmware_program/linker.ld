/* Simple linker script for test firmware */
MEMORY {
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS {
    .text : {
        *(.text)
    } > IMEM
    
    .data : {
        *(.data)
    } > IMEM
    
    .bss : {
        *(.bss)
    } > IMEM
}