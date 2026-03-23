# Memory Map

## Introduction
This document defines the complete memory map of the Mini RV32I SoC. Understanding this memory organization is crucial for bare-metal programming, as all hardware access occurs through memory-mapped I/O (MMIO).

The architecture enforces strict separation between instruction memory (IMEM), data memory (DMEM), and peripheral registers. All addresses and offsets are defined in `sw/include/system.h` and the respective hardware headers (`*_hw.h`).

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
- Stores executable code (`.text` section).
- Contains read-only data (`.rodata` section).
- Initial values for `.data` section (copied to DMEM during boot).

#### Characteristics
- **Read-only**: Software cannot write to this region. Write attempts are intercepted by `system_validate_address()` and raise a `SYSTEM_ERROR_MEMORY_ACCESS`.
- **Word-aligned access**: 32-bit reads are optimal.
- **Initialized at reset**: Loaded directly with firmware binary.

#### Linker Script Organization
```ld
MEMORY {
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS {
    .text : {
        *(.init)             /* Startup code */
        *(.text .text.*)     /* Program code */
        *(.rodata .rodata.*) /* Constants */
        _etext = .;          /* End marker */
    } > IMEM
}
```

### 2. Data Memory (DMEM) - 0x10000000 to 0x10003FFF (16 KB)

#### Purpose
- Stores global and static variables.
- Provides heap for dynamic allocation.
- Contains the functin call stack.


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


#### Memory Usage Validation (`system.h`)
Compile-time checks guarantee the memory layout never overflows the physical bounds:

```c
#define TOTAL_DMEM_USED (DATA_SECTION_SIZE + HEAP_SIZE + STACK_SIZE)

#if (TOTAL_DMEM_USED > DMEM_SIZE)
    #error "DMEM layout exceeds available memory!"
#endif
```


### Peripheral Memory Regions
*Note: All peripheral registers are declared as `volatile uint32_t` in software to enforce 32-bit Wishbone accesses.*

### 3. UART Peripheral - `0x20000000` to `0x20000FFF` (4 KB)

**Register Map**

| Offset    | Register Name | Width     | Access | Reset Value  | Description                           |
|-----------|---------------|-----------|--------|--------------|---------------------------------------|
| `0x00`    | TX_DATA       | 8-bit     | Write  | Undefined    | Transmit Data Register                |
| `0x04`    | RX_DATA       | 8-bit     | Read   | Undefined    | Receive Data Register                 |
| `0x08`    | BAUD_DIV      | 16-bit    | R/W    | 0x00000000   | Baud Rate Divisor                     |
| `0x0C`    | CTRL          | 8-bit     | R/W    | 0x00000000   | Control Register                      |
| `0x10`    | STATUS        | 8-bit     | Read   | 0x00000001   | Status Register (Read-To-Clear)       |


**Usage Example** 
```c
/* Direct MMIO via register_access.h */
write_reg32(UART_BASE_ADDRESS + 0x00, 'A');  // Transmit 'A'

/* Using driver API (Recommended and Safe) */
uart_t uart_dev;
system_error_t status = uart_init(&uart_dev, UART_BASE_ADDRESS);
if (is_success(status)) {
    uart_transmit_byte(&uart_dev, 'A', 1000U);  // 1ms timeout
}
```

### 4. Timer Peripheral - `0x30000000` to `0x30000FFF` (4 KB)

**Register Map**

| Offset    | Register Name | Width   | Access | Reset Value   | Description            |
|-----------|---------------|---------|--------|---------------|------------------------|
| `0x00`    | COUNT         | 32-bit  | Read   | 0x00000000    | Current Timer Count    |
| `0x04`    | CMP           | 32-bit  | R/W    | 0xFFFFFFFF    | Compare Value          |
| `0x08`    | CTRL          | 32-bit  | R/W    | 0x00000000    | Control Register       |
| `0x0C`    | STATUS        | 32-bit  | R/W    | 0x00000000    | Status Register (W1C)  |


**Timing Calculation**
```text
Match time = (CMP value * prescaler) / system_clock
For a 1ms timeout @ 100MHz with /1 prescaler:
CMP = (0.001 * 100,000,000) / 1 = 100,000
```


### 5. GPIO Peripheral - `0x40000000` to `0x40000FFF` (4 KB)

**Register Map**

| Offset    | Register Name | Width     | Access | Reset Value  | Description                   |
|-----------|---------------|-----------|--------|--------------|-------------------------------|
| `0x00`    | DATA          | 8-bit     | R/W    | 0x00         | Pin Data Register             |
| `0x04`    | DUR           | 8-bit     | R/W    | 0x00         | Direction Register (1=Out)    |
| `0x08`    | SET           | 8-bit     | Write  | N/A          | Set Register (1=High)         |
| `0x0C`    | CLEAR         | 8-bit     | Write  | N/A          | Clearn Register (1=Low)       |
| `0x10`    | TOGGLE        | 8-bit     | Write  | N/A          | Toggel Register (1=Inv)       |


**Pin Mapping**

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

---

## Hardware Error Responses & Safety
When accessing unmapped or invalid addresses, the Wishbone interconnect generates specific error patterns rather than crashing silently.

### Error Detection (`errors.h`)

```c
#define HARDWARE_ERROR_INVALID_ADDR     (0xDEADBEEFUL)
#define HARDWARE_ERROR_INVALID_SLAVE    (0xBADADD01UL)

static inline bool is_hardware_error(uint32_t value) {
    return ((value == HARDWARE_ERROR_INVALID_ADDR) || 
            (value == HARDWARE_ERROR_INVALID_SLAVE));
}
```


### Error Handling via HAL
You should never read memory addresses blindly. By using `system_read_word_safe()`, hardware exceptions are caught and safely translated into the `system_error_t` enum:

```c
uint32_t value;
system_error_t status;

/* Attempt to read an invalid address (0x50000000) */
status = system_read_word_safe(0x50000000UL, &value);

if (status == SYSTEM_ERROR_INVALID_ADDRESS) {
    // Gracefully handle the hardware access fault
}
```

## Memory Validation APIs
To prevent hardware errors, the system verifies address validity in software (`system.h`). Instead of uppercase macros, these are implemented as type-safe inline functions:

```c
static inline bool is_imem_address(uint32_t addr) {
    return ((addr >= IMEM_BASE_ADDRESS) && (addr <= IMEM_END_ADDRESS));
}

static inline bool is_dmem_address(uint32_t addr) {
    return ((addr >= DMEM_BASE_ADDRESS) && (addr <= DMEM_END_ADDRESS));
}

static inline bool is_peripheral_address(uint32_t addr) {
    return (is_uart_address(addr) || is_timer_address(addr) || is_gpio_address(addr));
}
```


## Practical Examples
### Example 1: Safe Memory Copy with Validation
```c
system_error_t copy_firmware_data(void) {
    system_error_t status = SYSTEM_SUCCESS;
    void *result_ptr = NULL;
    
    // system_memcpy_safe automatically validates that the source is readable
    // and the destination is writable before performing the operation.
    status = system_memcpy_safe((void*)DMEM_BASE_ADDRESS, 
                                (const void*)IMEM_BASE_ADDRESS, 
                                128U, 
                                &result_ptr);
    
    return status;
}
```

### Example 2: Peripheral Register Dump (Diagnostic)
```c
void dump_peripheral_registers(uint32_t base_addr) {
    if (is_peripheral_address(base_addr)) {
        for (uint32_t offset = 0U; offset < 0x14U; offset += 4U) {
            uint32_t value = read_reg32(base_addr + offset);
            // Print value over UART...
        }
    }
}
```


## Frequently Asked Questions

**Q1: Why are there large gaps (hundreds of MBs) between memory regions?**
**A**: The 4KB allocation per peripheral is standard. The Wishbone interconnect decodes the highest-order address bits to select slaves quickly. The gaps simplify the address decoder logic in Verilog and leave virtually infinite room for future expansion.


**Q2: Can I access peripheral registers using 8-bit (`system_read_byte`) accesses?**
**A**:**No. It is strictly forbidden by the design.** To ensure the Wishbone bus properly triggers the peripheral's selection logic (`wbs_sel`), all peripherals must be accessed using 32-bit read/writes (`read_reg32`, `write_reg32`). Accessing a single byte might result in the peripheral ignoring the command.


**Q3: What happens if I write to IMEM?**
**A**: In software, `system_validate_address(addr, true)` explicitly prevents writes to IMEM and will return `SYSTEM_ERROR_MEMORY_ACCESS`. If you bypass the HAL and write directly via MMIO, the memory controller in Verilog will simply ignore the write command.


**Q4: How do I add a new peripheral to the memory map?**
**A**:
1. Choose an unused base address (e.g., `0x50000000UL`).
2. Update the Wishbone interconnect to decode the new address.
3. Add base address definition (`#define SPI_BASE_ADDRESS`) to `system.h`.
4. Create the `is_spi_address()` validation inline function.
5. Implement the peripheral driver (`spi_hw.h` and `spi.c`).

