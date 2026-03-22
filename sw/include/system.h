/**
 * @file    system.h
 * @brief   System-wide definitions for Mini RV32I SoC.
 * @details Conforms to Barr Group Embedded C Coding Standard.
 * Contains memory-map, register access inline functions, and system constants
 * shared across drivers and applications.
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


/* Forward declaration for timer_t */
typedef struct timer_system timer_t;

/* ========================================================================== */
/* Memory Map Definitions                                                     */
/* ========================================================================== */

/*
 * Memory Map:
 * 
 * | Name    | Base Address  | Size  | Access | Description               |
 * |---------|---------------|--------|--------|----------------------------|
 * | IMEM    | 0x0000_0000   | 32 KB  | R      | Instruction memory         |
 * | DMEM    | 0x1000_0000   | 16 KB  | R/W    | Data Memory                |
 * | UART    | 0x2000_0000   | 4 KB   | R/W    | UART base register address |
 * | TIMER   | 0x3000_0000   | 4 KB   | R/W    | TIMER base register address|
 * | GPIO    | 0x4000_0000   | 4 KB   | R/W    | GPIO base register address |
 * 
 */


/* Memory Bases Address */
#define IMEM_BASE_ADDRESS           (0x00000000UL)
#define DMEM_BASE_ADDRESS           (0x10000000UL)


/* Individual Peripheral Base Address */
#define UART_BASE_ADDRESS           (0x20000000UL)
#define TIMER_BASE_ADDRESS          (0x30000000UL)
#define GPIO_BASE_ADDRESS           (0x40000000UL)


/* Memory Sizes */
#define IMEM_SIZE                   (0x00008000UL)  /* 32KB Instruction Memory */
#define DMEM_SIZE                   (0x00004000UL)  /* 16KB Data Memory */
#define PERIPH_SIZE                 (0x00001000UL)  /* 4KB  Per Peripheral */

/* Memory End Address (for boundary checking) */
#define IMEM_END_ADDRESS            (IMEM_BASE_ADDRESS  + IMEM_SIZE   - 1UL)
#define DMEM_END_ADDRESS            (DMEM_BASE_ADDRESS  + DMEM_SIZE   - 1UL)
#define UART_END_ADDRESS            (UART_BASE_ADDRESS  + PERIPH_SIZE - 1UL)
#define TIMER_END_ADDRESS           (TIMER_BASE_ADDRESS + PERIPH_SIZE - 1UL)
#define GPIO_END_ADDRESS            (GPIO_BASE_ADDRESS  + PERIPH_SIZE - 1UL)


/* ========================================================================== */
/* DMEM Layout (16KB Total)                                                    */
/* ========================================================================== */

/* 
 * DMEM Layout (0x1000_0000 - 0x10003_FFF):
 * 
 * | Range         | Size  | Purpose                            | Range                          |
 * |---------------|-------|------------------------------------|--------------------------------|
 * | 0x10000000    | 8KB   | Data (global variables, etc.)      | [0x1000_0000 - 0x1000_1FFF]    |
 * | 0x10002000    | 4KB   | Heap (dynamic memory)              | [0x1000_2000 - 0x1000_2FFF]    |
 * | 0x10003000    | 4KB   | Stack (grows downward)             | [0x1000_3000 - 0x1000_3FFF]    |
 */

/* Data Section (static/global variables) */
#define DATA_SECTION_BASE           (DMEM_BASE_ADDRESS)                         /* Start of data section */
#define DATA_SECTION_SIZE           (0x00002000UL)                              /* 8KB */

/* Heap Configuration */
#define HEAP_BASE_ADDRESS           (DMEM_BASE_ADDRESS + DATA_SECTION_SIZE)     /* After 8KB data */
#define HEAP_SIZE                   (0x00001000UL)                              /* 4KB Heap */

/* Stack Configuration (grows downward from top of DMEM) */
#define STACK_BASE_ADDRESS          (DMEM_END_ADDRESS)                          /* Top of DMEM */
#define STACK_SIZE                  (0x00001000UL)                              /* 4KB Stack */
#define STACK_END_ADDRESS           (STACK_BASE_ADDRESS - STACK_SIZE + 1UL)


/* Compile-time memory layout verification */
/* Verify we don't exceed DMEM */
#define TOTAL_DMEM_USED             (DATA_SECTION_SIZE + HEAP_SIZE + STACK_SIZE)

#if (TOTAL_DMEM_USED > DMEM_SIZE)
    #error "DMEM layout exceeds available memory!"
#endif

/* Verify no overlap */
#if (HEAP_BASE_ADDRESS < (DATA_SECTION_BASE + DATA_SECTION_SIZE))
    #error "Heap overlaps with data section!"
#endif

#if (STACK_END_ADDRESS < (HEAP_BASE_ADDRESS + HEAP_SIZE))
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
 * @brief  Check if address is in IMEM range.
 * @param  [in] addr Address to check.
 * @return true if address is in IMEM space.
 */
static inline bool is_imem_address(uint32_t addr)
{
    return ((addr >= IMEM_BASE_ADDRESS) && (addr <= IMEM_END_ADDRESS));
}


/**
 * @brief  Check if address is in DMEM range.
 * @param  [in] addr Address to check.
 * @return true if address is in DMEM space.
 */
static inline bool is_dmem_address(uint32_t addr)
{
    return ((addr >= DMEM_BASE_ADDRESS) && (addr <= DMEM_END_ADDRESS));
}


/**
 * @brief  Check if address is in UART range.
 * @param  [in] addr Address to check.
 * @return true if address is in UART space.
 */
static inline bool is_uart_address(uint32_t addr)
{
    return ((addr >= UART_BASE_ADDRESS) && (addr <= UART_END_ADDRESS));
}


/**
 * @brief  Check if address is in TIMER range.
 * @param  [in] addr Address to check.
 * @return true if address is in TIMER space.
 */
static inline bool is_timer_address(uint32_t addr)
{
    return ((addr >= TIMER_BASE_ADDRESS) && (addr <= TIMER_END_ADDRESS));
}


/**
 * @brief  Check if address is in GPIO range.
 * @param  [in] addr Address to check.
 * @return true if address is in GPIO space.
 */
static inline bool is_gpio_address(uint32_t addr)
{
    return ((addr >= GPIO_BASE_ADDRESS) && (addr <= GPIO_END_ADDRESS));
}


/**
 * @brief  Check if address is a valid peripheral address.
 * @param  [in] addr Address to check.
 * @return true if address is in peripheral space.
 */
static inline bool is_peripheral_address(uint32_t addr)
{
    return (is_uart_address(addr) || is_timer_address(addr) || is_gpio_address(addr));
}


/* ========================================================================== */
/* System Constants                                                           */
/* ========================================================================== */

/* Clock Frequencies */
#define SYSTEM_CLOCK_FREQ           (100000000UL)      /* 100 MHz System Clock */
#define UART_BAUD_RATE              (115200UL)         /* Default UART Baud Rate */


/* UART Constants (fixed at: 8 data bits, 1 stop bit, no parity) */
#define UART_DATA_BITS_8            (8U)               /* Informational only */
#define UART_STOP_BITS_1            (1U)               /* Informational only */ 
#define UART_PARITY_NONE            (0U)               /* Informational only */


/* ========================================================================== */
/* System Initialization Functions                                            */
/* ========================================================================== */


/**
 * @brief   Initialize the entire system
 * @note    This should be called before any peripheral operations
 */
void system_init(void);


/**
 * @brief   Initialize system with hardware timer support
 * @param   [in] system_timer Pointer to timer device for system timing
 */
void system_init_with_timer(timer_t *system_timer);


/**
 * @brief   System reset function
 * @note    This may trigger a soft reset of the processor
 */
void system_reset(void) __attribute__((noreturn));


/**
 * @brief   Validate memory address access.
 * @param   [in] addr Address to validate.
 * @param   [in] is_write true for write access, false for read.
 * @return  SYSTEM_SUCCESS if valid, error code otherwise.
 */
system_error_t system_validate_address(uint32_t addr, bool is_write);


/**
 * @brief   Initialize system with hardware timer support (safe version).
 * @param   [in] timer Pointer to timer device for system timing.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_init_with_timer_safe(timer_t *timer);


/* ========================================================================== */
/* Time Management Functions                                                  */
/* ========================================================================== */

/**
 * @brief   Get precise system time in microseconds.
 * @return  Current time in microseconds since system start.
 */
uint32_t system_get_time_us(void);


/**
 * @brief   Get precise system time in microseconds (safe version).
 * @param   [in] time_us Pointer to store time in microseconds.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_get_time_us_safe(uint32_t *time_us);


/**
 * @brief   Get system ticks from hardware timer.
 * @return  Current timer count value.
 */
uint32_t system_get_ticks(void);


/**
 * @brief   Get system ticks from hardware timer (safe version).
 * @param   [out] ticks Pointer to store timer count value.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_get_ticks_safe(uint32_t *ticks);

/**
 * @brief   Get elapsed time since a previous tick value.
 * @param   [in] previous_tick Previous tick value from system_get_ticks().
 * @return  Elapsed time in microseconds.
 */
uint32_t system_get_elapsed_time_us(uint32_t previous_tick);


/**
 * @brief   Get elapsed time since a previous tick value (safe version).
 * @param   [in] previous_tick Previous tick value from system_get_ticks().
 * @param   [out] elapsed_us Pointer to store elapsed time in microseconds.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_get_elapsed_time_us_safe(uint32_t previous_tick, uint32_t *elapsed_us);


/* ========================================================================== */
/* Non-blocking Delay Functions                                               */
/* ========================================================================== */

/**
 * @brief   Non-blocking delay start.
 * @param   [in] us Number of microseconds to delay.
 * @return  true if delay started, false if timer busy.
 */
bool system_delay_us_start(uint32_t us);


/**
 * @brief   Non-blocking delay start (safe version).
 * @param   [in] us Number of microseconds to delay.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_delay_us_start_safe(uint32_t us);


/**
 * @brief   Check if non-blocking delay has completed.
 * @return  true if delay completed, false if still waiting.
 */
bool system_delay_us_complete(void);


/**
 * @brief   Check if non-blocking delay has completed (safe version).
 * @param   [out] is_complete Pointer to store completion status.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_delay_us_complete_safe(bool *is_complete);


/* ========================================================================== */
/* Blocking Delay Functions                                                   */
/* ========================================================================== */

/**
 * @brief   Blocking delay in microseconds.
 * @param   [in] us Number of microseconds to delay.
 */
void system_delay_us(uint32_t us);


/**
 * @brief   Blocking delay in microseconds (safe version).
 * @param   [in] us Number of microseconds to delay.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_delay_us_safe(uint32_t us);


/**
 * @brief   Blocking delay in milliseconds.
 * @param   [in] ms Number of milliseconds to delay.
 */
void system_delay_ms(uint32_t ms);


/**
 * @brief   Blocking delay in milliseconds (safe version).
 * @param   [in] ms Number of milliseconds to delay.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_delay_ms_safe(uint32_t ms);


/* ========================================================================== */
/* Assertion Macros                                                           */
/* ========================================================================== */

/* Barr Group: Macro with block must be wrapped in do-while */
#ifdef DEBUG
    /**
     * @brief Debug assertion macro.
     * @param condition Condition to check.
     * @param message   Error message if assertion fails.
     */
    #define SYSTEM_ASSERT(condition, message) \
        do \
        { \
            if (!(condition)) \
            { \
                /* Infinite loop to trap CPU during debug */ \
                while (1) {} \
            } \
        } while (0)

    /**
     * @brief Assert valid memory access.
     * @param addr     Address to check.
     * @param is_write Type of access.
     */
    #define ASSERT_VALID_ACCESS(addr, is_write) \
        do \
        { \
            system_error_t __err = system_validate_address((uint32_t)(addr), (is_write)); \
            if (is_error(__err)) \
            { \
                while (1) {} \
            } \
        } while (0)
#else
    #define SYSTEM_ASSERT(condition, message)     do { } while (0)
    #define ASSERT_VALID_ACCESS(addr, is_write)   do { } while (0)
#endif

/* ========================================================================== */
/* Utility Inline Functions                                                   */
/* ========================================================================== */

/**
 * @brief  Check if pointer is aligned to a specific boundary.
 * @param  [in] ptr Pointer to check.
 * @param  [in] alignment Alignment boundary (must be power of two).
 * @return true if aligned, false otherwise.
 */
static inline bool ptr_is_aligned(const void *ptr, size_t alignment)
{
    return (((uintptr_t)ptr & (alignment - 1U)) == 0U);
}

/**
 * @brief  Align value up to specific boundary.
 * @param  [in] value Value to align.
 * @param  [in] alignment Alignment boundary (must be power of two).
 * @return Aligned value.
 */
static inline uint32_t align_up(uint32_t value, uint32_t alignment)
{
    return ((value + alignment - 1U) & ~(alignment - 1U));
}

/**
 * @brief  Align value down to specific boundary.
 * @param  [in] value Value to align.
 * @param  [in] alignment Alignment boundary (must be power of two).
 * @return Aligned value.
 */
static inline uint32_t align_down(uint32_t value, uint32_t alignment)
{
    return (value & ~(alignment - 1U));
}


#endif /* SYSTEM_H */