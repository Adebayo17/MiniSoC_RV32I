# Software Architecture Overview

## Introduction
This document describes the software architecture of the Mini RV32I SoC firmware. The architecture is designed for bare-metal embedded systems with a focus on modularity, error handling, and hardware abstraction.


## Architecture Principles

### 1. Bare-Metal Design
- No operating system dependencies
- Direct hardware control through memory-mapped I/O
- Minimal runtime overhead
- Full control over memory layout and resource usage

### 2. Layered Abstraction
- Clear separation between hardware access and application logic
- Each layer provides services to the layer above
- Hardware details encapsulated at the lowest level

### 3. Error-First Design
- All functions that can fail return `system_error_t`
- Comprehensive error codes for different failure modes
- Hardware error detection through Wishbone responses

### 4. Memory Safety
- Address validation before access
- Buffer boundary checking
- Alignment requirements enforcement


## Software Stack Layers

### Layer Diagram
```text
┌─────────────────────────────────────────────────────┐
│ APPLICATION LAYER                                   │
│ • Main program logic                                │
│ • Test programs                                     │
│ • User applications                                 │
│ Dependencies: Driver Abstraction Layer              │
├─────────────────────────────────────────────────────┤
│ DRIVER ABSTRACTION LAYER                            │
│ • Peripheral drivers (UART, GPIO, Timer)            │
│ • Hardware-specific implementations                 │
│ • Error handling and validation                     │
│ Dependencies: Hardware Abstraction Layer            │
├─────────────────────────────────────────────────────┤
│ HARDWARE ABSTRACTION LAYER (HAL)                    │
│ • System initialization                             │
│ • Memory management                                 │
│ • Time management                                   │
│ • Math utilities                                    │
│ Dependencies: Register Access Layer                 │
├─────────────────────────────────────────────────────┤
│ REGISTER ACCESS LAYER                               │
│ • Memory-mapped I/O operations                      │
│ • Bit manipulation macros                           │
│ • Atomic register operations                        │
│ Dependencies: Hardware (Wishbone bus)               │
└─────────────────────────────────────────────────────┘
```


## Detailed Layer Description

### 1. Register Access Layer

#### Purpose
Provide safe, efficient access to hardware registers through the Wishbone bus.

#### Key Components
```c
// register_access.h
#define READ_REG(addr)      (*(volatile uint32_t *)(addr))
#define WRITE_REG(addr, val) (*(volatile uint32_t *)(addr) = (val))
#define SET_BITS(addr, mask) // Atomic set
#define CLEAR_BITS(addr, mask) // Atomic clear
#define MODIFY_BITS(addr, mask, val) // Atomic modify
```

#### Characteristics
- **Direct memory access**: No function call overhead for register access
- **Volatile qualifier**: Prevents compiler optimization of hardware access
- **Atomic operations**: SET/CLEAR/MODIFY macros for safe concurrent access
- **Bit manipulation**: BITMASK, GET_FIELD, SET_FIELD macros


#### Example Usage
```c
// Reading a register
uint32_t status = READ_REG(UART_BASE_ADDRESS + REG_STATUS_OFFSET);

// Setting bits atomically
SET_BITS(GPIO_BASE_ADDRESS + REG_GPIO_SET_OFFSET, GPIO_PIN_MASK_0);
```


### 2. Hardware Abstraction Layer (HAL)

#### Purpose
Provide hardware-independent services to higher layers.

#### Components

##### A. System Services (`system.h/c`)
- System initialization and configuration
- Clock and time management
- Delay functions (blocking and non-blocking)
- Address validation
- System reset

##### B. Memory Services (`memory.h/c`)
- Safe memory access (byte, half-word, word)
- Standard memory functions (memcpy, memset, memcmp)
- Address range validation
- Alignment checking


##### C. Error Handling (`errors.h`)
- Error code definitions (system_error_t)
- Hardware error pattern detection
- Error checking macros (IS_ERROR, IS_SUCCESS)


##### D. Math Utilities (`math.h/c`)
- Software implementations for RV32I (no M extension)
- Multiplication, division, modulus
- Fast power-of-two operations


#### Design Patterns
```c
// All HAL functions follow this pattern:
system_error_t hal_function(params, result*);

// Example: Safe memory read
system_error_t err = system_read_word_safe(address, &value);
if (IS_ERROR(err)) {
    // Handle error
}
```


### 3. Driver Abstraction Layer

#### Purpose
Provide high-level, hardware-independent interfaces to peripherals.


#### Driver Structure
Each driver follows this pattern:
```c
typedef struct {
    peripheral_t    base;       // Base structure (inheritance)
    driver_config_t config;     // Current configuration
    driver_status_t status;     // Current status
} driver_t;
```

#### Common Driver API Pattern
```c
// Initialization
system_error_t driver_init(driver_t *dev, uint32_t base_addr);

// Configuration
system_error_t driver_configure(driver_t *dev, const config_t *config);

// Operation
system_error_t driver_operation(driver_t *dev, params...);

// Status
system_error_t driver_get_status(driver_t *dev, status_t *status);

// Cleanup
system_error_t driver_deinit(driver_t *dev);
```

#### Available Drivers

##### UART Driver (uart.h/c)
- Serial communication (TX/RX)
- Baud rate configuration
- Status monitoring (TX ready, RX available, errors)
- Blocking and timeout-based operations


##### GPIO Driver (gpio.h/c)
- Pin direction control (input/output)
- Pin read/write operations
- Atomic set/clear/toggle operations
- Port-level operations


##### Timer Driver (timer.h/c)
- 32-bit up-counter
- Compare match functionality
- Continuous and one-shot modes
- Prescaler configuration
- Delay and timeout functions


### 4. Application Layer

#### Purpose
Implement user logic using the services provided by lower layers.

#### Structure
```text
Application Layer
├── Main Program (sw/src/main.c)
├── Test Programs (sw/tests/)
│   ├── Peripheral unit tests
│   ├── Integration tests
│   └── System tests
└── User Applications
    ├── Custom main.c
    └── Additional modules
```

#### Application Template
```c
#include "system.h"
#include "drivers/uart/include/uart.h"
#include "drivers/gpio/include/gpio.h"
#include "drivers/timer/include/timer.h"

int main(void) {
    // 1. Initialize system
    system_init();
    
    // 2. Initialize peripherals
    uart_t uart0;
    gpio_t gpio0;
    timer_t timer0;
    
    // 3. Configure peripherals
    // 4. Implement application logic
    // 5. Main loop or event-driven processing
    
    return 0;
}
```


## Header Dependencies and Includion 

### Dependency Graph
```text
main.c (Application)
├── system.h (HAL)
│   ├── register_access.h (Register Layer)
│   ├── errors.h
│   ├── memory.h
│   └── math.h
├── uart.h (Driver)
│   └── peripheral.h (Base)
├── gpio.h (Driver)
│   └── peripheral.h (Base)
└── timer.h (Driver)
    └── peripheral.h (Base)
```

### Inclusion Guidelines
1. **Never include `.c` files**
2. **Minimize header dependencies**
3. **Use forward declarations when possible**
4. **Include what you use (IWYU principle)**
5. **Group includes by layer**:

```c
// System headers (HAL)
#include "system.h"
#include "memory.h"
#include "errors.h"

// Driver headers
#include "uart.h"
#include "gpio.h"
#include "timer.h"

// Standard headers (if needed)
#include <stdint.h>
#include <stdbool.h>
```


## Memory Architecture

### Address Space Organization
```text
0x00000000 ┌─────────────────┐
           │     IMEM        │ 32 KB
           │   (.text,       │ Read-only
           │    .rodata)     │ 
0x00007FFF ├─────────────────┤
           │                 │
           │    Unused       │
           │                 │
0x0FFFFFFF ├─────────────────┤
0x10000000 ┌─────────────────┐
           │     DMEM        │ 16 KB
           │   (.data,       │ Read-write
           │    .bss,        │
           │    heap,        │
           │    stack)       │
0x10003FFF ├─────────────────┤
           │                 │
           │    Unused       │
           │                 │
0x1FFFFFFF ├─────────────────┤
0x20000000 ┌─────────────────┐
           │     UART        │ 4 KB
           │   Peripheral    │
0x20000FFF ├─────────────────┤
0x30000000 ┌─────────────────┐
           │     TIMER       │ 4 KB
           │   Peripheral    │
0x30000FFF ├─────────────────┤
0x40000000 ┌─────────────────┐
           │     GPIO        │ 4 KB
           │   Peripheral    │
0x40000FFF └─────────────────┘
```

### Memory Sections

- `.text`: Executable code (IMEM)
- `.rodata`: Read-only data (IMEM)
- `.data`: Initialized variables (DMEM, loaded from IMEM)
- `.bss`: Zero-initialized variables (DMEM)
- `.heap`: Dynamic memory allocation (DMEM)
- `.stack`: Function call stack (DMEM, grows downward)


## Error Handling architecture

### Multi-Level Error Handling
```text
┌─────────────────────────────────┐
│      Application Layer          │
│  • User error handling          │
│  • Graceful degradation         │
├─────────────────────────────────┤
│      Driver Layer               │
│  • Parameter validation         │
│  • Hardware status checking     │
│  • Error code translation       │
├─────────────────────────────────┤
│      HAL Layer                  │
│  • Address validation           │
│  • Hardware error detection     │
│  • Error code propagation       │
├─────────────────────────────────┤
│      Hardware Layer             │
│  • Wishbone error responses     │
│  • 0xDEADBEEF (invalid addr)    │
│  • 0xBADADD01 (invalid slave)   │
└─────────────────────────────────┘
```

### Error Propagation Example
```c
// Hardware returns error
READ_REG(0xDEADBEEF) → returns 0xDEADBEEF

// HAL detects hardware error
system_read_word_safe() → returns SYSTEM_ERROR_INVALID_ADDRESS

// Driver propagates error
uart_receive_byte() → returns SYSTEM_ERROR_INVALID_ADDRESS

// Application handles error
err = uart_receive_byte(&uart0, &data, 1000);
if (err == SYSTEM_ERROR_INVALID_ADDRESS) {
    // Reset communication
    uart_reset(&uart0);
}
```


## Boot Process architecture

### Cold Boot Sequence
```text
1. CPU Reset
   ↓
2. Fetch from IMEM[0] (startup.S)
   ↓
3. Initialize Stack Pointer (_estack)
   ↓
4. Copy .data from IMEM to DMEM
   ↓
5. Zero .bss section in DMEM
   ↓
6. Call system_init()
   ↓
7. Call main()
   ↓
8. Application Execution
```

### Startup Code (`startup.S`)
```assembly
_start:
    // Setup stack pointer
    la sp, _estack
    
    // Initialize .bss (zero it)
    la t0, _sbss
    la t1, _ebss
    bss_loop:
        sw zero, 0(t0)
        addi t0, t0, 4
        blt t0, t1, bss_loop
    
    // Copy .data from IMEM to DMEM
    la t0, _sidata    // Source in IMEM
    la t1, _sdata     // Destination in DMEM
    la t2, _edata
    data_loop:
        lw t3, 0(t0)
        sw t3, 0(t1)
        addi t0, t0, 4
        addi t1, t1, 4
        blt t1, t2, data_loop
    
    // Jump to main()
    call main
    
    // If main returns, hang
    hang:
        j hang
```

## Build System Integration

### Compilation Flow
```text
.c/.S files
    ↓ (Compiler: riscv32-unknown-elf-gcc)
.o object files
    ↓ (Linker: riscv32-unknown-elf-ld)
.elf executable
    ↓ (Objcopy: riscv32-unknown-elf-objcopy)
.bin/.hex/.mem files
```


### Layer-Specific Compilation Flags
```makefile
# Register Layer: No special flags
# HAL Layer: Standard optimization
CFLAGS += -Os -Wall -Wextra

# Driver Layer: Hardware-specific knowledge
CFLAGS += -I$(DRIVER_INCLUDE_DIR)

# Application Layer: User configuration
CFLAGS += -DAPPLICATION_CONFIG=1
```

## Design Patterns and Best Practices

### 1. Resource Management Pattern
```c
// Acquire resource
system_error_t err = peripheral_init(&dev, BASE_ADDRESS);
if (IS_ERROR(err)) goto cleanup;

// Use resource
err = peripheral_operation(&dev);
if (IS_ERROR(err)) goto cleanup;

// Release resource
cleanup:
    peripheral_deinit(&dev);
    return err;
```

### 2. Configuration Pattern
```c
// Define configuration
peripheral_config_t config = {
    .mode = MODE_CONTINUOUS,
    .param = DEFAULT_VALUE,
    .callback = NULL
};

// Apply configuration
system_error_t err = peripheral_configure(&dev, &config);
```


### 3. Status Monitoring Pattern
```c
peripheral_status_t status;
system_error_t err = peripheral_get_status(&dev, &status);
if (IS_ERROR(err)) {
    // Handle error
}

if (status.is_ready) {
    // Perform operation
}
```

## Performance Considerations
### 1. Register Access Optimization
- Use `READ_REG`/`WRITE_REG` for single accesses
- Use `SET_BITS`/`CLEAR_BITS` for atomic bit manipulation
- Avoid read-modify-write cycles when hardware provides atomic operations


### 2. Function Call Overhead
- Critical paths use inline functions or macros
- Error checking adds overhead but improves reliability
- Trade-off based on application requirements


### 3. Memory Usage
- `.text` in IMEM (32KB limit)
- `.data` + `.bss` + heap + stack in DMEM (16KB limit)
- Use `-Os` optimization to reduce code size


## Security Considerations
### 1. Memory Safety
- All memory accesses validated
- Buffer boundaries checked
- Stack overflow detection through linker assertions

### 2. Hardware Access Control
- Address validation prevents access to unauthorized regions
- Peripheral initialization required before use
- Error detection for invalid hardware responses

### 3. Code Integrity
- Read-only code in IMEM
- `.data` integrity through checks (optional extension)
- Stack protection through size limits


## Extension Points
### 1. Adding New Peripherals
- Create driver header (`peripheral.h`) following the driver pattern
- Implement driver (`peripheral.c`)
- Add to build system (`include.sw.mk`)
- Update memory map documentation

### 2. Adding System Services
- Add to HAL layer if hardware-independent
- Add to specific driver if hardware-dependent
- Follow existing error handling patterns
- Update documentation

### 3. Customizing Memory Layout
- Modify `sw/linker.ld`
- Update `system.h` memory definitions
- Adjust startup code if needed
- Update memory map documentation


## Related Documentation
- [Memory Map](./03_MEMORY_MAP.md) - Detailed address space layout
- [Build System](./04_BUILD_SYSTEM.md) - Compilation and linking process
- [Driver Documentation](./06_DRIVERS/) - Individual driver APIs
- [Examples and Tests](./08_EXAMPLES_TESTS.md) - Usage examples


## Conclusion
The Mini RV32I software architecture provides a robust foundation for bare-metal embedded development. Its layered design promotes modularity, maintainability, and reliability while maintaining the performance characteristics required for embedded systems.

The architecture is designed to be extensible, allowing developers to add new peripherals, system services, or custom applications while maintaining compatibility with existing code.