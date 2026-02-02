# Memory Map

## Introduction
This document defines the complete memory map of the Mini RV32I SoC. Understanding this memory organization is crucial for bare-metal programming, as all hardware access occurs through memory-mapped I/O.

## Address Space Overview

### 32-bit Address Space Layout
```text
┌─────────────────────────────────────────────────────┐
│ 0x0000_0000 ┌─────────────────────────────────────┐ │
│ │ IMEM (32 KB)                                    │ │
│ │ Instructions &                                  │ │
│ │ Read-Only Data                                  │ │
│ 0x0000_7FFF ├─────────────────────────────────────┤ │
│ │ UNUSED                                          │ │
│ │ (3.75 GB Gap)                                   │ │
│ 0x0FFF_FFFF ├─────────────────────────────────────┤ │
│ 0x1000_0000 ┌─────────────────────────────────────┐ │
│ │ DMEM (16 KB)                                    │ │
│ │ Data Memory                                     │ │
│ │ (Variables, Heap, Stack)                        │ │
│ 0x1000_3FFF ├─────────────────────────────────────┤ │
│ │ UNUSED                                          │ │
│ │ (255 MB Gap)                                    │ │
│ 0x1FFF_FFFF ├─────────────────────────────────────┤ │
│ 0x2000_0000 ┌─────────────────────────────────────┐ │
│ │ UART (4 KB)                                     │ │
│ │ Serial Communication                            │ │
│ 0x2000_0FFF ├─────────────────────────────────────┤ │
│ │ UNUSED                                          │ │
│ │ (256 MB Gap)                                    │ │
│ 0x2FFF_FFFF ├─────────────────────────────────────┤ │
│ 0x3000_0000 ┌─────────────────────────────────────┐ │
│ │ TIMER (4 KB)                                    │ │
│ │ System Timer                                    │ │
│ 0x3000_0FFF ├─────────────────────────────────────┤ │
│ │ UNUSED                                          │ │
│ │ (256 MB Gap)                                    │ │
│ 0x3FFF_FFFF ├─────────────────────────────────────┤ │
│ 0x4000_0000 ┌─────────────────────────────────────┐ │
│ │ GPIO (4 KB)                                     │ │
│ │ General Purpose I/O Pins                        │ │
│ 0x4000_0FFF └─────────────────────────────────────┘ │
│ │ UNUSED                                          │ │
│ │ (3.0 GB Gap)                                    │ │
│ 0xFFFF_FFFF └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```


### Memory Region Summary Table
| Region    | Base Address  | End Address | Size    | Description           | Access     | Wishbone Slave ID    |
|-----------|---------------|-------------|---------|-----------------------|------------|----------------------|
| IMEM      | 0x0000_0000   | 0x0000_7FFF | 32 KB   | Instruction Memory    | Read-Only  | 0                    |
| DMEM      | 0x1000_0000   | 0x1000_3FFF | 16 KB   | Data Memory           | Read/Write | 1                    |
| UART      | 0x2000_0000   | 0x2000_0FFF | 4 KB    | UART Peripheral       | Read/Write | 2                    |
| TIMER     | 0x3000_0000   | 0x3000_0FFF | 4 KB    | Timer Peripheral      | Read/Write | 3                    |
| GPIO      | 0x4000_0000   | 0x4000_0FFF | 4 KB    | GPIO Peripheral       | Read/Write | 4                    |



## Detailed Memory Regions

### 1. Instruction Memory (IMEM) - 0x00000000 to 0x00007FFF (32 KB)

#### Purpose
- Stores executable code (`.text` section)
- Contains read-only data (`.rodata` section)
- Initial values for `.data` section (copy source)

#### Characteristics
- **Read-only**: CPU can fetch instructions, but cannot write
- **Word-aligned access**: 32-bit reads only
- **Initialized at reset**: Loaded with firmware binary
- **No runtime modification**: Constants and code only

#### Linker Script Organization
```ld
MEMORY {
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS {
    .text : {
        *(.init)           # Startup code
        *(.text .text.*)   # Program code
        *(.rodata .rodata.*) # Constants
        _etext = .;        # End marker
    } > IMEM
}
```

### 2. Data Memory (DMEM) - 0x10000000 to 0x10003FFF (16 KB)

#### Purpose
- Stores global and static variables
- Provides heap for dynamic allocation
- Contains call stack
- Runtime data storage


#### Internal Organizations
```text
0x1000_0000 ┌─────────────────────────────────────┐
            │                                     │
            │          .data section              │
            │    (Initialized variables)          │
            │           8 KB (0x2000)             │
            │                                     │
0x1000_1FFF ├─────────────────────────────────────┤
            │                                     │
            │          .bss section               │
            │   (Zero-initialized variables)      │
            │   Size: variable (up to heap_start) │
            │                                     │
0x1000_1FFF+├─────────────────────────────────────┤
            │                                     │
            │           HEAP region               │
            │      (Dynamic memory allocation)    │
            │           4 KB (0x1000)             │
            │                                     │
0x1000_2FFF ├─────────────────────────────────────┤
            │                                     │
            │           STACK region              │
            │        (Function call stack)        │
            │           4 KB (0x1000)             │
            │         (Grows downward)            │
            │                                     │
0x1000_3FFF └─────────────────────────────────────┘
```

#### Linker Script Definitions
```ld
/* Data section (initialized variables) */
_sdata = .;        /* Start of .data in DMEM */
_edata = .;        /* End of .data in DMEM */
_sidata = LOADADDR(.data); /* Load address in IMEM */

/* BSS section (zero-initialized) */
_sbss = .;         /* Start of .bss */
_ebss = .;         /* End of .bss */

/* Heap (4KB) */
_heap_start = .;
. += 0x1000;       /* 4KB = 0x1000 bytes */
_heap_end = .;

/* Stack (4KB, grows downward) */
_estack = ORIGIN(DMEM) + LENGTH(DMEM); /* Top of DMEM */
_sstack = _estack - 0x1000;           /* Bottom of stack */
```

#### Memory Usage Validation
```c
// In system.h - compile-time checks
#define TOTAL_DMEM_USED (DATA_SECTION_SIZE + HEAP_SIZE + STACK_SIZE)
#if TOTAL_DMEM_USED > DMEM_SIZE
    #error "DMEM layout exceeds available memory!"
#endif

#if HEAP_BASE_ADDRESS < (DATA_SECTION_BASE + DATA_SECTION_SIZE)
    #error "Heap overlaps with data section!"
#endif

#if STACK_END_ADDRESS < (HEAP_BASE_ADDRESS + HEAP_SIZE)
    #error "Stack overlaps with heap!"
#endif
```

### Peripheral Memory Regions
### 3. UART Peripheral - 0x20000000 to 0x20000FFF (4 KB)

#### Register Map

| Offset    | Register Name | Width     | Access | Reset Value  | Description                           |
|-----------|---------------|-----------|--------|--------------|---------------------------------------|
| `0x00`    | TX_DATA       | 8-bit     | Write  | Undefined    | Transmit Data Register                |
| `0x04`    | RX_DATA       | 8-bit     | Read   | Undefined    | Receive Data Register                 |
| `0x08`    | BAUD_DIV      | 16-bit    | R/W    | 0x0363       | Baud Rate Divisor (115200 @ 100MHz)   |
| `0x0C`    | CTRL          | 8-bit     | R/W    | 0x00000000   | Control Register                      |
| `0x10`    | STATUS        | 8-bit     | Read   | 0x00000001   | Status Register                       |


#### Register Details

**TX_DATA Register (Write-only)**
```
Bits 31:8: Reserved (read as 0)
Bits 7:0: TX_DATA[7:0] - Data to transmit
```

**RX_DATA Register (Read-only)**
```text
Bits 31:8: Reserved (read as 0)
Bits 7:0: RX_DATA[7:0] - Received data
```

**BAUD_DIV Register**
```
Bits 31:16: Reserved (read as 0)
Bits 15:0: DIVISOR[15:0] - Baud rate divisor
Calculation: divisor = system_clock / (16 * baud_rate)
Example: 100MHz / (16 * 115200) = 54.25 ≈ 54 (0x36)
```

**CTRL Register**
```text
Bit 31:2: Reserved (write as 0, read undefined)
Bit 1: RX_ENABLE - 1=Enable receiver, 0=Disable receiver
Bit 0: TX_ENABLE - 1=Enable transmitter, 0=Disable transmitter
```

**STATUS Register**
```text
Bit 31:5: Reserved (read as 0)
Bit 4: RX_FRAME_ERROR - 1=Frame error detected
Bit 3: RX_OVERRUN - 1=Receive overrun (data lost)
Bit 2: RX_READY - 1=Receive data available
Bit 1: TX_BUSY - 1=Transmitter busy
Bit 0: TX_EMPTY - 1=Transmit buffer empty (ready for new data)
```

#### Usage Example 
```c
// Direct register access
WRITE_REG(UART_BASE_ADDRESS + 0x00, 'A');  // Transmit 'A'
uint32_t status = READ_REG(UART_BASE_ADDRESS + 0x10);
if (status & (1 << 2)) {  // Check RX_READY
    uint8_t data = READ_REG(UART_BASE_ADDRESS + 0x04) & 0xFF;
}

// Using driver API (recommended)
uart_t uart_dev;
uart_init(&uart_dev, UART_BASE_ADDRESS);
uart_transmit_byte(&uart_dev, 'A', 100);  // 100ms timeout
```

### 4. Timer Peripheral - 0x30000000 to 0x30000FFF (4 KB)

#### Register Map

| Offset    | Register Name | Width   | Access | Reset Value   | Description            |
|-----------|---------------|---------|--------|---------------|------------------------|
| `0x00`    | COUNT         | 32-bit  | Read   | 0x00000000    | Current Timer Count    |
| `0x04`    | CMP           | 32-bit  | R/W    | 0xFFFFFFFF    | Compare Value          |
| `0x08`    | CTRL          | 32-bit  | R/W    | 0x00000000    | Control Register       |
| `0x0C`    | STATUS        | 32-bit  | R/W    | 0x00000000    | Status Register        |

#### Register Details

**COUNT Register (Read-only)**
```text
Bits 31:0: COUNT[31:0] - Current timer value
Increments on each prescaled clock tick
Wraps from 0xFFFFFFFF to 0x00000000
```

**CMP Register**
```text
Bits 31:0: COMPARE[31:0] - Compare value
When COUNT == CMP, match flag is set
Minimum value: 2 (value 1 might be missed)
```

**CTRL Register**
```text
Bits 31:5: Reserved (write as 0, read undefined)
Bits 4:3: PRESCALE[1:0] - Clock prescaler
           00 = /1, 01 = /8, 10 = /64, 11 = /1024
Bit 2: ONESHOT - 1=One-shot mode, 0=Continuous mode
Bit 1: RESET - Write 1 to reset counter (auto-clears)
Bit 0: ENABLE - 1=Timer enabled, 0=Timer disabled
```


**STATUS Register**
```text
Bits 31:2: Reserved (write as 0, read undefined)
Bit 1: OVERFLOW - 1=Counter overflow occurred (write 0 to clear)
Bit 0: MATCH - 1=Compare match occurred (write 0 to clear)
```


#### Timing Calculation
```text
Timer period = (prescaler / system_clock)
Match time = (CMP value * prescaler / system_clock)
Example: 1ms timeout @ 100MHz with /1 prescaler
CMP = (time * clock_freq) / prescaler
    = (0.001 * 100,000,000) / 1
    = 100,000
```

#### Usage Example
```c
// Configure timer for 1ms periodic interrupts
WRITE_REG(TIMER_BASE_ADDRESS + 0x04, 100000);  // CMP = 100,000
WRITE_REG(TIMER_BASE_ADDRESS + 0x08, 0x01);    // ENABLE=1, Continuous

// Check for match
uint32_t status = READ_REG(TIMER_BASE_ADDRESS + 0x0C);
if (status & 0x01) {
    // Match occurred
    WRITE_REG(TIMER_BASE_ADDRESS + 0x0C, 0x00);  // Clear match flag
}

// Using driver API
timer_t timer_dev;
timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
timer_delay_ms(&timer_dev, 100);  // 100ms delay
```


### 5. GPIO Peripheral - 0x40000000 to 0x40000FFF (4 KB)

#### Register Map

| Offset    | Register Name | Width     | Access | Reset Value  | Description           |
|-----------|---------------|-----------|--------|--------------|-----------------------|
| `0x00`    | DATA          | 8-bit     | R/W    | 0x00         | Pin Data Register     |
| `0x04`    | DUR           | 8-bit     | R/W    | 0x00         | Direction Register    |
| `0x08`    | SET           | 8-bit     | Write  | N/A          | Set Register          |
| `0x0C`    | CLEAR         | 8-bit     | Write  | N/A          | Clearn Register       |
| `0x10`    | TOGGLE        | 8-bit     | Write  | N/A          | Toggel Register       |


#### Register Details


**DATA Register**
```text
Bits 31:8: Reserved (read as 0)
Bits 7:0: PIN_DATA[7:0] - Pin values
For output pins: shows output value
For input pins: shows synchronized input value
```

**DIR Register**
```text
Bits 31:8: Reserved (read as 0)
Bits 7:0: PIN_DIR[7:0] - Pin direction
0 = Input, 1 = Output
```

**SET Register (Write-only)**
```text
Bits 31:8: Reserved (ignored)
Bits 7:0: PIN_SET[7:0] - Set pins
Writing 1 sets corresponding output pin HIGH
Writing 0 has no effect
```

**CLEAR Register (Write-only)**
```text
Bits 31:8: Reserved (ignored)
Bits 7:0: PIN_CLEAR[7:0] - Clear pins
Writing 1 clears corresponding output pin LOW
Writing 0 has no effect
```

**TOGGLE Register (Write-only)**
```text
Bits 31:8: Reserved (ignored)
Bits 7:0: PIN_TOGGLE[7:0] - Toggle pins
Writing 1 toggles corresponding output pin
Writing 0 has no effect
```


#### Pin Mapping

| Pin Number    | Bit Position  | Default Function      |
|---------------|---------------|-----------------------|
| GPIO_PIN_0    | 0             | General purpose I/O   |
| GPIO_PIN_1    | 1             | General purpose I/O   |
| GPIO_PIN_2    | 2             | General purpose I/O   |
| GPIO_PIN_3    | 3             | General purpose I/O   |
| GPIO_PIN_4    | 4             | General purpose I/O   |
| GPIO_PIN_5    | 5             | General purpose I/O   |
| GPIO_PIN_6    | 6             | General purpose I/O   |
| GPIO_PIN_7    | 7             | General purpose I/O   |


#### Usage Example
```c
// Configure pin 0 as output, set HIGH
WRITE_REG(GPIO_BASE_ADDRESS + 0x04, 0x01);  // DIR: pin0 = output
WRITE_REG(GPIO_BASE_ADDRESS + 0x08, 0x01);  // SET: pin0 = HIGH

// Read all pins
uint8_t pin_values = READ_REG(GPIO_BASE_ADDRESS + 0x00) & 0xFF;

// Toggle pin 1
WRITE_REG(GPIO_BASE_ADDRESS + 0x10, 0x02);  // TOGGLE: pin1

// Using driver API
gpio_t gpio_dev;
gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
gpio_write_pin(&gpio_dev, GPIO_PIN_0, true);  // Set pin 0 HIGH
bool value;
gpio_read_pin(&gpio_dev, GPIO_PIN_1, &value); // Read pin 1
```


## Hardware Error Responses
### Wishbone Bus Error Handling

When accessing unmapped or invalid addresses, the Wishbone interconnect returns predefined error patterns:

#### Error Conditions
1. **Invalid Address**: Access outside defined memory regions
2. **Invalid Slave**: Non-existent slave ID selected
3. **Alignment Fault**: Unaligned access (not applicable in this simple implementation)


#### Error Response Patterns
```c
// Defined in errors.h
#define HARDWARE_ERROR_INVALID_ADDR     0xDEADBEEF
#define HARDWARE_ERROR_INVALID_SLAVE    0xBADADD01

// Error detection macro
#define IS_HARDWARE_ERROR(value) \
    ((value) == HARDWARE_ERROR_INVALID_ADDR || \
     (value) == HARDWARE_ERROR_INVALID_SLAVE)
```


#### Error Handling in Software
```c
// Example of hardware error detection
uint32_t read_result = READ_REG(0x50000000);  // Invalid address

if (IS_HARDWARE_ERROR(read_result)) {
    if (read_result == HARDWARE_ERROR_INVALID_ADDR) {
        // Handle invalid address access
        return SYSTEM_ERROR_INVALID_ADDRESS;
    } else if (read_result == HARDWARE_ERROR_INVALID_SLAVE) {
        // Handle invalid slave selection
        return SYSTEM_ERROR_INVALID_SLAVE;
    }
}
```

## Address Validation Macros
### Validation Macros in `system.h`
```c
// Check if address is in specific region
#define IS_IMEM_ADDRESS(addr) \
    (((uint32_t)(addr) >= IMEM_BASE_ADDRESS) && \
     ((uint32_t)(addr) <= IMEM_END_ADDRESS))

#define IS_DMEM_ADDRESS(addr) \
    (((uint32_t)(addr) >= DMEM_BASE_ADDRESS) && \
     ((uint32_t)(addr) <= DMEM_END_ADDRESS))

#define IS_UART_ADDRESS(addr) \
    (((uint32_t)(addr) >= UART_BASE_ADDRESS) && \
     ((uint32_t)(addr) <= UART_END_ADDRESS))

#define IS_TIMER_ADDRESS(addr) \
    (((uint32_t)(addr) >= TIMER_BASE_ADDRESS) && \
     ((uint32_t)(addr) <= TIMER_END_ADDRESS))

#define IS_GPIO_ADDRESS(addr) \
    (((uint32_t)(addr) >= GPIO_BASE_ADDRESS) && \
     ((uint32_t)(addr) <= GPIO_END_ADDRESS))

// Check if address is any peripheral
#define IS_PERIPHERAL_ADDRESS(addr) \
    (IS_UART_ADDRESS(addr) || \
     IS_TIMER_ADDRESS(addr) || \
     IS_GPIO_ADDRESS(addr))
```


### Usage in Safe Access Functions
```c
system_error_t system_read_word_safe(uint32_t addr, uint32_t *value) {
    // Validate address range
    system_error_t err = system_validate_address_range(addr, 4, false);
    if (IS_ERROR(err)) {
        return err;
    }
    
    // Perform read
    *value = READ_REG(addr);
    
    // Check for hardware errors
    if (IS_HARDWARE_ERROR(*value)) {
        return HARDWARE_ERROR_TO_SYSTEM_ERROR(*value);
    }
    
    return SYSTEM_SUCCESS;
}
```


## Memory Access Alignment
### Alignment Requirements
| Access Size           | Require Alignment | Example Valid Address | Example Invalid Address |
|-----------------------|-------------------|-----------------------|-----------------------|
| Byte (8-bit)          | 1 byte            | 0x10000001            | N/A (all addresses byte-aligned)            |
| Half-word (16-bit)    | 2 bytes           | 0x10000002            | 0x10000001            |
| Word (322-bit)        | 4 bytes           | 0x10000004            | 0x10000002            |


### Alignment Checking
```c
// Check if pointer is properly aligned
bool system_is_aligned(const void *ptr, size_t alignment) {
    if (alignment == 0 || (alignment & (alignment - 1)) != 0) {
        return false; // Invalid alignment (not power of two)
    }
    return ((uintptr_t)ptr & (alignment - 1)) == 0;
}

// Align address up/down
#define ALIGN_UP(value, alignment) \
    (((value) + (alignment) - 1) & ~((alignment) - 1))

#define ALIGN_DOWN(value, alignment) \
    ((value) & ~((alignment) - 1))
```


## Practical Examples
### Example 1: Peripheral Discovery
```c
// Test if an address is a valid peripheral
bool is_valid_peripheral(uint32_t addr) {
    if (IS_UART_ADDRESS(addr)) {
        printf("Address 0x%08X is in UART region\n", addr);
        return true;
    }
    if (IS_TIMER_ADDRESS(addr)) {
        printf("Address 0x%08X is in TIMER region\n", addr);
        return true;
    }
    if (IS_GPIO_ADDRESS(addr)) {
        printf("Address 0x%08X is in GPIO region\n", addr);
        return true;
    }
    printf("Address 0x%08X is not a peripheral\n", addr);
    return false;
}
```


### Example 2: Safe Memory Copy with Validation
```c
system_error_t safe_copy(void *dest, const void *src, size_t n) {
    // Validate destination (write access)
    system_error_t err = system_validate_address_range(
        (uint32_t)dest, n, true);
    if (IS_ERROR(err)) return err;
    
    // Validate source (read access)
    err = system_validate_address_range((uint32_t)src, n, false);
    if (IS_ERROR(err)) return err;
    
    // Perform copy
    system_memcpy(dest, src, n);
    
    return SYSTEM_SUCCESS;
}
```


### Example 3: Peripheral Register Dump
```c
void dump_peripheral_registers(uint32_t base_addr, const char *name) {
    printf("\n%s Registers (base: 0x%08X):\n", name, base_addr);
    
    for (int i = 0; i < 0x20; i += 4) {  // First 32 bytes
        uint32_t addr = base_addr + i;
        if (IS_PERIPHERAL_ADDRESS(addr)) {
            uint32_t value = READ_REG(addr);
            printf("  0x%08X: 0x%08X", addr, value);
            
            if (IS_HARDWARE_ERROR(value)) {
                printf(" [HARDWARE ERROR]");
            }
            printf("\n");
        }
    }
}

// Usage
dump_peripheral_registers(UART_BASE_ADDRESS, "UART");
dump_peripheral_registers(TIMER_BASE_ADDRESS, "TIMER");
```


## Memory Map Constants Reference

### Base Address Definitions (`system.h`)
```c
// Memory Bases
#define IMEM_BASE_ADDRESS           0x00000000U
#define DMEM_BASE_ADDRESS           0x10000000U

// Peripheral Bases
#define UART_BASE_ADDRESS           0x20000000U
#define TIMER_BASE_ADDRESS          0x30000000U
#define GPIO_BASE_ADDRESS           0x40000000U

// Memory Sizes
#define IMEM_SIZE                   0x00008000U  // 32KB
#define DMEM_SIZE                   0x00004000U  // 16KB
#define PERIPH_SIZE                 0x00001000U  // 4KB per peripheral

// End Addresses (for boundary checking)
#define IMEM_END_ADDRESS            (IMEM_BASE_ADDRESS + IMEM_SIZE - 1)
#define DMEM_END_ADDRESS            (DMEM_BASE_ADDRESS + DMEM_SIZE - 1)
#define UART_END_ADDRESS            (UART_BASE_ADDRESS + PERIPH_SIZE - 1)
#define TIMER_END_ADDRESS           (TIMER_BASE_ADDRESS + PERIPH_SIZE - 1)
#define GPIO_END_ADDRESS            (GPIO_BASE_ADDRESS + PERIPH_SIZE - 1)
```

## Frequently Asked Questions

**Q1: Why are there large gaps between memory regions?**

**A**: The 4KB allocation per peripheral allows for future expansion. The Wishbone interconnect decodes the high-order address bits to select slaves, making the actual gap size irrelevant for functionality but providing address space for additional features.


**Q2: Can I access peripheral registers using byte or half-word accesses?**

**A**:Yes, but it's recommended to use word (32-bit) accesses for efficiency. The hardware supports byte and half-word accesses, but they may be less efficient on the 32-bit Wishbone bus.


**Q3: What happens if I write to IMEM?**

**A**:Writes to IMEM are ignored by the memory controller. The Wishbone transaction will complete (ACK asserted), but the data will not be stored. Always treat IMEM as read-only.


**Q4: How do I add a new peripheral to the memory map?**

**A**:
1. Choose an unused base address (e.g., 0x50000000)
2. Update the Wishbone interconnect to decode the new address
3. Add base address definition to system.h
4. Create validation macros for the new peripheral
5. Implement the peripheral driver


**Q5: What's the maximum addressable memory?**

**A**:The RV32I CPU has a 32-bit address space (4GB), but only specific regions are implemented. Unimplemented regions return hardware error patterns on read and ignore writes.


