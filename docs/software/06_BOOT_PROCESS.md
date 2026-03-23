# Boot Process & Startup Sequence

## Introduction 
In a "Bare-Metal" embedded system like the Mini RV32I SoC, there is no Operating System to load the program into memory or set up the environment. When the CPU powers on or resets, it blindly starts executing instructions from memory address `0x00000000`.

Before any C code (like `main()`) can run safely, the processor must prepare the C Runtime Environment (CRT). This crucial transition is handled by a small assembly file: `sw/src/startup.S`.

This document explains the step-by-step cold boot sequence.

---

## The Cold Boot Sequence
When the SoC reset line is de-asserted, the CPU's Program Counter (PC) is automatically set to `0x00000000` (the base address of IMEM).

The linker script ensures that the `.init` section of `startup.S` is placed exactly at this address. The execution flows through four distinct phases before handing control over to the application.

### Phase 1: Stack Pointer Initialization
The very first instruction executed by the CPU must set up the Stack Pointer (`sp` or `x2` in RISC-V). Without a stack, the CPU cannot execute C function calls or allocate local variables.

```asm
_start:
    /* Setup Stack pointer */
    la sp, _estack
```
- **How it works**: `_estack` is a symbol provided by the linker script, pointing to the very top of the Data Memory (DMEM, e.g., `0x10004000`). The stack will grow downward from this address.


### Phase 2: `.bss` Initialization (Zero-Fill)
The C standard dictates that all uninitialized global and static variables must default to `0`. However, RAM powers up with random garbage data.

```asm
    /* Initialize .bss section to zero */
    la      t0, _sbss             /* t0 = start of .bss */
    la      t1, _ebss             /* t1 = end of .bss */
    beq     t0, t1, bss_done      /* if no bss, skip */

bss_loop:
    sw      zero, 0(t0)           /* Write 0 to memory */
    addi    t0, t0, 4             /* Move to next word */
    blt     t0, t1, bss_loop
bss_done:

```
- **How it works**: The code loops from `_sbss` to `_ebss` (defined in the linker script), writing the hardware `zero` register (`x0`) to every 32-bit word in DMEM.


### Phase 3: `.data` Relocation (IMEM to DMEM Copy)
Global variables that are initialized with a specific value (e.g., `int my_var = 42;`) have their initial values stored in the Read-Only IMEM. Because the program needs to modify them at runtime, these values must be copied into the Read/Write DMEM.

```asm
    /* Copy .data section from LMA (IMEM) to VMA (DMEM) */
    la      t0, _sidata           /* source (in IMEM image) */
    la      t1, _sdata            /* destination (in DMEM) */
    la      t2, _edata            /* end of destination */
    beq     t1, t2, data_done

data_loop:
    lw      t3, 0(t0)             /* Load word from IMEM */
    sw      t3, 0(t1)             /* Store word to DMEM */
    addi    t0, t0, 4
    addi    t1, t1, 4
    blt     t1, t2, data_loop
data_done:

```
- How it works: The code reads the Load Memory Address (LMA) from `_sidata` (in IMEM) and copies it word-by-word to the Virtual Memory Address (VMA) starting at `_sdata` (in DMEM).

### Phase 4: Handover to C Application
Now that the stack is ready, variables are zeroed, and initial values are loaded, the environment is 100% compliant with the C standard. The assembly code can safely call `main()`.

```asm
    /* Jump to main() */
    call main

    /* If main returns, loop forever (Trap) */
hang:
    j hang

```
- **Safety Net**: In embedded systems, `main()` should contain an infinite loop and never return. If a bug causes `main()` to return, the CPU falls into the `hang` infinite loop, preventing it from executing random memory as code.

---

## C-Level Initialization
Once `startup.S` calls `main()`, the software assumes control. Following our architectural standards, `main()` must immediately initialize the Hardware Abstraction Layer (HAL).

```c
int main(void) {
    /* 1. Reset system structures and clear legacy states */
    system_init();
    
    /* 2. Initialize Peripherals (UART, GPIO, Timer) */
    system_error_t status = peripherals_init();
    
    if (is_error(status)) {
        /* Trap CPU if hardware setup fails */
        handle_critical_error(); 
    }
    
    /* 3. Enter Application Superloop */
    while(1) {
        // Business logic...
    }
}

```

**Why system_init() is necessary**
Even though `.bss` variables are zeroed, `system_init()` (located in `sw/src/system.c`) ensures that internal software states (like delay timers or legacy ticks) are strictly reset to their default operational values. It acts as the software counterpart to the hardware reset line.

---

## Summary Diagram

```text
Power On / Soft Reset
        │
        ▼
[ PC = 0x00000000 ]
        │
        ▼
   startup.S
   ├── 1. sp = _estack             (Stack setup in DMEM)
   ├── 2. memset(_sbss, 0)         (Zero uninitialized data)
   ├── 3. memcpy(_sdata, _sidata)  (Load initialized data to RAM)
   └── 4. call main                (Enter C code)
        │
        ▼
    main.c
    ├── 1. system_init()           (Init software HAL)
    ├── 2. peripheral_init()       (Init hardware drivers)
    └── 3. while(1)                (Infinite Superloop)

```

---

## Related Documentation
- **[Linker Script Guide](05_LINKER_SCRIPT.md)**:   To understand where symbols like `_estack`, `_sidata`, and `_sbss` are defined.
- **[Architecture Overview](02_ARCHITECTURE_OVERVIEW.md)**: To understant the structure of the C code that runs after boot.