# Timer Driver API

## Introduction

The Timer driver provides precise timekeeping, blocking delays, and non-blocking timeout capabilities for the Mini RV32I SoC.

The hardware consists of a 32-bit up-counter with a programmable prescaler and a compare match register. Because the SoC does not support hardware interrupts, the timer driver relies entirely on polling hardware flags (`MATCH` and `OVERFLOW`) to detect when a specified time period has elapsed.

---

## Hardware / Software Separation

The Timer driver adheres to the project's layered architecture:

1. **Hardware Layer (`timer_hw.h`)**: Defines the memory-mapped registers (`REG_COUNT`, `REG_CMP`, `REG_CTRL`, `REG_STATUS`) and their respective bit fields. It is strictly internal to the driver.

2. **Software Layer (`timer.h` / `timer.c`)**: Provides the Object-Oriented C API, exposing the `timer_t` handle, configuration structures, and standard functions.

---

## The Driver Handle (`timer_t`)

To interact with the Timer, you must instantiate a `timer_t` object. This handle caches the hardware state to prevent unnecessary Wishbone bus accesses and stores the system clock frequency required to calculate accurate delays.

```c
typedef struct timer_system {
    peripheral_t        base;            /*!< Inherited base class */
    uint32_t            clock_frequency; /*!< Required for time math (e.g., 100000000) */
    timer_config_t      config;          /*!< Cache of mode and prescaler */
    timer_status_t      status;          /*!< Cache of match/overflow flags */
} timer_t;
```

---

## Initialization

The Timer requires the system's clock frequency during initialization. This allows the driver to automatically compute the correct `CMP` (Compare) values for any requested microsecond or millisecond delay.

```c
#include "system.h"
#include "errors.h"
#include "timer.h"

system_error_t setup_timer(timer_t *timer_dev) {
    system_error_t status = SYSTEM_SUCCESS;

    /* Initialize the handle with base address and clock frequency */
    status = timer_init(timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);

    return status;
}
```

*Note: `timer_init` automatically issues a hardware reset to the timer, ensuring the counter starts at zero and all old status flags are cleared.*

---

## High-Level Timing Functions

The driver provides abstracted functions that handle the complex math of converting microseconds into hardware clock ticks.

### 1. Blocking Delays

A blocking delay halts the CPU execution until the time has elapsed. The driver configures the timer in `ONESHOT` mode, sets the appropriate `CMP` value, starts the timer, and traps the CPU in a `while` loop until the `MATCH` flag is asserted by the hardware.

```c
/* Safely halt execution for 10 milliseconds */
status = timer_delay_ms(&timer_dev, 10U);

/* Safely halt execution for 500 microseconds */
status = timer_delay_us(&timer_dev, 500U);
```

### 2. Non-Blocking Timeouts (Asynchronous)

For responsive applications (like a main superloop reading sensors and blinking LEDs simultaneously), you must use non-blocking timeouts.

You start the timeout once, and then poll its status without halting the CPU.

```c
/* Start a 1-second (1,000,000 us) background timeout */
status = timer_start_timeout(&timer_dev, 1000000U, TIMER_MODE_ONESHOT);

if (is_success(status)) {
    bool timeout_reached = false;

    while (1) {
        /* Do other background tasks here (e.g., UART processing) */
        
        /* Check if the 1 second has passed */
        (void)timer_is_timeout(&timer_dev, &timeout_reached);
        
        if (timeout_reached) {
            /* Execute periodic task */
            do_something_periodic();
            
            /* Restart the timeout for the next cycle */
            (void)timer_start_timeout(&timer_dev, 1000000U, TIMER_MODE_ONESHOT);
        }
    }
}
```

---

## Low-Level Configuration & Modes

If you need specific hardware behaviors beyond simple delays, you can manually configure the timer's mode and prescaler.

### Timer Modes (`timer_mode_t`)

- `TIMER_MODE_CONTINUOUS`: The counter resets to `0` upon reaching the `CMP` value and continues counting indefinitely. Ideal for generating a continuous system timebase.
- ``TIMER_MODE_ONESHOT``: The counter stops automatically when it reaches the `CMP` value. Ideal for single-use delays.

### Hardware Prescaler (```timer_prescale_t```)

The prescaler divides the system clock before it reaches the counter, allowing the timer to count much longer durations before overflowing its 32-bit register.

- `TIMER_PRESCALE_1` (Default)
- `TIMER_PRESCALE_8`
- `TIMER_PRESCALE_64`
- `TIMER_PRESCALE_1024`

### Example: Manual Configuration
```c
timer_config_t config;
config.mode          = TIMER_MODE_CONTINUOUS;
config.prescale      = TIMER_PRESCALE_1024;
config.compare_value = 50000U;

status = timer_configure(&timer_dev, &config);

if (is_success(status)) {
    /* Start the timer manually */
    status = timer_enable(&timer_dev);
}
```

---

## Status Clearing (Write-1-To-Clear)

The hardware timer uses a "Write-1-to-Clear" (W1C) logic for its status flags. This means that once a `MATCH` or `OVERFLOW` occurs, the flag stays asserted (at `1`) until the software explicitly writes a `1` back to it to clear it.

If you are using the manual API (e.g., `timer_is_match`), you must clear the flag yourself after processing the event:

```c
bool is_match = false;
status = timer_is_match(&timer_dev, &is_match);

if (is_success(status) && is_match) {
    /* Process the event */
    
    /* Acknowledge and clear the flag in hardware */
    status = timer_clear_match(&timer_dev);
}
```

*Note: High-level functions like `timer_delay_ms` or `timer_start_timeout` automatically clear these flags for you.*

---

## Dependency Note: Software Math

To convert real-world time (`microseconds`) into hardware limits (`compare_value`), the timer driver internally relies on division operations.

Because the Mini RV32I does not include the hardware multiplication/division extension (`M`), the timer driver safely offloads these calculations to the `system_udiv32` functions provided by `math.h`.