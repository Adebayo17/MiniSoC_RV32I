/*
 * @file gpio_hw.h
 * @brief GPIO Hardware Abstraction - Documents hardware-specific behavior
 */

#ifndef GPIO_HW_H
#define GPIO_HW_H

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

#endif /* GPIO_HW_H */