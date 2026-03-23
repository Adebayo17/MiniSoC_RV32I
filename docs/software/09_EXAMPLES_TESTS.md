# Examples & Tests Guide

## Introduction

The Mini RV32I SoC software stack includes a comprehensive suite of unit and integration tests. Because this is a bare-metal environment destined to run on a Verilog hardware simulation, these tests serve two primary purposes:

1. **Hardware Verification**: They stimulate the RTL modules (UART, GPIO, Timer) to ensure the Verilog implementation behaves correctly.

2. **Software Validation**: They prove that the Hardware Abstraction Layer (HAL) and drivers handle initialization, edge cases, and hardware errors (like `0xDEADBEEF`) safely without crashing.

---

## Directory Layout
The tests and examples are located in the `sw/` directory:

```text
sw/
├── src/
│   └── main.c                 # Primary application example (Integration Example)
└── tests/
    ├── gpio/
    │   └── gpio_usage.c       # GPIO unit tests
    ├── timer/
    │   └── timer_usage.c      # Timer unit tests
    ├── uart/
    │   └── uart_usage.c       # UART unit tests
    └── integration_test.c     # Full SoC integration test
```

---

## Building and Running Tests

The build system compiles the tests independently from the main firmware. Each test file becomes its own standalone executable (ELF).

### Building the Test Suite
To compile all tests at once, run the following command from the project root:

```bash
make sw.test
```

**Output location**:
The compiled executables will be placed in `build/sw/tests/`:

- `build/sw/tests/gpio/gpio_test.elf`
- `build/sw/tests/timer/timer_test.elf`
- `build/sw/tests/uart/uart_test.elf`
- `build/sw/tests/integration_test.elf`

### Simulating a Test
To run a specific test in your hardware simulator, you typically need to convert the desired `.elf` into a `.mem` file, rename it to `firmware.mem` (or adjust your Verilog `$readmemh` path), and launch the simulator.

*(If you have a dedicated make sim.test target in your Makefile, use that instead).*

---

## Available Test Programs

### 1. GPIO Test (gpio_usage.c)
Validates the digital I/O capabilities and the hardware atomic operations.

- `test_gpio_init()`: Checks `NULL` pointer protections and verifies that invalid addresses are rejected.
- `test_gpio_direction()`: Verifies input/output configurations. Tests the hardware limit by purposely trying to configure `GPIO_PIN_10` (expecting `SYSTEM_ERROR_GPIO_INVALID_PIN`).
- `test_gpio_read_write()`: Tests the atomic `SET`, `CLEAR`, and `TOGGLE` hardware registers.
- `test_gpio_blink()`: Simulates a 5-cycle LED blink using the hardware timer for delays.

### 2. Timer Test (`timer_usage.c`)
Validates the continuous timebase and hardware counting.

- `test_timer_init()`: Ensures the driver rejects `0 Hz` clock frequencies.
- `test_timer_configuration()`: Tests the application of the prescaler (`PRESCALE_1` to `PRESCALE_1024`).
- `test_timer_delay()`: Tests blocking microsecond and millisecond delays.
- `test_timer_timeout()`: Simulates a non-blocking background timeout using polling (`timer_is_timeout`).


### 3. UART Test (`uart_usage.c`)
Validates the serial communication block.

- `test_uart_init()`: Checks baud rate divisor calculations based on the system clock.
- `test_uart_transmit()`: Tests single-byte, string, and raw data buffer transmissions with safe timeouts.
- `test_uart_status()`: Validates the retrieval and clearing of hardware error flags (Overrun, Frame Error).


### 4. Integration Test (`integration_test.c`)
This is the most complex test. It initializes all peripherals simultaneously to ensure there are no memory overlaps or bus collisions.

- It blinks a GPIO LED while transmitting the string "`LED ON\r\n`" / "`LED OFF\r\n`" over the UART.
- `test_memory_integration()`: Tests `system_memcpy_safe` and `system_memcmp_safe`.
- `test_error_handling()`: Purposely triggers hardware misalignment (reading a 32-bit word from a non-multiple-of-4 address) to verify that the HAL intercepts the exception.

---

## Anatomy of a Bare-Metal Test

If you wish to write your own tests, you must adhere to the **Barr Group** standards established in this project. Tests do not use `assert()` from the standard library. Instead, they propagate the `system_error_t` up to `main()`.

### The Test Pattern
```c
#include "system.h"
#include "errors.h"
#include "gpio.h"

/* 1. Define a specific test function */
system_error_t test_my_feature(void) {
    system_error_t status = SYSTEM_SUCCESS;
    gpio_t dev;

    /* Initialize */
    status = gpio_init(&dev, GPIO_BASE_ADDRESS);

    /* Perform Action */
    if (is_success(status)) {
        status = gpio_set_pin(&dev, GPIO_PIN_0);
    }

    /* Verify Result (Return HARDWARE error if it fails logic) */
    if (is_success(status)) {
        bool val;
        status = gpio_read_pin(&dev, GPIO_PIN_0, &val);
        if (is_success(status) && (val != true)) {
            status = SYSTEM_ERROR_HARDWARE; 
        }
    }

    /* Cleanup */
    (void)gpio_deinit(&dev);

    return status;
}

/* 2. Chain tests in main() */
int main(void) {
    system_error_t status = SYSTEM_SUCCESS;
    int ret_val = 0;
    
    system_init();
    
    /* Chain execution: Stop immediately if one test fails */
    status = test_my_feature();
    
    if (is_success(status)) {
        status = test_another_feature();
    }
    
    /* 3. Set the UNIX-style return value (0 = Success, 1 = Fail) */
    if (is_error(status)) {
        ret_val = 1;
    }
    
    return ret_val;
}
```

### Why this pattern?
1. **No unexpected crashes**: If `gpio_init` fails, `gpio_set_pin` is never called, preventing Null Pointer Dereferences or hardware bus locks.

2. **Clean shutdown**: The `gpio_deinit` function at the end acts as a single exit point cleanup, ensuring the hardware is left in a safe state even if the verification step failed.

3. **Simulation friendly**: Verilog testbenches can monitor the CPU register containing the `main()` return value (`ret_val`) to automatically determine if the test passed or failed.