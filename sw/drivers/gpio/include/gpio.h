/*
 * @file gpio.h
 * @brief GPIO Driver
*/

#ifndef GPIO_H
#define GPIO_H

#include "../../../include/peripheral.h"       /* peripheral_t structure */
#include "../../../include/errors.h"           /* system_error_t */


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


/* Maximum number of GPIO pins */
#define GPIO_MAX_PINS               8


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
    GPIO_PIN_7 = 7
} gpio_pin_t;


/**
 * @brief GPIO Direction Definition
 */
typedef enum {
    GPIO_DIR_INPUT   = 0u,
    GPIO_DIR_OUTPUT  = 1u
} gpio_direction_t;


/**
 * @brief GPIO pin configuration structutr
 * Note: This SoC doesn't support pull-up/down or drive strength configuration
 * Those fields are included for future compatibility but will be ignored
 */
typedef struct {
    gpio_pin_t          pin;            /* Pin number */
    gpio_direction_t    direction;      /* Input or Output */
    bool                initial_value;  /* Initial value for output */
} gpio_pin_config_t;


/**
 * @brief GPIO port configuration structure
 */
typedef struct {
    uint8_t          direction_mask;    /* 1=output, 0=input */
    uint8_t          initial_values;    /* Initial output values */
} gpio_port_config_t;


/**
 * @brief GPIO Status structure
 */
typedef struct {
    uint8_t          input_values;      /* Current input values */
    uint8_t          output_values;     /* Current output values */
    uint8_t          direction;         /* Current direction settings */
    bool             initialized;       /* Whether GPIO is initialized */
} gpio_status_t;


/**
 * @brief GPIO Device Structute
 */
typedef struct {
    peripheral_t        base;           /* Base peripheral structure */
    gpio_port_config_t  config;         /* Current configuration */
    gpio_status_t       status;         /* Current status */
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
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_init(gpio_t *dev, uint32_t base_addr);


/**
 * @brief Deinitialize GPIO driver
 * @param dev Pointer to GPIO structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_deinit(gpio_t *dev);


/**
 * @brief Configure GPIO port with specified parameters
 * @param dev Pointer to GPIO structure
 * @param config Pointer to port configuration structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_configure_port(gpio_t *dev, const gpio_port_config_t *config);


/**
 * @brief Get current GPIO port configuration
 * @param dev Pointer to GPIO structure
 * @param config Pointer to store configuration
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_get_port_config(gpio_t *dev, gpio_port_config_t *config);


/**
 * @brief Configure a single GPIO pin
 * @param dev Pointer to GPIO structure
 * @param pin_config Pointer to pin configuration structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_configure_pin(gpio_t *dev, const gpio_pin_config_t *pin_config);


/**
 * @brief Get configuration of a single GPIO pin
 * @param dev Pointer to GPIO structure
 * @param pin Pin number
 * @param pin_config Pointer to store pin configuration
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_get_pin_config(gpio_t *dev, gpio_pin_t pin, gpio_pin_config_t *pin_config);


/**
 * @brief Set direction for all pins at once
 * @param dev Pointer to GPIO structure
 * @param direction_mask Bitmask where 1=output and 0=input
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_direction_all(gpio_t *dev, uint8_t direction_mask);


/**
 * @brief Set direction for a specific pin
 * @param dev Pointer to GPIO structure
 * @param pin Pin number
 * @param direction GPIO_DIR_INPUT or GPIO_DIR_OUTPUT
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_direction_pin(gpio_t *dev, gpio_pin_t pin, gpio_direction_t direction);


/**
 * @brief Get current direction settings for all pins
 * @param dev Pointer to GPIO structure
 * @param direction_mask Pointer to store direction mask (1=output, 0=input)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_get_direction_all(gpio_t *dev, uint8_t *direction_mask);


/**
 * @brief Get current direction for a specific pin
 * @param dev Pointer to GPIO structure
 * @param pin Pin number
 * @param direction Pointer to store direction
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_get_direction_pin(gpio_t *dev, gpio_pin_t pin, gpio_direction_t *direction);


/**
 * @brief Write value to all output pins
 * @param dev Pointer to GPIO structure
 * @param value Value to write (each bit corresponds to a pin)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_write_all(gpio_t *dev, uint8_t value);


/**
 * @brief Write value to a specific output pin
 * @param dev Pointer to GPIO structure
 * @param pin Pin number
 * @param value Value to write (true for HIGH, false for LOW)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_write_pin(gpio_t *dev, gpio_pin_t pin, bool value);


/**
 * @brief Read current state of all pins (inputs and outputs)
 * @param dev Pointer to GPIO structure
 * @param value Pointer to store pin values
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_read_all(gpio_t *dev, uint8_t *value);


/**
 * @brief Read current state of a specific pin
 * @param dev Pointer to GPIO structure
 * @param pin Pin number
 * @param value Pointer to store pin value (true for HIGH, false for LOW)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_read_pin(gpio_t *dev, gpio_pin_t pin, bool *value);


/**
 * @brief Set specific pins HIGH using SET register
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to set (1=set, 0=no change)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_pins(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief Set a specific pin HIGH using SET register
 * @param dev Pointer to GPIO structure
 * @param pin Pin number
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_pin(gpio_t *dev, gpio_pin_t pin);


/**
 * @brief Clear specific pins (LOW) using CLEAR register
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to clear (1=clear, 0=no change)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_clear_pins(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief Clear a specific pin (LOW) using CLEAR register
 * @param dev Pointer to GPIO structure
 * @param pin Pin number
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_clear_pin(gpio_t *dev, gpio_pin_t pin);


/**
 * @brief Toggle specific pins using TOGGLE register
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to toggle (1=toggle, 0=no change)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_toggle_pins(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief Toggle a specific pin using TOGGLE register
 * @param dev Pointer to GPIO structure
 * @param pin Pin number
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_toggle_pin(gpio_t *dev, gpio_pin_t pin);


/**
 * @brief Configure multiple pins as inputs
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to configure as inputs
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_inputs(gpio_t *dev, uint8_t pin_mask);


/**
 * @brief Configure multiple pins as outputs
 * @param dev Pointer to GPIO structure
 * @param pin_mask Bitmask of pins to configure as outputs
 * @param initial_value Initial value for outputs (optional, use 0xFF for HIGH, 0x00 for LOW)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_set_outputs(gpio_t *dev, uint8_t pin_mask, uint8_t initial_value);


/**
 * @brief Get GPIO status
 * @param dev Pointer to GPIO structure
 * @param status Pointer to store status information
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_get_status(gpio_t *dev, gpio_status_t *status);


/**
 * @brief Reset GPIO to default state
 * @param dev Pointer to GPIO structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t gpio_reset(gpio_t *dev);


/**
 * @brief Validate GPIO pin number
 * @param pin Pin number to validate
 * @return SYSTEM_SUCCESS if valid, SYSTEM_ERROR_INVALID_PARAM if invalid
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