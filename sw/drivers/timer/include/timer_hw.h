/*
 * @file timer_hw.h
 * @brief Timer Hardware Abstraction - Documents hardware-specific behavior
 */

#ifndef TIMER_HW_H
#define TIMER_HW_H

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
 * 
 * Example usage in hardware:
 * 
 * // Configure timer for 1ms timeout @ 50MHz with /1 prescaler
 * // 1ms = 50,000 ticks (50,000,000 Hz / 1000)
 * WRITE_REG(TIMER_BASE + 0x04, 50000); // CMP = 50000
 * WRITE_REG(TIMER_BASE + 0x08, 0x01);  // ENABLE=1, continuous mode
 * 
 * // Wait for match
 * while (!(READ_REG(TIMER_BASE + 0x0C) & 0x01)) {}
 * WRITE_REG(TIMER_BASE + 0x0C, 0x00); // Clear match flag
 * 
 * // One-shot mode example
 * WRITE_REG(TIMER_BASE + 0x04, 1000);  // CMP = 1000
 * WRITE_REG(TIMER_BASE + 0x08, 0x05);  // ENABLE=1, ONESHOT=1
 */

#endif /* TIMER_HW_H */