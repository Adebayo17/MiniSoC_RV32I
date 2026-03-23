# Error Handling Architecture

## Introduction

In a bare-metal embedded environment, there is no Operating System to catch segmentation faults, and the C language does not support exception handling (`try`/`catch`). If an error occurs (such as accessing an invalid memory address or a peripheral timing out), the software must handle it explicitly to prevent the CPU from executing unpredictable or dangerous behavior.

This project strictly follows the **Barr Group Embedded C Coding Standard**. All functions that can potentially fail return a standardized error type, and execution flow is managed using the Single Exit Point pattern to guarantee safe state recovery.

---

## 1. The `system_error_t` Type
All hardware abstraction (HAL) and driver functions return the `system_error_t` enumeration (defined in `sw/include/errors.h`).

### Value Convention
- **`0` (`SYSTEM_SUCCESS`)**: The operation completed successfully.
- **`< 0` (Negative Values)**: An error occurred.

### Error Categories
Errors are divided into logical categories:

1. **Software Errors (0 to -10)**: Invalid parameters (`SYSTEM_ERROR_INVALID_PARAM`), busy states, timeouts.
2. **Hardware Errors (-10 to -19)**: Misaligned memory accesses, attempts to write to Read-Only memory (IMEM).
3. **Peripheral-Specific Errors (< -20)**: UART Overrun (`SYSTEM_ERROR_UART_OVERRUN`), GPIO invalid pin, etc.

---

## 2. Safe Error Evaluation
To comply with the coding standard, you must never use raw comparison operators to check for success or failure (e.g., `if (err == 0)` or `if (err < 0)`).

Instead, the system provides strict `static inline` helper functions. This abstracts the underlying integer representation and improves code readability.

### The Right Way to Check Errors
```c
system_error_t status = uart_init(&uart0, UART_BASE_ADDRESS);

/* CORRECT: Using the inline helper functions */
if (is_error(status)) {
    // Handle the failure
}

if (is_success(status)) {
    // Proceed safely
}
```

---

## 3. The "Single Exit Point" Pattern
A common source of memory leaks and locked hardware in embedded C is returning early from a function or using `goto` statements to jump to a cleanup block.

Our architecture enforces a **Single Exit Point**. A function must declare a status variable at the top, chain operations sequentially using if (is_success(status)), and return the status at the very end.

### Example: Sequential Execution
Notice how if Step 1 fails, Steps 2 and 3 are completely skipped, but the cleanup routine is still guaranteed to execute.

```c
system_error_t perform_sensor_read(uart_t *uart) {
    system_error_t status = SYSTEM_SUCCESS;
    uint8_t data = 0U;

    /* Step 1: Enable Hardware */
    status = uart_enable_rx(uart);

    /* Step 2: Read Data (Only if Step 1 succeeded) */
    if (is_success(status)) {
        status = uart_receive_byte(uart, &data, 1000U);
    }

    /* Step 3: Acknowledge (Only if Step 2 succeeded) */
    if (is_success(status)) {
        status = uart_transmit_byte(uart, 0xACK, 500U);
    }

    /* Cleanup: ALWAYS executed, regardless of success or failure */
    (void)uart_disable_rx(uart);

    /* Single Exit Point */
    return status;
}
```

---

## 4. Hardware Error Interception
A unique feature of the Mini RV32I SoC is its robust Wishbone interconnect. If the CPU attempts to read from an unmapped address or a disabled slave, the bus does not hang. Instead, it returns a specific 32-bit hardware error pattern.

### Hardware Error Patterns
- `0xDEADBEEF` (`HARDWARE_ERROR_INVALID_ADDR`): Accessing an address outside defined regions.
- `0xBADADD01` (`HARDWARE_ERROR_INVALID_SLAVE`): Accessing an empty region inside a valid slave.

### How the HAL translates this
If you use the raw `read_reg32()` macro, you might mistakenly treat `0xDEADBEEF` as a valid sensor reading.

By using the Safe Memory API (`system_read_word_safe`), the HAL intercepts this hardware response and safely translates it into a software error (`SYSTEM_ERROR_INVALID_ADDRESS`), preventing your logic from processing garbage data.

```c
uint32_t sensor_value;
system_error_t status;

/* Trying to read a completely invalid physical address */
status = system_read_word_safe(0x99999999UL, &sensor_value);

if (status == SYSTEM_ERROR_INVALID_ADDRESS) {
    /* The HAL successfully caught the 0xDEADBEEF hardware response. */
    /* 'sensor_value' remains untouched. */
}
```

---

## 5. Parameter Validation
Every driver function begins by validating its inputs. The API uses the `peripheral_check_valid()` utility (found in `sw/include/peripheral_utils.h`) to verify that a peripheral handle is not `NULL`, that its base address is correctly mapped in the hardware, and that it has been initialized.

If an invalid parameter is detected, the function immediately assigns `SYSTEM_ERROR_INVALID_PARAM` to the `status` and bypasses the hardware interaction block.

---

## 6. Assertions (Debug Mode Only)

For development and debugging, the system provides an assertion macro in `sw/include/system.h`:

```c
SYSTEM_ASSERT(condition, message);
```

If the `DEBUG` flag is defined during compilation, a failed assertion will trap the CPU in an infinite `while(1)` loop. This is extremely useful for catching logic errors immediately during Verilog simulation.

*Note: In production builds (without `DEBUG` defined), `SYSTEM_ASSERT` compiles to an empty statement, consuming zero memory or CPU cycles.*