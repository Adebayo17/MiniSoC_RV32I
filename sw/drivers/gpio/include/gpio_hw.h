/*
 * @file  gpio_hw.h
 * @brief GPIO Hardware Abstraction - Documents hardware-specific behavior
 * @brief Hardware definition for GPIO module
 * @details Conforms to the Barr Group Embedded C Coding Standard.
 */

#ifndef GPIO_HW_H
#define GPIO_HW_H

#include <stdint.h>

/**
 * @brief GPIO Hardware Description
 * 
 * This GPIO module has the following characteristics:
 * 
 * 1. **Register Map**:
 *    - 0x00: DATA register (R/W)
 *      * When read: Shows output value for output pins, input value for input pins
 *      * When written: Sets output value for output pins (ignored for input pins)
 *    - 0x04: DIR register (R/W)
 *      * 1 = Output, 0 = Input
 *    - 0x08: SET register (W only)
 *      * Writing 1 to a bit sets corresponding output pin HIGH
 *      * Writing 0 has no effect
 *    - 0x0C: CLEAR register (W only)
 *      * Writing 1 to a bit clears corresponding output pin LOW
 *      * Writing 0 has no effect
 *    - 0x10: TOGGLE register (W only)
 *      * Writing 1 to a bit toggles corresponding output pin
 *      * Writing 0 has no effect
 * 
 * 2. **Hardware Features**:
 *    - 8 GPIO pins (0-7)
 *    - Each pin can be independently configured as input or output
 *    - Inputs have 2-stage synchronizers for metastability protection
 *    - Outputs have direct register control
 *    - SET/CLEAR/TOGGLE registers provide atomic operations
 * 
 * 3. **Hardware Limitations**:
 *    - No pull-up/pull-down resistor configuration
 *    - No drive strength configuration
 *    - No interrupt support
 *    - No debouncing hardware
 *    - No open-drain configuration
 * 
 * 4. **Reset State**:
 *    - All pins configured as inputs (DIR = 0x00)
 *    - All output values LOW (DATA = 0x00)
 *    - Input pins show actual external pin state
 * 
 * 5. **Synchronization**:
 *    - Inputs are synchronized to system clock with 2 flip-flops
 *    - This adds 2 clock cycles of latency on input reads
 *    - Output changes occur on next clock edge after write
 * 
 * 6. **Register Behavior**:
 *    - DATA register: Mixed read behavior (output values for outputs, input values for inputs)
 *    - DIR register: Controls pin direction
 *    - SET/CLEAR/TOGGLE: Atomic operations that don't require read-modify-write
 * 
 * Example usage in hardware:
 * 
 * // Configure pin 0 as output, set HIGH
 * WRITE_REG(GPIO_BASE + 0x04, 0x01); // DIR = output for pin 0
 * WRITE_REG(GPIO_BASE + 0x08, 0x01); // SET pin 0
 * 
 * // Configure pin 1 as input, read value
 * WRITE_REG(GPIO_BASE + 0x04, 0x00); // DIR = input for pin 1
 * value = READ_REG(GPIO_BASE + 0x00); // Read DATA register
 * 
 * // Toggle pin 0
 * WRITE_REG(GPIO_BASE + 0x10, 0x01); // TOGGLE pin 0
 */


/* ========================================================================== */
/* GPIO Register Map Structure                                                */
/* ========================================================================== */

/**
 * @struct gpio_regs_t
 * @brief  Structure for GPIO register map.
 * @note   SET, CLEAR and TOGGLE registers offer atomic operations
 *         managed directly by the hardware.
 */
typedef struct
{
    volatile uint32_t DATA;         /*!< 0x00: Data Register (Read: In/Out state, Write: Out state) */
    volatile uint32_t DIR;          /*!< 0x04: Direction Register (1=Output, 0=Input) */
    volatile uint32_t SET;          /*!< 0x08: Set Output Bits (Write-only, 1=Set bit to 1) */
    volatile uint32_t CLEAR;        /*!< 0x0C: Clear Output Bits (Write-only, 1=Clear bit to 0) */
    volatile uint32_t TOGGLE;       /*!< 0x10: Toggle Output Bits (Write-only, 1=Invert bit) */
} gpio_regs_t;

/* ========================================================================== */
/* GPIO Pin Masks                                                             */
/* ========================================================================== */

#define GPIO_PIN_MASK_0             (1UL << 0)
#define GPIO_PIN_MASK_1             (1UL << 1)
#define GPIO_PIN_MASK_2             (1UL << 2)
#define GPIO_PIN_MASK_3             (1UL << 3)
#define GPIO_PIN_MASK_4             (1UL << 4)
#define GPIO_PIN_MASK_5             (1UL << 5)
#define GPIO_PIN_MASK_6             (1UL << 6)
#define GPIO_PIN_MASK_7             (1UL << 7)
#define GPIO_ALL_PINS_MASK          (0xFFUL)

/* Maximum number of GPIO pins (Hardware limit parameter N_GPIO = 8) */
#define GPIO_MAX_PINS               (8U)

#endif /* GPIO_HW_H */