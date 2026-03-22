/*
 * @file    gpio.h
 * @brief   GPIO Driver Interface.
 * @details Conforms to the Barr Group Embedded C Coding Standard.
*/

#ifndef GPIO_H
#define GPIO_H


#include <stdint.h>
#include <stdbool.h>
#include "peripheral.h"       /* peripheral_t structure */
#include "errors.h"           /* system_error_t */


/* ========================================================================== */
/* GPIO Types Definitions                                                     */
/* ========================================================================== */

/** 
 * @brief GPIO Pin Definitions 
 */
typedef enum 
{
    GPIO_PIN_0 = 0,
    GPIO_PIN_1 = 1,
    GPIO_PIN_2 = 2,
    GPIO_PIN_3 = 3,
    GPIO_PIN_4 = 4,
    GPIO_PIN_5 = 5,
    GPIO_PIN_6 = 6,
    GPIO_PIN_7 = 7
} gpio_pin_t;


/**
 * @brief GPIO Direction Definition
 */
typedef enum 
{
    GPIO_DIR_INPUT   = 0u,
    GPIO_DIR_OUTPUT  = 1u
} gpio_direction_t;


/* ========================================================================== */
/* GPIO Configuration Structures                                              */
/* ========================================================================== */


/**
 * @struct gpio_pin_config_t
 * @brief GPIO pin configuration structure
 * Note: This SoC doesn't support pull-up/down or drive strength configuration
 * Those fields are included for future compatibility but will be ignored
 */
typedef struct 
{
    gpio_pin_t          pin;            /*!< Pin number (0-7) */
    gpio_direction_t    direction;      /*!< Input or Output */
    bool                initial_value;  /*!< Initial value (if configured as output) */
} gpio_pin_config_t;


/**
 * @struct gpio_port_config_t
 * @brief  GPIO port configuration structure
 */
typedef struct 
{
    uint8_t          direction_mask;    /*!< Bitmask: 1=output, 0=input */
    uint8_t          initial_values;    /*!< Bitmask: Initial output values */
} gpio_port_config_t;


/**
 * @struct gpio_status_t
 * @brief  Current status cache of the GPIO port.
 */
typedef struct 
{
    uint8_t          input_values;      /*!< Current input values */
    uint8_t          output_values;     /*!< Current output values */
    uint8_t          direction;         /*!< Current direction settings */
} gpio_status_t;


/**
 * @struct gpio_t
 * @brief  GPIO Device Handle
 */
typedef struct 
{
    peripheral_t        base;           /*!< Base peripheral structure */
    gpio_port_config_t  config;         /*!< Current software configuration */
    gpio_status_t       status;         /*!< Current status cache */
} gpio_t;


/* ========================================================================== */
/* Utility Functions                                                          */
/* ========================================================================== */

/** 
 * @brief   Cast GPIO handle to base peripheral structure 
 * @param   [in] gpio Pointer to gpio structure
 * @return  Safe cast to peripheral_t pointer.
 */
static inline peripheral_t *gpio_to_peripheral(gpio_t *gpio) 
{
    /* Safe cast - base is first member */
    return (peripheral_t *)gpio;
}


/** 
 * @brief  Cast base peripheral structure to GPIO handle
 * @param   [in] periph Pointer to peripheral structure
 * @return  Safe cast to gpio_t pointer.
 */
static inline gpio_t *peripheral_to_gpio(peripheral_t *periph) 
{
    /* Safe cast if originally was gpio_t */
    return (gpio_t *)periph;
}


/* ========================================================================== */
/* Functions Prototypes                                                       */
/* ========================================================================== */


/**
 * @brief   Initialize GPIO driver
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] base_addr Base address of the GPIO peripheral
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_init(gpio_t *dev, uint32_t base_addr);


/**
 * @brief   Deinitialize GPIO driver
 * @param   [in] dev Pointer to GPIO structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_deinit(gpio_t *dev);


/**
 * @brief   Reset GPIO to default state
 * @param   [in] dev Pointer to GPIO structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_reset(gpio_t *dev);


/**
 * @brief   Configure GPIO port with specified parameters
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] config Pointer to port configuration structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_configure_port(gpio_t *dev, const gpio_port_config_t *config);


/**
 * @brief   Get current GPIO port configuration
 * @param   [in] dev Pointer to GPIO structure
 * @param   [out] config Pointer to store configuration
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_get_port_config(gpio_t *dev, gpio_port_config_t *config);


/**
 * @brief   Configure a single GPIO pin
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin_config Pointer to pin configuration structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_configure_pin(gpio_t *dev, const gpio_pin_config_t *pin_config);


/**
 * @brief   Get configuration of a single GPIO pin
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin Pin number
 * @param   [out] pin_config Pointer to store pin configuration
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_get_pin_config(gpio_t *dev, gpio_pin_t pin, gpio_pin_config_t *pin_config);


/**
 * @brief   Set direction for all pins at once
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] direction_mask Bitmask where 1=output and 0=input
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_direction_all(gpio_t *dev, uint8_t direction_mask);


/**
 * @brief   Set direction for a specific pin
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin Pin number
 * @param   [in] direction GPIO_DIR_INPUT or GPIO_DIR_OUTPUT
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_direction_pin(gpio_t *dev, gpio_pin_t pin, gpio_direction_t direction);


/**
 * @brief   Get current direction settings for all pins
 * @param   [in]  dev Pointer to GPIO structure
 * @param   [out] direction_mask Pointer to store direction mask (1=output, 0=input)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_get_direction_all(gpio_t *dev, uint8_t *direction_mask);


/**
 * @brief   Get current direction for a specific pin
 * @param   [in]  dev Pointer to GPIO structure
 * @param   [in]  pin Pin number
 * @param   [out] direction Pointer to store direction
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_get_direction_pin(gpio_t *dev, gpio_pin_t pin, gpio_direction_t *direction);


/**
 * @brief   Write value to all output pins
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] value Value to write (each bit corresponds to a pin)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_write_all(gpio_t *dev, uint8_t value);


/**
 * @brief   Write value to a specific output pin
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin Pin number
 * @param   [in] value Value to write (true for HIGH, false for LOW)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_write_pin(gpio_t *dev, gpio_pin_t pin, bool value);


/**
 * @brief   Read current state of all pins (inputs and outputs)
 * @param   [in]  dev Pointer to GPIO structure
 * @param   [out] value Pointer to store pin values
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_read_all(gpio_t *dev, uint8_t *value);


/**
 * @brief   Read current state of a specific pin
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin Pin number
 * @param   [out] value Pointer to store pin value (true for HIGH, false for LOW)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_read_pin(gpio_t *dev, gpio_pin_t pin, bool *value);


/* Hardware Accelerated Atomic Operations */


/**
 * @brief   Set specific pins HIGH using SET register
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin_mask Bitmask of pins to set (1=set, 0=no change)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_pins(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief   Set a specific pin HIGH using SET register
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin Pin number
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_pin(gpio_t *dev, gpio_pin_t pin);


/**
 * @brief   Clear specific pins (LOW) using CLEAR register
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin_mask Bitmask of pins to clear (1=clear, 0=no change)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_clear_pins(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief   Clear a specific pin (LOW) using CLEAR register
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin Pin number
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_clear_pin(gpio_t *dev, gpio_pin_t pin);


/**
 * @brief   Toggle specific pins using TOGGLE register
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin_mask Bitmask of pins to toggle (1=toggle, 0=no change)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_toggle_pins(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief   Toggle a specific pin using TOGGLE register
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin Pin number
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_toggle_pin(gpio_t *dev, gpio_pin_t pin);


/* Direction Helpers */


/**
 * @brief   Configure multiple pins as inputs
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin_mask Bitmask of pins to configure as inputs
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_inputs(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief   Configure multiple pins as outputs
 * @param   [in] dev Pointer to GPIO structure
 * @param   [in] pin_mask Bitmask of pins to configure as outputs
 * @param   [in] initial_value Initial value for outputs (optional, use 0xFF for HIGH, 0x00 for LOW)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_outputs(gpio_t *dev, uint8_t pin_mask, uint8_t initial_value);


/**
 * @brief   Get GPIO status
 * @param   [in] dev Pointer to GPIO structure
 * @param   [out] status Pointer to store status information
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_get_status(gpio_t *dev, gpio_status_t *status_out);



/**
 * @brief   Validate GPIO pin number
 * @param   [in] pin Pin number to validate
 * @return  SYSTEM_SUCCESS if valid, SYSTEM_ERROR_INVALID_PARAM if invalid
 */
system_error_t gpio_validate_pin(gpio_pin_t pin);



/* ========================================================================== */
/* Hardware-Specific Notes                                                    */
/* ========================================================================== */

/*
 * Hardware Limitations:
 * 1. No pull-up/pull-down resistor configuration
 * 2. No drive strength configuration
 * 3. Inputs are synchronized with 2-stage synchronizer
 * 4. Output values stored in out_reg
 * 5. Direction controlled by dir_reg (1=output, 0=input)
 * 6. SET/CLEAR/TOGGLE registers provide atomic operations
 */

 
#endif /* GPIO_H */