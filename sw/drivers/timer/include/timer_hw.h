/**
 * @file    timer_hw.h
 * @brief   Hardware definitions for the TIMER peripheral.
 * @details Conforms to the Barr Group Embedded C Coding Standard.
 * Describes the register structure and hardware bit masks.
 */

#ifndef TIMER_HW_H
#define TIMER_HW_H

#include <stdint.h>

/**
 * @brief Timer Hardware Description
 * 
 * This timer module has the following characteristics:
 * 
 * 1. **Register Map**:
 *    - 0x00: COUNT register (R)
 *      * Current timer count value (32-bit)
 *      * Increments on each clock tick (divided by prescaler)
 *    - 0x04: CMP register (R/W)
 *      * Compare value for match generation
 *      * When COUNT == CMP, match flag is set
 *    - 0x08: CTRL register (R/W)
 *      * Bit 0: ENABLE (1=enabled, 0=disabled)
 *      * Bit 1: RESET (1=reset counter, auto-clears)
 *      * Bit 2: ONESHOT (1=one-shot mode, 0=continuous)
 *      * Bits 3-4: PRESCALE (00=/1, 01=/8, 10=/64, 11=/1024)
 *      * Other bits: Reserved
 *    - 0x0C: STATUS register (R/W)
 *      * Bit 0: MATCH (1=match occurred, write 0 to clear)
 *      * Bit 1: OVERFLOW (1=overflow occurred, write 0 to clear)
 *      * Other bits: Reserved
 * 
 * 2. **Timer Behavior**:
 *    - 32-bit up-counter
 *    - Starts from 0 on reset or when enabled
 *    - In continuous mode: wraps around from 0xFFFFFFFF to 0x00000000
 *    - In one-shot mode: stops when match occurs
 *    - Match flag is set when COUNT == CMP
 *    - Overflow flag is set when COUNT wraps from 0xFFFFFFFF to 0x00000000
 * 
 * 3. **Clock Prescaling**:
 *    - Prescaler divides system clock before counting
 *    - Prescaler settings: /1, /8, /64, /1024
 *    - Prescaler changes take effect immediately
 *    - Prescaler applies to both COUNT and match detection
 * 
 * 4. **Reset Behavior**:
 *    - Setting RESET bit clears COUNT to 0
 *    - RESET is edge-triggered (set then clear)
 *    - RESET does not affect CMP, CTRL, or STATUS registers
 * 
 * 5. **Match Behavior**:
 *    - Match flag is set when COUNT reaches CMP value
 *    - In continuous mode: flag sets each time COUNT == CMP
 *    - In one-shot mode: timer stops after match
 *    - Match flag must be cleared by software
 * 
 * 6. **Overflow Behavior**:
 *    - Overflow flag sets when COUNT wraps from max to 0
 *    - Only relevant in continuous mode
 *    - Overflow flag must be cleared by software
 * 
 * 7. **Timing Considerations**:
 *    - Minimum compare value: 2 (value 1 might miss detection)
 *    - Maximum compare value: 0xFFFFFFFF (32-bit max)
 *    - Compare value of 0 would match immediately
 *    - Prescaler changes affect timing immediately
 */


/* ========================================================================== */
/* TIMER Register Map Structure                                               */
/* ========================================================================== */

/**
 * @struct timer_regs_t
 * @brief  Structure representing the TIMER register map.
 */
typedef struct
{
    /* COUNT is "volatile const" because the processor should/can only read it */
    volatile const uint32_t COUNT;          /*!< 0x00: Counter Value (Read-Only) */
    volatile uint32_t       CMP;            /*!< 0x04: Compare Value */
    volatile uint32_t       CTRL;           /*!< 0x08: Control Register */
    volatile uint32_t       STATUS;         /*!< 0x0C: Status Register (Write-1-to-Clear) */
} timer_regs_t;


/* ========================================================================== */
/* Timer REG_CTRL Bit Definitions                                             */
/* ========================================================================== */

#define TIMER_CTRL_ENABLE_POS       (0U)
#define TIMER_CTRL_ENABLE_BIT       (1UL << TIMER_CTRL_ENABLE_POS)

#define TIMER_CTRL_RESET_POS        (1U)
#define TIMER_CTRL_RESET_BIT        (1UL << TIMER_CTRL_RESET_POS)

#define TIMER_CTRL_ONESHOT_POS      (2U)
#define TIMER_CTRL_ONESHOT_BIT      (1UL << TIMER_CTRL_ONESHOT_POS)

#define TIMER_CTRL_PRESCALE_POS     (3U)
#define TIMER_CTRL_PRESCALE_MASK    (3UL << TIMER_CTRL_PRESCALE_POS) /* Bits 3 and 4 */


/* ========================================================================== */
/* Timer REG_STATUS Bit Definitions                                           */
/* ========================================================================== */

#define TIMER_STATUS_MATCH_POS      (0U)
#define TIMER_STATUS_MATCH_BIT      (1UL << TIMER_STATUS_MATCH_POS)

#define TIMER_STATUS_OVERFLOW_POS   (1U)
#define TIMER_STATUS_OVERFLOW_BIT   (1UL << TIMER_STATUS_OVERFLOW_POS)


/* ========================================================================== */
/* TIMER Hardware Constants                                                   */
/* ========================================================================== */

/* IMPORTANT: Should match the OVERFLOW_VALUE parameter define in the Verilog module */
#define TIMER_MAX_VALUE             (0xFFFFFFFFUL)
#define TIMER_MIN_COMPARE_VALUE     (2UL)


#endif /* TIMER_HW_H */