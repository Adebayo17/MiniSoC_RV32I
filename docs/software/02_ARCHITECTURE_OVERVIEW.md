# Software Architecture Overview

## Introduction
This document describes the software architecture of the Mini RV32I SoC firmware. The architecture is explicitly designed for a strict bare-metal embedded system (no Operating System, no standard C library, no hardware interrupts).

The entire codebase strictly adheres to the **Barr Group Embedded C Coding Standard**, focusing on safety, modularity, and explicit hardware abstraction.


## Core Architectural Principles

### 1. Bare-Metal & No-IRQ Design
- Direct hardware control through Memory-Mapped I/O (MMIO).
- Absence of hardware interrupts (IRQs) means all peripheral management relies on highly predictable, non-blocking state machines and status polling.
- Minimal runtime overhead and total control over the execution flow.

### 2. Object-Oriented C (Polymorphism)
- While written in C, the architecture uses structure inclusion to mimic inheritance.
- Every hardware driver inherits from a base `peripheral_t` class, allowing generic validation and initialization routines.

### 3. Error-First & Single Exit Point
- Any function that can fail returns a `system_error_t` enum.
- Forbidden use of goto, continue, or multiple return statements in the middle of functions.
- Errors are propagated using cascading `if (is_success(status))` blocks to guarantee proper cleanup.

### 4. Memory Safety & Strict Alignment
- Pointers and addresses are validated before access (`system_validate_address`).
- RISC-V hardware alignment rules are strictly enforced in software before executing memory operations to prevent silent hardware traps.


## Software Stack Layers

### Layer Diagram
```text
┌─────────────────────────────────────────────────────┐
│ APPLICATION LAYER (sw/src/main.c, sw/tests)         │
│ • Main program superloop                            │
│ • State machines and business logic                 │
│ Dependencies: Driver API & System API               │
├─────────────────────────────────────────────────────┤
│ DRIVER ABSTRACTION LAYER (sw/drivers/)              │
│ • Peripheral drivers (UART, GPIO, Timer)            │
│ • Object-Oriented Handles (uart_t, gpio_t)          │
│ • Shadow caching of hardware states                 │
│ Dependencies: HAL & Registec Access Layer           │
├─────────────────────────────────────────────────────┤
│ HARDWARE ABSTRACTION LAYER (HAL) (sw/include)       │
│ • System timebase and safe delays (system.c)        │
│ • Safe memory manipulation (memory.c)               │
│ • Software Math fallbacks (math.c)                  │
│ Dependencies: Register Access Layer & Error Codes   │
├─────────────────────────────────────────────────────┤
│ REGISTER ACCESS LAYER                               │
│ • Typed inline functions for MMIO                   │
│ • Bit manipulation macros (SET_BIT, CLEAR_BIT)      │
│ • Strict 32-bit volatile enforcement                │
│ Dependencies: Hardware (Wishbone bus)               │
└─────────────────────────────────────────────────────┘
```


## Detailed Layer Description

### 1. Register Access Layer
**Purpose:** Provide safe, type-checked access to hardware registers through the Wishbone bus.

To comply with Barr Group rules, we do **not** use unsafe parameterized macros for memory access. Instead, we use `static inline` functions to ensure strict type checking.

```c
// Example from register_access.h
static inline void write_reg32(uint32_t address, uint32_t value) {
    *((volatile uint32_t *)address) = value; // Forces hardware access
}

// Atomic bit manipulation
SET_BIT(hw->CTRL, UART_CTRL_TX_ENABLE_POS);
```


### 2. Hardware Abstraction Layer (HAL)
**Purpose:** Provide hardware-independent core services to higher layers.

- **System & Time (`system.h/c`):** Manages the continuous system timer. Provides `system_delay_us_safe()` and non-blocking timeout polling without relying on IRQs.

- **Memory (`memory.h/c`):** Provides bare-metal implementations of `memset`, `memcpy`, and `memmove`, augmented with rigorous boundary and overlap checking.

- **Math (`math.h/c`):** Since the RV32I core lacks the `M` extension, this layer provides fast software implementations for multiplication and division.

- **Errors (`errors.h`):** Defines `system_error_t` and inline helpers like `is_success()` and `is_error()`.


### 3. Driver Abstraction Layer
**Purpose:** Provide high-level interfaces to peripherals using an Object-Oriented approach.

Every driver handle MUST have `peripheral_t` as its first member. This allows safe pointer casting to generic validation functions.

```c
/* Base Class */
typedef struct {
    uint32_t base_address;
    bool     initialized;
} peripheral_t;

/* Derived Class (UART) */
typedef struct {
    peripheral_t    base;   // Inheritance: MUST be first
    uart_config_t   config; // Software cache
    uart_status_t   status; // Software cache
} uart_t;
```

**Hardware/Software Separation:** Drivers are split between `uart_hw.h` (pure register maps and bit masks) and `uart.h` (software API and handles).


### 4. Application Layer
**Purpose:** Implement user logic using the services provided by lower layers. It never interacts with raw memory addresses.

```c
// Application Template Pattern
int main(void) {
    system_error_t status = SYSTEM_SUCCESS;
    gpio_t gpio_dev;
    
    system_init();
    
    status = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    
    if (is_success(status)) {
        status = gpio_configure_pin(&gpio_dev, ...);
    }
    
    if (is_error(status)) {
        handle_critical_error(); // Single failure path
    }
    
    while(1) {
        // Main Superloop (Polling)
    }
    return 0;
}
```


## Design Patterns & Best Practices

### 1. The "Single Exit Point" Pattern

To avoid spaghetti code and memory leaks, goto and multiple return statements are strictly forbidden. Operations are chained safely:

```c
// CORRECT: Barr Group Compliant Flow
system_error_t perform_task(void) {
    system_error_t status = SYSTEM_SUCCESS;
    
    status = step_one();
    
    if (is_success(status)) {
        status = step_two();
    }
    
    if (is_success(status)) {
        status = step_three();
    }
    
    // Cleanup is always reached, regardless of where it failed
    cleanup_resources();
    
    return status; // Single return
}
```


### 2. Multi-Level Error Translation

Hardware exceptions are safely caught and translated up the stack:

1. Hardware Layer: The Wishbone bus returns 0xDEADBEEF if a non-existent address is accessed.
2. HAL Layer: system_read_word_safe() detects 0xDEADBEEF and returns SYSTEM_ERROR_INVALID_ADDRESS.
3. Driver Layer: Safely aborts the transaction and passes the error up.
4. Application: Receives SYSTEM_ERROR_INVALID_ADDRESS and flashes an error LED.


### 3. Shadow Caching

Reading from the Wishbone bus is slower than reading from the CPU's internal RAM. To optimize performance, drivers cache their configuration and status in RAM (e.g., `dev->config.baudrate`). The software reads this cache instead of querying the hardware repeatedly.


## Related Documentation
To keep this overview concise, specific architectural implementations are detailed in the following documents:

- [Memory Map](03_MEMORY_MAP.md): Detailed address space layout (IMEM, DMEM, Peripherals).
- [Build System](04_BUILD_SYSTEM.md): Compilation flow and Makefile architecture.
- [Boot Process](06_BOOT_PROCESS.md): Details on the Cold Boot Sequence (`startup.S` -> C Environment Setup -> `main`).
- [Error Handling](08_ERROR_HANDLING.md): Complete guide on `system_error_t` and assertions.

