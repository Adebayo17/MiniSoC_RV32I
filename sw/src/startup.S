    .section .init
    .globl _start
    .globl __stack_top

/* Entry point */
_start:
    /* Setup Stack pointer */
    la sp, __stack_top

    /* --------------------------------------------------
     * Initialize .bss section to zero
     * -------------------------------------------------- */
    la      t0, __bss_start             /* t0 = start of .bss */
    la      t1, __bss_end               /* t1 = end of .bss */
    beq     t0, t1, bss_done            /* if no bss, skip */

bss_loop:
    sw      zero, 0(t0)                 /* *t0 = 0 */
    addi    t0, t0, 4                   /* next word */
    blt     t0, t1, bss_loop

bss_done:

    /* --------------------------------------------------
     * Copy .data section from LMA (IMEM) to VMA (DMEM)
     * -------------------------------------------------- */
    la      t0, __data_load             /* source (in IMEM image) */
    la      t1, __data_start            /* destination (in DMEM) */
    la      t2, __data_end
    beq     t1, t2, data_done

data_loop:
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    blt     t1, t2, data_loop

data_done:

    /* --------------------------------------------------
     * Jump to main()
     * -------------------------------------------------- */
    call main

    /* --------------------------------------------------
     * If main returns, loop forever
     * -------------------------------------------------- */

hang:
    j hang

    /* --------------------------------------------------
     * Provide weak symbols if linker does not find them
     * -------------------------------------------------- */
    .section .rodata
    .weak main
    .weak __stack_top
    .weak __bss_start
    .weak __bss_end
    .weak __data_load
    .weak __data_start
    .weak __data_end
    
