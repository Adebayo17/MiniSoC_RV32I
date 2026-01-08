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

/* Register Access Layer */
#include "register_access.h"


/* Essential headers */
#include "errors.h"        /* Error codes */
#include "memory.h"        /* Memory access */

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


#endif /* SYSTEM_H */