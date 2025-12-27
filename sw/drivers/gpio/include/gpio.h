/*
 * @file gpio.h
 * @brief GPIO Driver
*/

#ifndef GPIO_H
#define GPIO_H

#include "system.h"        /* Memory map, macros */
#include "peripheral.h"    /* peripheral_t structure */
#include "errors.h"        /* Error codes */


/* ========================================================================== */
/* GPIO Memory Map Definitions                                                */
/* ========================================================================== */


/* Register Address Offsets */
#define REG_GPIO_DATA_OFFSET        0x00u
#define REG_GPIO_DIR_OFFSET         0x04u
#define REG_GPIO_SET_OFFSET         0x08u
#define REG_GPIO_CLEAR_OFFSET       0x0Cu
#define REG_GPIO_TOGGLE_OFFSET      0x10u


/* Register Address Calculation */
#define REG_GPIO_DATA_ADDR          (GPIO_BASE_ADDRESS + REG_GPIO_DATA_OFFSET  )
#define REG_GPIO_DIR_ADDR           (GPIO_BASE_ADDRESS + REG_GPIO_DIR_OFFSET   )
#define REG_GPIO_SET_ADDR           (GPIO_BASE_ADDRESS + REG_GPIO_SET_OFFSET   )
#define REG_GPIO_CLEAR_ADDR         (GPIO_BASE_ADDRESS + REG_GPIO_CLEAR_OFFSET )
#define REG_GPIO_TOGGLE_ADDR        (GPIO_BASE_ADDRESS + REG_GPIO_TOGGLE_OFFSET)


/* ========================================================================== */
/* GPIO REG_GPIO_DATA Bit Definitions                                         */
/* ========================================================================== */

#define GPIO_DATA_POS               0
#define GPIO_DATA_WIDTH             8
#define GPIO_DATA_MASK              BITMASK(GPIO_DATA_WIDTH, GPIO_DATA_POS)


/* ========================================================================== */
/* GPIO REG_GPIO_DIR Bit Definitions                                          */
/* ========================================================================== */

#define GPIO_DIR_POS                0
#define GPIO_DIR_WIDTH              8
#define GPIO_DIR_MASK               BITMASK(GPIO_DIR_WIDTH, GPIO_DIR_POS)


/* ========================================================================== */
/* GPIO REG_GPIO_SET Bit Definitions                                          */
/* ========================================================================== */

#define GPIO_SET_POS                0
#define GPIO_SET_WIDTH              8
#define GPIO_SET_MASK               BITMASK(GPIO_SET_WIDTH, GPIO_SET_POS)


/* ========================================================================== */
/* GPIO REG_GPIO_CLEAR Bit Definitions                                        */
/* ========================================================================== */

#define GPIO_CLEAR_POS              0
#define GPIO_CLEAR_WIDTH            8
#define GPIO_CLEAR_MASK             BITMASK(GPIO_CLEAR_WIDTH, GPIO_CLEAR_POS)


/* ========================================================================== */
/* GPIO REG_GPIO_TOGGLE Bit Definitions                                       */
/* ========================================================================== */

#define GPIO_TOGGLE_POS             0
#define GPIO_TOGGLE_WIDTH           8
#define GPIO_TOGGLE_MASK            BITMASK(GPIO_TOGGLE_WIDTH, GPIO_TOGGLE_POS)



/* ========================================================================== */
/* GPIO Pin Masks                                                             */
/* ========================================================================== */

#define GPIO_PIN_MASK_0             (1u << 0)
#define GPIO_PIN_MASK_1             (1u << 1)
#define GPIO_PIN_MASK_2             (1u << 2)
#define GPIO_PIN_MASK_3             (1u << 3)
#define GPIO_PIN_MASK_4             (1u << 4)
#define GPIO_PIN_MASK_5             (1u << 5)
#define GPIO_PIN_MASK_6             (1u << 6)
#define GPIO_PIN_MASK_7             (1u << 7)
#define GPIO_ALL_PINS               0xFFu


/* Direction Constants */
// #define GPIO_DIR_INPUT              0u 
// #define GPIO_DIR_OUTPUT             1u


/* ========================================================================== */
/* GPIO Structure Definitions                                                 */
/* ========================================================================== */

/** 
 * @brief GPIO Pin Definitions 
 */
typedef enum {
    GPIO_PIN_0 = 0,
    GPIO_PIN_1 = 1,
    GPIO_PIN_2 = 2,
    GPIO_PIN_3 = 3,
    GPIO_PIN_4 = 4,
    GPIO_PIN_5 = 5,
    GPIO_PIN_6 = 6,
    GPIO_PIN_7 = 7,
    GPIO_PIN_MAX = 8
} gpio_pin_t;


/**
 * @brief GPIO Direction Definition
 */
typedef enum {
    GPIO_DIR_INPUT   = 0u,
    GPIO_DIR_OUTPUT  = 1u
} gpio_direction_t;


/**
 * @brief GPIO pin configuration
 */
typedef struct {
    gpio_pin_t       pin;
    gpio_direction_t direction;
} gpio_config_t;


/**
 * @brief GPIO Device Structute
 */
typedef struct {
    peripheral_t base;
} gpio_t;


/* ========================================================================== */
/* Utility Functions                                                          */
/* ========================================================================== */

/** 
 * @brief Function that cast gpio structure to peripheral structure
 * @param gpio Pointer to gpio structure
 * @return gpio as peripheral 
 */
static inline peripheral_t *gpio_to_peripheral(gpio_t *gpio) {
    return (peripheral_t *)gpio;  // Safe cast - base is first member
}


/** 
 * @brief Function that cast peripheral gpio structure to gpio structure
 * @param gpio Pointer to peripheral structure
 * @return peripheral as gpio
 */
static inline gpio_t *peripheral_to_gpio(peripheral_t *periph) {
    return (gpio_t *)periph;  // Safe cast if originally was gpio_t
}


/* ========================================================================== */
/* Functions Prototypes                                                       */
/* ========================================================================== */


/**
 * @brief Initialize GPIO driver
 * @param dev Pointer to GPIO structure
 * @param base_addr Base address of the GPIO peripheral
*/
void gpio_init(gpio_t *dev, uint32_t base_addr);


/**
 * @brief Set direction for all pins at once
 * @param dev Pointer to GPIO structure
 * @param direction_mask Bitmask where 1=output and 0=input
 */
void gpio_set_direction_all(gpio_t *dev, uint8_t direction_mask);


/**
 * @brief Set direction for a specific pin
 * @param dev Pointer to GPIO structure
 * @param pin Pin number (0-7) of GPIO_PIN_x constant
 * @param direction GPIO_DIR_INPUT or GPIO_DIR_OUTPUT
 */
void gpio_set_direction_pin(gpio_t *dev, gpio_pin_t pin, gpio_direction_t direction);


/**
 * @brief Get current direction settings for all pins
 * @param dev Pointer to GPIO structure
 * @return Direction mask where 1=output and 0=input
 */
uint8_t gpio_get_direction_all(gpio_t *dev);


/**
 * @brief Get current direction for a specific pin
 * @param dev Pointer to GPIO structure
 * @param pin Pin number (0-7) of GPIO_PIN_x constant
 * @return GPIO_DIR_INPUT or GPIO_DIR_OUTPUT
 */
gpio_direction_t gpio_get_direction_pin(gpio_t *dev, gpio_pin_t pin);


/**
 * @brief Write value to all output pins
 * @param dev Pointer to GPIO structure
 * @param value Value to write (each bit corresponds to a pin)
 */
void gpio_write_all(gpio_t *dev, uint8_t value);


/**
 * @brief Write value to a specific output pin
 * @param dev Pointer to GPIO structure
 * @param pin Pin number (0-7) of GPIO_PIN_x constant
 * @param value Value to write (0 or 1)
 */
void gpio_write_pin(gpio_t *dev, gpio_pin_t pin, bool value);


/**
 * @brief Read current state of all pins (inputs and outputs)
 * @param dev Pointer to GPIO structure
 * @return Current state of all pins
 */
uint8_t gpio_read_all(gpio_t *dev);


/**
 * @brief Read current state of a specific pin
 * @param dev Pointer to GPIO structure
 * @param pin Pin number (0-7) of GPIO_PIN_x constant
 * @return Current state of the pin (0 or 1)
 */
bool gpio_read_pin(gpio_t *dev, gpio_pin_t pin);


/**
 * @brief Set specific pins HIGH using SET register
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to set (1=set, 0=no change)
 */
void gpio_set_pins(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief Set a specific pin HIGH using SET register
 * @param dev Pointer to GPIO structure
 * @param pin Pin number (0-7) of GPIO_PIN_x constant
 */
void gpio_set_pin(gpio_t *dev, gpio_pin_t pin);


/**
 * @brief Clear specific pins (LOW) using CLEAR register
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to clear (1=clear, 0=no change)
 */
void gpio_clear_pins(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief Clear a specific pin (LOW) using CLEAR register
 * @param dev Pointer to GPIO structure
 * @param pin Pin number (0-7) of GPIO_PIN_x constant
 */
void gpio_clear_pin(gpio_t *dev, gpio_pin_t pin);


/**
 * @brief Toogle specific pins using TOGGLE register
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to toggle (1=toggle, 0=no change)
 */
void gpio_toggle_pins(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief Toogle a specific pin using TOGGLE register
 * @param dev Pointer to GPIO structure
 * @param pin Pin number (0-7) of GPIO_PIN_x constant
 */
void gpio_toggle_pin(gpio_t *dev, gpio_pin_t pin);


/**
 * @brief Configure multiple pins as inputs or as outputs
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to configure directions number (1=output, 0=input)
 * @param direction GPIO_DIR_INPUT or GPIO_DIR_OUTPUT
 */
void gpio_set_direction_mask(gpio_t *dev, uint8_t pin_mask, gpio_direction_t direction);


/**
 * @brief Configure multiple pins as inputs
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to configure as inputs
 */
void gpio_set_inputs(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief Configure multiple pins as outputs
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to configure as outputs
 */
void gpio_set_outputs(gpio_t *dev, uint8_t pin_mask);


#endif /* GPIO_H */