# System & Memory API (HAL)

## Introduction
The System and Memory API forms the **Hardware Abstraction Layer (HAL)** of the Mini RV32I SoC. Rather than communicating directly with specific hardware registers, the application layer relies on these foundational services to perform memory manipulation, mathematical operations, timekeeping, and error management.

This layer is strictly compliant with the **Barr Group Embedded C Coding Standard**, heavily utilizing `static inline` functions for type safety and `system_error_t` for robust execution flow.

## 1. Error Handling (`errors.h`)
All HAL functions and drivers return a standard `system_error_t` enumeration. This ensures a unified error propagation mechanism across the entire bare-metal stack.

### Standard Error Codes

- `SYSTEM_SUCCESS` (0)                  : Operation completed successfully.
- `SYSTEM_ERROR_INVALID_PARAM` (-1)     : Null pointers or out-of-bounds parameters.
- `SYSTEM_ERROR_TIMEOUT` (-2)           : A polling operation exceeded its time limit.
- `SYSTEM_ERROR_MEMORY_ACCESS` (-6)     : Alignment fault or access violation (e.g., writing to IMEM).
- `SYSTEM_ERROR_INVALID_ADDRESS` (-7)   : Hardware returned `0xDEADBEEF`.

### Safe Evaluation
To evaluate errors, **never use direct comparison operators** (e.g., `if (err == 0)`). Always use the provided typed inline helpers:

```c
system_error_t status = system_init_with_timer_safe(&sys_timer);

if (is_error(status)) {
    // Handle the error gracefully
}

if (is_success(status)) {
    // Proceed with the next step
}
```


## 2. Memory Management (`memory.h`)
Standard C library functions (`<string.h>`) like `memcpy` or `memset` are highly optimized for hosted environments but lack hardware bounds checking. Our custom memory API provides safe, bounded alternatives.

### Safe MMIO Access

Reading from raw memory addresses is dangerous if the address does not exist on the Wishbone bus. `system_read_word_safe` automatically catches hardware exceptions and validates alignment.

```c
uint32_t value;
system_error_t status = system_read_word_safe(0x10002000UL, &value);

if (status == SYSTEM_ERROR_INVALID_ADDRESS) {
    /* The hardware intercepted a read to an unmapped region */
}
```

### Safe Memory Blocks
Our implementations of `system_memcpy_safe`, `system_memmove_safe`, and `system_memset_safe` enforce runtime security:

- They validate that the source is readable and the destination is writable (e.g., preventing `memcpy` into the Read-Only IMEM).
- They ensure no arithmetic overflow occurs during pointer calculation.
- They detect overlaps automatically and switch to `memmove` logic if necessary.

```c
uint8_t dest_buffer[64];
uint8_t src_buffer[64];

system_error_t status = system_memcpy_safe(dest_buffer, src_buffer, 64U, NULL);
```


## 3. System Core & Timebase (`system.h`)
The system module manages global initialization and timekeeping. Because this SoC lacks hardware interrupts, delays and timeouts are managed via safe polling.

### Initialization
`system_init()` MUST be called at the very beginning of `main()`. It resets all internal software states and prepares the runtime environment.

### Delay Functions
The API provides both blocking and non-blocking delays using the hardware timer.

### Blocking Delay:
```c
/* Halts the CPU execution safely for 500 milliseconds */
system_error_t status = system_delay_ms_safe(500U);
```


### Non-Blocking Timeout (Polling):
```c
system_delay_us_start_safe(1000U); /* Start a 1ms timeout */

bool is_done = false;
while (!is_done) {
    /* Perform background tasks here */
    system_delay_us_complete_safe(&is_done);
}
```


## 4. Object-Oriented Peripheral Base (`peripheral.h`)
To avoid duplicating initialization and validation logic across the UART, GPIO, and Timer drivers, the HAL introduces a base class: `peripheral_t`.

### The Inheritance Pattern
Every driver must declare `peripheral_t base;` as its very first member. This allows software polymorphism in C.

```c
typedef struct {
    uint32_t    base_address;
    bool        initialized;
} peripheral_t;

typedef struct {
    peripheral_t  base;   /* Inheritance */
    uart_config_t config;
    uart_status_t status;
} uart_t;
```

### Validation
Before any driver performs an operation, it must validate its handle. The `peripheral_check_valid()` utility safely casts the driver back to its base class to verify that `base_address` is mapped and `initialized` is true.


## 5. Software Math Routines (`math.h`)
The Mini RV32I core implements the standard RV32I instruction set, which **does not include the Hardware Multiplier/Divider (M) extension**.

If you use standard C operators (`*`, `/`, `%`), the GCC compiler will emit `mul` or `div` assembly instructions, causing an *Illegal Instruction Trap on the hardware*.

### Available Math Functions
You must explicitly use the provided software math routines. They are implemented in pure C using efficient shift-and-add algorithms.

- `system_umul32(a, b)`: Unsigned 32-bit multiplication.
- `system_mul32(a, b)`: Signed 32-bit multiplication.
- `system_udiv32(a, b)`: Unsigned 32-bit division.
- `system_umod32(a, b)`: Unsigned 32-bit modulo.


### Example:
```c
uint32_t ticks_per_us = system_udiv32(SYSTEM_CLOCK_FREQ, 1000000U);
```

*Note: The API also provides ultra-fast bitwise alternatives (`fast_udiv_pow2`, `fast_umod_pow2`) specifically for divisors that are known powers of two.*