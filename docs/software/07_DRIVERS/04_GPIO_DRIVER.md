# GPIO Driver API

## Introduction
The GPIO (General Purpose Input/Output) driver provides control over the 8 independent digital I/O pins of the Mini RV32I SoC.

A key feature of this hardware and driver implementation is the support for Atomic Operations. Instead of relying on software Read-Modify-Write (RMW) cycles to change a pin's state, the hardware provides dedicated `SET`, `CLEAR`, and `TOGGLE` registers. This prevents race conditions and ensures that flipping one pin will never accidentally corrupt the state of adjacent pins.

---

## Hardware / Software Separation

Like all peripheral drivers in this project, the GPIO driver is cleanly divided:

- **Hardware Layer (`gpio_hw.h`)**: Contains the physical memory map offsets (`REG_GPIO_DATA`, `REG_GPIO_DIR`, `REG_GPIO_SET`, etc.) and bit masks. Application code must never include this file directly.

- **Software Layer (`gpio.h` / `gpio.c`)**: Provides the Object-Oriented C API. It defines the `gpio_t` handle, direction enumerations, and the public functions used by the application.

---

## The Driver Handle (`gpio_t`)
To interact with the GPIO peripheral, instantiate a `gpio_t` object. This structure inherits from the base `peripheral_t` class, allowing the system to validate its memory address before any operation.

```c
typedef struct {
    peripheral_t base; /* Inherited base class (Validation & Base Address) */
} gpio_t;
```

---

## Initialization & Direction Configuration
Before a pin can be used, the GPIO peripheral must be initialized with its physical base address (`0x40000000U`). Then, each pin must be configured as either an `INPUT` or an `OUTPUT`.

By default, after a hardware reset, all pins are configured as inputs.

### Example: Basic Setup
```c
#include "system.h"
#include "errors.h"
#include "gpio.h"

system_error_t setup_gpio(gpio_t *gpio_dev) {
    system_error_t status = SYSTEM_SUCCESS;

    /* 1. Initialize the handle with the hardware base address */
    status = gpio_init(gpio_dev, GPIO_BASE_ADDRESS);

    /* 2. Configure Pin 0 as Output (e.g., for an LED) */
    if (is_success(status)) {
        status = gpio_set_direction_pin(gpio_dev, GPIO_PIN_0, GPIO_DIR_OUTPUT);
    }

    /* 3. Configure Pin 1 as Input (e.g., for a Button) */
    if (is_success(status)) {
        status = gpio_set_direction_pin(gpio_dev, GPIO_PIN_1, GPIO_DIR_INPUT);
    }

    return status;
}
```

---

## Pin Validation (`gpio_validate_pin`)
The driver includes internal safety checks to ensure that operations are only performed on valid pins (`GPIO_PIN_0` through `GPIO_PIN_7`). If an invalid pin number (e.g., `8U`) is passed to any function, the driver safely aborts the operation and returns `SYSTEM_ERROR_GPIO_INVALID_PIN`.

---

## Writing to Pins (Output)
For output pins, the driver leverages the hardware's atomic registers. Writing a `1` to the `SET` register turns the pin HIGH, writing a `1` to the `CLEAR` register turns it LOW, and writing to the `TOGGLE` register inverses its current state.

### Standard Write
If you have a boolean state variable, you can use the standard write function:

```c
bool led_state = true;
status = gpio_write_pin(&gpio_dev, GPIO_PIN_0, led_state);
```

### Fast Atomic Operations
For performance-critical code or toggling patterns, use the atomic functions directly. They execute in a single Wishbone bus transaction:

```c
/* Atomically set Pin 0 HIGH */
status = gpio_set_pin(&gpio_dev, GPIO_PIN_0);

/* Atomically set Pin 0 LOW */
status = gpio_clear_pin(&gpio_dev, GPIO_PIN_0);

/* Atomically toggle Pin 0 (Invert current state) */
status = gpio_toggle_pin(&gpio_dev, GPIO_PIN_0);
```

---

## Reading from Pins (Input)
You can read the logical state of any pin configured as an input. The driver polls the hardware `DATA` register and returns `true` (HIGH) or `false` (LOW).

```c
bool button_pressed = false;

/* Read the state of Pin 1 */
status = gpio_read_pin(&gpio_dev, GPIO_PIN_1, &button_pressed);

if (is_success(status)) {
    if (button_pressed) {
        /* Button is currently HIGH */
    }
}
```

You can also read the state of all 8 pins simultaneously if you need to capture a parallel data bus:

```c
uint8_t all_pins = 0U;
status = gpio_read_all(&gpio_dev, &all_pins);
```

---

## Complete Usage Example: Button Controlled Blink
This example demonstrates how to configure an output (LED) and an input (Button). The LED blinks continuously, but the blinking stops while the button is held down.
```c
#include "system.h"
#include "errors.h"
#include "gpio.h"
#include "timer.h"

int main(void) {
    system_error_t status = SYSTEM_SUCCESS;
    gpio_t gpio0;
    timer_t timer0;
    
    /* System & Hardware Initialization */
    system_init();
    status = gpio_init(&gpio0, GPIO_BASE_ADDRESS);
    
    if (is_success(status)) {
        status = timer_init(&timer0, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    }
    
    /* Pin Configuration */
    if (is_success(status)) {
        status = gpio_set_direction_pin(&gpio0, GPIO_PIN_0, GPIO_DIR_OUTPUT); /* LED */
    }
    if (is_success(status)) {
        status = gpio_set_direction_pin(&gpio0, GPIO_PIN_1, GPIO_DIR_INPUT);  /* Button */
    }
    
    /* Error Trap */
    if (is_error(status)) {
        while(1) { /* Init failed, halt CPU */ }
    }
    
    /* Main Superloop */
    while (1) {
        bool button_state = false;
        
        /* Read the button */
        status = gpio_read_pin(&gpio0, GPIO_PIN_1, &button_state);
        
        if (is_success(status)) {
            if (button_state == false) {
                /* Button is not pressed, toggle the LED */
                (void)gpio_toggle_pin(&gpio0, GPIO_PIN_0);
            } else {
                /* Button is pressed, force LED OFF */
                (void)gpio_clear_pin(&gpio0, GPIO_PIN_0);
            }
        }
        
        /* Wait 200ms before next iteration */
        (void)system_delay_ms_safe(200U);
    }
    
    return 0;
}
```