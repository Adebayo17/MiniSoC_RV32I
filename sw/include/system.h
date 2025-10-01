/*
 * @file system.h
 * @brief System-wide definitions for Mini RV32I SoC
 * 
 * This file contains memory-map, register access macros, and system constants
 * that are shared all accross drivers and applications
*/

#ifndef SYSTEM_H
#define SYSTEM_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct timer_system timer_t;

/* ========================================================================== */
/* Memory Map Definitions                                                     */
/* ========================================================================== */

/*
 * Memory Map:
 * 
 * | Name    | Base Address   | Size   | Access | Description               |
 * |---------|---------------|--------|--------|----------------------------|
 * | IMEM    | 0x0000_0000   | 8 KB   | R      | Instruction memory         |
 * | DMEM    | 0x1000_0000   | 4 KB   | R/W    | Data Memory                |
 * | UART    | 0x2000_0000   | 4 KB   | R/W    | UART base register address |
 * | TIMER   | 0x3000_0000   | 4 KB   | R/W    | TIMER base register address|
 * | GPIO    | 0x4000_0000   | 4 KB   | R/W    | GPIO base register address |
 * 
 */


/* Memory Bases Address */
#define IMEM_BASE_ADDRESS           0x00000000U
#define DMEM_BASE_ADDRESS           0x10000000U


/* Individual Peripheral Base Address */
#define UART_BASE_ADDRESS           0x20000000U
#define TIMER_BASE_ADDRESS          0x30000000U
#define GPIO_BASE_ADDRESS           0x40000000U


/* Memory Sizes */
#define IMEM_SIZE                   0x00002000U /* 8KB Instruction Memory */
#define DMEM_SIZE                   0x00001000U /* 4KB Data Memory */
#define PERIPH_SIZE                 0x00001000U /* 4KB Per Peripheral */

/* Memory End Address (for boundary checking) */
#define IMEM_END_ADDRESS            (IMEM_BASE_ADDRESS  + IMEM_SIZE   - 1)
#define DMEM_END_ADDRESS            (DMEM_BASE_ADDRESS  + DMEM_SIZE   - 1)
#define UART_END_ADDRESS            (UART_BASE_ADDRESS  + PERIPH_SIZE - 1)
#define TIMER_END_ADDRESS           (TIMER_BASE_ADDRESS + PERIPH_SIZE - 1)
#define GPIO_END_ADDRESS            (GPIO_BASE_ADDRESS  + PERIPH_SIZE - 1)


/* ========================================================================== */
/* DMEM Layout (4KB Total)                                                    */
/* ========================================================================== */

/* 
 * DMEM Layout (0x10000000 - 0x10000FFF):
 * 
 * | Range          | Size  | Purpose                          | Range                          |
 * |---------------|-------|-----------------------------------|--------------------------------|
 * | 0x10000000    | 2KB   | Data (global variables, etc.)     | [0x1000_0000 - 0x1000_07FF]    |
 * | 0x10000800    | 1KB   | Heap (dynamic memory)             | [0x1000_0800 - 0x1000_0BFF]    |
 * | 0x10000C00    | 1KB   | Stack (grows downward)            | [0x1000_0C00 - 0x1000_0FFF]    |
 */

/* Data Section (static/global variables) */
#define DATA_SECTION_BASE           DMEM_BASE_ADDRESS
#define DATA_SECTION_SIZE           0x00000800U  /* 2KB */

/* Heap Configuration */
#define HEAP_BASE_ADDRESS           (DMEM_BASE_ADDRESS + 0x0800U)   /* After 2KB data */
#define HEAP_SIZE                   0x00000400U                     /* 1KB Heap */

/* Stack Configuration (grows downward from top of DMEM) */
#define STACK_BASE_ADDRESS          (DMEM_END_ADDRESS)              /* Top of DMEM */
#define STACK_SIZE                  0x00000400U                     /* 1KB Stack */
#define STACK_END_ADDRESS           (STACK_BASE_ADDRESS - STACK_SIZE + 1)


/* Verify we don't exceed DMEM */
#define TOTAL_DMEM_USED             (DATA_SECTION_SIZE + HEAP_SIZE + STACK_SIZE)
#if TOTAL_DMEM_USED > DMEM_SIZE
    #error "DMEM layout exceeds available memory!"
#endif

/* Verify no overlap */
#if HEAP_BASE_ADDRESS < (DATA_SECTION_BASE + DATA_SECTION_SIZE)
    #error "Heap overlaps with data section!"
#endif

#if STACK_END_ADDRESS < (HEAP_BASE_ADDRESS + HEAP_SIZE)
    #error "Stack overlaps with heap!"
#endif


/* Linker-provided symbols (extern references) */
extern uint32_t _heap_start;
extern uint32_t _heap_end;
extern uint32_t _estack;

/* ========================================================================== */
/* Register Access Macros                                                     */
/* ========================================================================== */


/**
 * @brief Read from memory-map register
 * @param addr Memory addr to read from
 * @return 32-bit value read from the address
 */
#define READ_REG(addr)              (*(volatile uint32_t *)(addr))


/**
 * @brief Write to a memory-mapped register
 * @param addr Memory address to read to
 * @param value 32-bit value to write
 */
#define WRITE_REG(addr, value)      (*(volatile uint32_t *)(addr) = (value))


/**
 * @brief Set bits in a register (read-modify-write)
 * @param addr Register address
 * @param mask Bitmask of bits to set
 */
#define SET_BITS(addr, mask)        do { \
    uint32_t reg = READ_REG(addr); \
    reg |= (mask); \
    WRITE_REG(addr, reg); \
} while (0)


/**
 * @brief Clear bits in a register (read-modify-write)
 * @param addr Register address
 * @param mask Bitmask of bits to clear
 */
#define CLEAR_BITS(addr, mask)      do { \
    uint32_t reg = READ_REG(addr); \
    reg &= ~(mask); \
    WRITE_REG(addr, reg); \
} while (0)


/**
 * @brief Modify specific bits in a register (read-modify-write)
 * @param addr Register address
 * @param mask Bitmask of bits to modify
 * @param value New value for the bits (shifted to correct position)
 */
#define MODIFY_BITS(addr, mask, value) do { \
    uint32_t reg = READ_REG(addr); \
    reg &= ~(mask); \
    reg |= ((value) & (mask)); \
    WRITE_REG(addr, reg); \
} while (0)


/* ========================================================================== */
/* Bit Manipulation Macros                                                    */
/* ========================================================================== */


/**
 * @brief Create a bitmask with specified width at given position
 * @param width Number of bits in the mask
 * @param pos Starting bit position (0-based)
 * @return Bitmask value
 */
#define BITMASK(width, pos)         (((1u << (width)) - 1u) << (pos))


/**
 * @brief Extract a field from a register value
 * @param reg Register value
 * @param mask Bitmask for the field
 * @param pos Starting bit position of the field
 * @return Extracted field value
 */
#define GET_FIELD(reg, mask, pos)   (((reg) & (mask)) >> (pos))


/**
 * @brief Set a field in a register value
 * @param reg Register value
 * @param mask Bitmask for the field
 * @param pos Starting bit position of the field
 * @param value Value to set
 * @return Modified register value with field set
 */
#define SET_FIELD(reg, mask, pos, value) \
    (((reg) & ~(mask)) | (((value) << (pos)) & (mask)))


/* ========================================================================== */
/* Address Validation Macros                                                  */
/* ========================================================================== */


/**
 * @brief Check if address is in IMEM range
 * @param addr Address to check
 * @return true if address is in IMEM space
 */
#define IS_IMEM_ADDRESS(addr)       (((uint32_t)(addr) >= (uint32_t)IMEM_BASE_ADDRESS) && \
                                    ((uint32_t)(addr) <= (uint32_t)IMEM_END_ADDRESS))

/**
 * @brief Check if address is in DMEM range
 * @param addr Address to check
 * @return true if address is in DMEM space
 */
#define IS_DMEM_ADDRESS(addr)       (((uint32_t)(addr) >= DMEM_BASE_ADDRESS) && \
                                    ((uint32_t)(addr) <= DMEM_END_ADDRESS))

/**
 * @brief Check if address is in UART range
 * @param addr Address to check
 * @return true if address is in UART space
 */
#define IS_UART_ADDRESS(addr)       (((uint32_t)(addr) >= UART_BASE_ADDRESS) && \
                                    ((uint32_t)(addr) <= UART_END_ADDRESS))


/**
 * @brief Check if address is in TIMER range
 * @param addr Address to check
 * @return true if address is in TIMER space
 */
#define IS_TIMER_ADDRESS(addr)      (((uint32_t)(addr) >= TIMER_BASE_ADDRESS) && \
                                    ((uint32_t)(addr) <= TIMER_END_ADDRESS))


/**
 * @brief Check if address is in GPIO range
 * @param addr Address to check
 * @return true if address is in GPIO space
 */
#define IS_GPIO_ADDRESS(addr)       (((uint32_t)(addr) >= GPIO_BASE_ADDRESS) && \
                                    ((uint32_t)(addr) <= GPIO_END_ADDRESS))


/**
 * @brief Check if address is valid peripheral address
 * @param addr Address to check
 * @return true if address is in peripheral space
 */
#define IS_PERIPHERAL_ADDRESS(addr) (IS_UART_ADDRESS(addr) || \
                                    IS_TIMER_ADDRESS(addr) || \
                                    IS_GPIO_ADDRESS(addr))


/* ========================================================================== */
/* System Constants                                                           */
/* ========================================================================== */

/* Clock Frequencies */
#define SYSTEM_CLOCK_FREQ           50000000U       /* 50 MHz System Clock */
#define UART_BAUD_RATE              115200U         /* Default UART Baud Rate */


/* GPIO Constants */
#define GPIO_MAX_PINS               8U              /* Number of GPIO pins */


/* UART Constants (fixed at: 8 data bits, 1 stop bit, no parity) */
#define UART_DATA_BITS_8            8               /* Informational only */
#define UART_STOP_BITS_1            1               /* Informational only */ 
#define UART_PARITY_NONE            0               /* Informational only */


/* ========================================================================== */
/* Base Peripheral Structure                                                  */
/* ========================================================================== */


/**
 * @brief Base peripheral structure
 * All peripheral drivers should include this as their first member
 */
typedef struct {
    uint32_t base_address;
} peripheral_t;


/* ========================================================================== */
/* System Functions                                                           */
/* ========================================================================== */


/**
 * @brief Initialize the entire system
 * @note This should be called before any peripheral operations
 */
void system_init(void);


/**
 * @brief Initialize system with hardware timer support
 * @param system_timer Pointer to timer device for system timing
 */
void system_init_with_timer(timer_t *system_timer);


/**
 * @brief System reset function
 * @note This may trigger a soft reset of the processor
 */
void system_reset(void) __attribute__((noreturn));


/**
 * @brief Validate memory address access
 * @param addr Address to validate
 * @param is_write true for write access, false for read
 * @return SYSTEM_SUCCESS if valid, error code otherwise
 */
int system_validate_address(uint32_t addr, bool is_write);


/**
 * @brief Non-blocking delay in microseconds (uses hardware timer)
 * @param us Number of microseconds to delay
 * @return true if delay started, false if timer busy
 */
bool system_delay_us_start(uint32_t us);


/**
 * @brief Check if non-blocking delay has completed
 * @return true if delay completed, false if still waiting
 */
bool system_delay_us_complete(void);


/**
 * @brief Blocking delay in microseconds (uses hardware timer)
 * @param us Number of microseconds to delay
 */
void system_delay_us(uint32_t us);


/**
 * @brief Blocking delay in milliseconds (uses hardware timer)
 * @param ms Number of milliseconds to delay
 */
void system_delay_ms(uint32_t ms);


/**
 * @brief Get precise system time in microseconds
 * @return Current time in microseconds since system start
 */
uint32_t system_get_time_us(void);


/**
 * @brief Get system ticks from hardware timer
 * @return Current timer count value
 */
uint32_t system_get_ticks(void);


/**
 * @brief Get elapsed time since a previous tick value
 * @param previous_tick Previous tick value from system_get_ticks()
 * @return Elapsed time in microseconds
 */
uint32_t system_get_elapsed_time_us(uint32_t previous_tick);


/* ========================================================================== */
/* Error Codes                                                                */
/* ========================================================================== */

typedef enum {
    SYSTEM_SUCCESS = 0,
    SYSTEM_ERROR_INVALID_PARAM = -1,
    SYSTEM_ERROR_TIMEOUT = -2,
    SYSTEM_ERROR_BUSY = -3,
    SYSTEM_ERROR_NOT_READY = -4,
    SYSTEM_ERROR_HARDWARE = -5,
    SYSTEM_ERROR_MEMORY_ACCESS = -6,
    SYSTEM_ERROR_INVALID_ADDRESS = -7
} system_error_t;

/* ========================================================================== */
/* Assertion Macros                                                           */
/* ========================================================================== */

#ifdef DEBUG
/**
 * @brief Debug assertion macro
 * @param condition Condition to check
 * @param message Error message if assertion fails
 */
#define SYSTEM_ASSERT(condition, message) do { \
    if (!(condition)) { \
        /* Add debug output or breakpoint here */ \
        while(1); /* Trap in debug mode */ \
    } \
} while (0)

/**
 * @brief Assert valid memory access
 * @param addr Address to check
 * @param is_write Type of access
 */
#define ASSERT_VALID_ACCESS(addr, is_write) do { \
    if (system_validate_address((uint32_t)(addr), (is_write)) != SYSTEM_SUCCESS) { \
        while(1); /* Trap on invalid access */ \
    } \
} while (0)

#else
#define SYSTEM_ASSERT(condition, message) ((void)0)
#define ASSERT_VALID_ACCESS(addr, is_write) ((void)0)
#endif


/* ========================================================================== */
/* Peripheral Functions Prototypes                                            */
/* ========================================================================== */

/* Generic peripheral operations */

/**
 * @brief Initialize Peripheral driver
 * @param dev Pointer to Peripheral structure
 * @param base_addr Base address of the peripheral
 */
void peripheral_init(peripheral_t *dev, uint32_t base_addr);


/**
 * @brief Get peripheral base address
 * @param dev Pointer to Peripheral structure
 * @return Base address of the peripheral
 */
uint32_t peripheral_get_base_address(const peripheral_t *dev);


/**
 * @brief Check if the offset is in the peripheral memory space
 * @param dev Pointer to Peripheral structure
 * @param offset Offset to check 
 * @return true if device valid and in peripheral memory space, false otherwise
 */
bool peripheral_validate_address(const peripheral_t *dev, uint32_t offset);


/* ========================================================================== */
/* Memory Access Functions                                                    */
/* ========================================================================== */

/**
 * @brief Read a byte from memory (emulated for word-aligned systems)
 * @param addr Memory address (can be unaligned)
 * @return 8-bit value read from the address
 */
uint8_t system_read_byte(uint32_t addr);


/**
 * @brief Write a byte to memory (emulated for word-aligned systems)
 * @param addr Memory address (can be unaligned)
 * @param value 8-bit value to write
 */
void system_write_byte(uint32_t addr, uint8_t value);


/**
 * @brief Read a half-word (16-bit) from memory
 * @param addr Memory address (should be 2-byte aligned for efficiency)
 * @return 16-bit value read from the address
 */
uint16_t system_read_halfword(uint32_t addr);


/**
 * @brief Write a half-word (16-bit) to memory
 * @param addr Memory address (should be 2-byte aligned for efficiency)
 * @param value 16-bit value to write
 */
void system_write_halfword(uint32_t addr, uint16_t value);


/**
 * @brief Read a word (32-bit) from memory
 * @param addr Memory address (must be 4-byte aligned)
 * @return 32-bit value read from the address
 */
uint32_t system_read_word(uint32_t addr);


/**
 * @brief Write a word (32-bit) to memory
 * @param addr Memory address (must be 4-byte aligned)
 * @param value 32-bit value to write
 */
void system_write_word(uint32_t addr, uint32_t value);


/**
 * @brief Copy memory block (memcpy equivalent)
 * @param dest Destination address
 * @param src Source address
 * @param n Number of bytes to copy
 */
void system_memcpy(void *dest, const void *src, size_t n);


/**
 * @brief Set memory block to value (memset equivalent)
 * @param dest Destination address
 * @param value Value to set
 * @param n Number of bytes to set
 */
void system_memset(void *dest, uint8_t value, size_t n);


/* ========================================================================== */
/* Fast Math Helpers (for common cases)                                       */
/* ========================================================================== */

/**
 * @brief Check if a number is power of two
 * @param x Number to check
 * @return true if x is power of two
 */
static inline bool is_power_of_two(uint32_t x) {
    return (x != 0) && ((x & (x - 1)) == 0);
}


/**
 * @brief Fast division by power of two (using shift)
 * @param value Value to divide
 * @param power_two_divisor Must be power of two (2, 4, 8, 16, ...)
 * @return value / power_two_divisor
 */
static inline uint32_t fast_udiv_pow2(uint32_t value, uint32_t power_two_divisor) {
    // Find the shift amount by counting trailing zeros
    uint32_t shift = 0;
    uint32_t temp = power_two_divisor;
    while (temp > 1) {
        temp >>= 1;
        shift++;
    }
    return value >> shift;
}


/**
 * @brief Fast modulus by power of two (using mask)
 * @param value Value for modulus
 * @param power_two_modulus Must be power of two (2, 4, 8, 16, ...)
 * @return value % power_two_modulus
 */
static inline uint32_t fast_umod_pow2(uint32_t value, uint32_t power_two_modulus) {
    return value & (power_two_modulus - 1);
}


/* ========================================================================== */
/* Software Math Functions (RV32I without M extension)                       */
/* ========================================================================== */

/**
 * @brief 32-bit unsigned multiplication
 * @param a First operand
 * @param b Second operand
 * @return a * b
 */
uint32_t system_umul32(uint32_t a, uint32_t b);


/**
 * @brief 32-bit signed multiplication
 * @param a First operand
 * @param b Second operand
 * @return a * b
 */
int32_t system_mul32(int32_t a, int32_t b);


/**
 * @brief 32-bit unsigned division
 * @param dividend Number to be divided
 * @param divisor Number to divide by
 * @return dividend / divisor
 */
uint32_t system_udiv32(uint32_t dividend, uint32_t divisor);


/**
 * @brief 32-bit signed division
 * @param dividend Number to be divided
 * @param divisor Number to divide by
 * @return dividend / divisor
 */
int32_t system_div32(int32_t dividend, int32_t divisor);


/**
 * @brief 32-bit unsigned modulus
 * @param dividend Number to be divided
 * @param divisor Number to divide by
 * @return dividend % divisor
 */
uint32_t system_umod32(uint32_t dividend, uint32_t divisor);


/**
 * @brief 32-bit signed modulus
 * @param dividend Number to be divided
 * @param divisor Number to divide by
 * @return dividend % divisor
 */
int32_t system_mod32(int32_t dividend, int32_t divisor);


/**
 * @brief Multiply two 32-bit values and return 64-bit result
 * @param a First operand
 * @param b Second operand
 * @return a * b as 64-bit value (lower 32 bits in result[0], upper in result[1])
 */
void system_umul64(uint32_t a, uint32_t b, uint32_t result[2]);




#endif /* SYSTEM_H */