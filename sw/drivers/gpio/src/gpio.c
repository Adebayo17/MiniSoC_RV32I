/*
 * @file gpio.c
 * @brief GPIO Driver Implementation
*/

#include "../include/gpio.h"
#include "../../../include/system.h"
#include "../../../include/peripheral.h"
#include <stddef.h>


/* ========================================================================== */
/* Private Helper Functions                                                   */
/* ========================================================================== */

/**
 * @brief Update GPIO status from hardware registers
 * @param dev Pointer to GPIO structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t gpio_update_status(gpio_t *dev)
{
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Read current values from hardware */
    dev->status.input_values = READ_REG(dev->base.base_address + REG_GPIO_DATA_OFFSET) & 0xFF;
    dev->status.direction = READ_REG(dev->base.base_address + REG_GPIO_DIR_OFFSET) & 0xFF;
    
    /* For this hardware, data register shows:
     * - Output value if pin is output
     * - Input value if pin is input
     */
    dev->status.output_values = dev->status.input_values & dev->status.direction;
    
    return SYSTEM_SUCCESS;
}


/**
 * @brief Validate pin number
 * @param pin Pin number to validate
 * @return SYSTEM_SUCCESS if valid, error code otherwise
 */
static inline system_error_t validate_pin_number(gpio_pin_t pin)
{
    if (pin >= GPIO_MAX_PINS) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    return SYSTEM_SUCCESS;
}


/**
 * @brief Check if pin is configured as output
 * @param dev Pointer to GPIO structure
 * @param pin Pin number to check
 * @param is_output Pointer to store result
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t check_pin_is_output(gpio_t *dev, gpio_pin_t pin, bool *is_output)
{
    PARAM_CHECK_NOT_NULL(is_output);
    PERIPHERAL_CHECK_VALID(dev);
    
    system_error_t err = validate_pin_number(pin);
    if (IS_ERROR(err)) {
        return err;
    }
    
    uint8_t direction_mask;
    err = gpio_get_direction_all(dev, &direction_mask);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *is_output = (direction_mask & (1u << pin)) != 0;
    return SYSTEM_SUCCESS;
}


/* ========================================================================== */
/* Public GPIO Functions                                                      */
/* ========================================================================== */


system_error_t gpio_init(gpio_t *dev, uint32_t base_addr)
{
    PARAM_CHECK_NOT_NULL(dev);
    
    /* Validate base address */
    if (!IS_GPIO_ADDRESS(base_addr)) {
        return SYSTEM_ERROR_INVALID_ADDRESS;
    }
    
    /* Check if already initialized */
    bool is_initialized = false;
    system_error_t err = peripheral_is_initialized(&dev->base, &is_initialized);
    if (IS_ERROR(err)) {
        return err;
    }
    
    if (is_initialized) {
        return SYSTEM_ERROR_BUSY;
    }
    
    /* Initialize base peripheral */
    err = peripheral_init(&dev->base, base_addr);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Initialize GPIO to known state */
    system_memset(&dev->config, 0, sizeof(dev->config));
    system_memset(&dev->status, 0, sizeof(dev->status));
    
    /* Set all pins as inputs by default (hardware default) */
    /* Note: Hardware reset state is all inputs, outputs low */
    
    /* Update status */
    dev->status.initialized = true;
    err = gpio_update_status(dev);
    if (IS_ERROR(err)) {
        peripheral_deinit(&dev->base);
        return err;
    }
    
    return SYSTEM_SUCCESS;
}


system_error_t gpio_deinit(gpio_t *dev)
{
    PARAM_CHECK_NOT_NULL(dev);
    
    /* Reset GPIO to default state before deinitialization */
    system_error_t err = gpio_reset(dev);
    if (IS_ERROR(err) && err != SYSTEM_ERROR_NOT_READY) {
        /* Continue deinitialization even if reset fails */
    }
    
    /* Deinitialize base peripheral */
    return peripheral_deinit(&dev->base);
}


system_error_t gpio_configure_port(gpio_t *dev, const gpio_port_config_t *config)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, config);
    
    /* Store configuration */
    dev->config = *config;
    
    /* Apply direction settings */
    system_error_t err = gpio_set_direction_all(dev, config->direction_mask);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Apply initial values (only for outputs) */
    uint8_t output_mask = config->direction_mask;
    uint8_t output_values = config->initial_values & output_mask;
    
    if (output_values != 0) {
        err = gpio_set_pins(dev, output_values);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    /* Clear any outputs that should be LOW */
    uint8_t clear_mask = output_mask & ~config->initial_values;
    if (clear_mask != 0) {
        err = gpio_clear_pins(dev, clear_mask);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    /* Update status */
    return gpio_update_status(dev);
}


system_error_t gpio_get_port_config(gpio_t *dev, gpio_port_config_t *config)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, config);
    
    /* Copy configuration */
    *config = dev->config;
    
    /* Update direction mask from current hardware state */
    system_error_t err = gpio_get_direction_all(dev, &config->direction_mask);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Update initial values from current output state */
    config->initial_values = dev->status.output_values;
    
    return SYSTEM_SUCCESS;
}


system_error_t gpio_configure_pin(gpio_t *dev, const gpio_pin_config_t *pin_config)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, pin_config);
    
    /* Validate pin number */
    system_error_t err = validate_pin_number(pin_config->pin);
    if (IS_ERROR(err)) {
        return err;
    }
    
    uint8_t pin_mask = (1u << pin_config->pin);
    
    /* Configure direction */
    err = gpio_set_direction_pin(dev, pin_config->pin, pin_config->direction);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Set initial value for output pins */
    if (pin_config->direction == GPIO_DIR_OUTPUT) {
        if (pin_config->initial_value) {
            err = gpio_set_pin(dev, pin_config->pin);
        } else {
            err = gpio_clear_pin(dev, pin_config->pin);
        }
        
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    /* Update configuration structure */
    if (pin_config->direction == GPIO_DIR_OUTPUT) {
        dev->config.direction_mask |= pin_mask;
    } else {
        dev->config.direction_mask &= ~pin_mask;
    }
    
    if (pin_config->initial_value) {
        dev->config.initial_values |= pin_mask;
    } else {
        dev->config.initial_values &= ~pin_mask;
    }
    
    /* Update status */
    return gpio_update_status(dev);
}


system_error_t gpio_get_pin_config(gpio_t *dev, gpio_pin_t pin, gpio_pin_config_t *pin_config)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, pin_config);
    
    /* Validate pin number */
    system_error_t err = validate_pin_number(pin);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Get direction */
    gpio_direction_t direction;
    err = gpio_get_direction_pin(dev, pin, &direction);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Get current value */
    bool current_value;
    if (direction == GPIO_DIR_OUTPUT) {
        /* For outputs, read from stored output values */
        current_value = (dev->status.output_values & (1u << pin)) != 0;
    } else {
        /* For inputs, read actual pin state */
        err = gpio_read_pin(dev, pin, &current_value);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    /* Fill pin configuration structure */
    pin_config->pin = pin;
    pin_config->direction = direction;
    pin_config->initial_value = current_value;
    
    return SYSTEM_SUCCESS;
}


system_error_t gpio_set_direction_all(gpio_t *dev, uint8_t direction_mask)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Write direction mask to hardware */
    WRITE_REG(dev->base.base_address + REG_GPIO_DIR_OFFSET, direction_mask);
    
    /* Update stored configuration */
    dev->config.direction_mask = direction_mask;
    
    /* Update status */
    return gpio_update_status(dev);
}


system_error_t gpio_set_direction_pin(gpio_t *dev, gpio_pin_t pin, gpio_direction_t direction)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Validate pin number */
    system_error_t err = validate_pin_number(pin);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Read current direction */
    uint8_t current_direction;
    err = gpio_get_direction_all(dev, &current_direction);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Update direction for specific pin */
    uint8_t pin_mask = (1u << pin);
    
    if (direction == GPIO_DIR_OUTPUT) {
        current_direction |= pin_mask;
    } else {
        current_direction &= ~pin_mask;
    }
    
    /* Write updated direction to hardware */
    return gpio_set_direction_all(dev, current_direction);
}


system_error_t gpio_get_direction_all(gpio_t *dev, uint8_t *direction_mask)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, direction_mask);
    
    /* Update status from hardware */
    system_error_t err = gpio_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *direction_mask = dev->status.direction;
    
    return SYSTEM_SUCCESS;
}


system_error_t gpio_get_direction_pin(gpio_t *dev, gpio_pin_t pin, gpio_direction_t *direction)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, direction);
    
    /* Validate pin number */
    system_error_t err = validate_pin_number(pin);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Get direction mask */
    uint8_t direction_mask;
    err = gpio_get_direction_all(dev, &direction_mask);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Extract direction for specific pin */
    uint8_t pin_mask = (1u << pin);
    *direction = (direction_mask & pin_mask) ? GPIO_DIR_OUTPUT : GPIO_DIR_INPUT;
    
    return SYSTEM_SUCCESS;
}


system_error_t gpio_write_all(gpio_t *dev, uint8_t value)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Write value to data register */
    WRITE_REG(dev->base.base_address + REG_GPIO_DATA_OFFSET, value);
    
    /* Update stored configuration */
    dev->config.initial_values = value;
    
    /* Update status */
    return gpio_update_status(dev);
}


system_error_t gpio_write_pin(gpio_t *dev, gpio_pin_t pin, bool value)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Validate pin number */
    system_error_t err = validate_pin_number(pin);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Check if pin is configured as output */
    bool is_output;
    err = check_pin_is_output(dev, pin, &is_output);
    if (IS_ERROR(err)) {
        return err;
    }
    
    if (!is_output) {
        return SYSTEM_ERROR_INVALID_PARAM; /* Cannot write to input pin */
    }
    
    if (value) {
        return gpio_set_pin(dev, pin);
    } else {
        return gpio_clear_pin(dev, pin);
    }
}


system_error_t gpio_read_all(gpio_t *dev, uint8_t *value)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, value);
    
    /* Update status from hardware */
    system_error_t err = gpio_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *value = dev->status.input_values;
    
    return SYSTEM_SUCCESS;
}


system_error_t gpio_read_pin(gpio_t *dev, gpio_pin_t pin, bool *value)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, value);
    
    /* Validate pin number */
    system_error_t err = validate_pin_number(pin);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Update status from hardware */
    err = gpio_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Extract value for specific pin */
    *value = (dev->status.input_values & (1u << pin)) != 0;
    
    return SYSTEM_SUCCESS;
}


system_error_t gpio_set_pins(gpio_t *dev, uint8_t pin_mask)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Write to set register */
    WRITE_REG(dev->base.base_address + REG_GPIO_SET_OFFSET, pin_mask);
    
    /* Update stored configuration */
    dev->config.initial_values |= pin_mask;
    
    /* Update status */
    return gpio_update_status(dev);
}


system_error_t gpio_set_pin(gpio_t *dev, gpio_pin_t pin)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Validate pin number */
    system_error_t err = validate_pin_number(pin);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Set pin using set register */
    return gpio_set_pins(dev, (1u << pin));
}


system_error_t gpio_clear_pins(gpio_t *dev, uint8_t pin_mask)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Write to clear register */
    WRITE_REG(dev->base.base_address + REG_GPIO_CLEAR_OFFSET, pin_mask);
    
    /* Update stored configuration */
    dev->config.initial_values &= ~pin_mask;
    
    /* Update status */
    return gpio_update_status(dev);
}


system_error_t gpio_clear_pin(gpio_t *dev, gpio_pin_t pin)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Validate pin number */
    system_error_t err = validate_pin_number(pin);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Clear pin using clear register */
    return gpio_clear_pins(dev, (1u << pin));
}


system_error_t gpio_toggle_pins(gpio_t *dev, uint8_t pin_mask)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Write to toggle register */
    WRITE_REG(dev->base.base_address + REG_GPIO_TOGGLE_OFFSET, pin_mask);
    
    /* Update stored configuration */
    dev->config.initial_values ^= pin_mask;
    
    /* Update status */
    return gpio_update_status(dev);
}


system_error_t gpio_toggle_pin(gpio_t *dev, gpio_pin_t pin)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Validate pin number */
    system_error_t err = validate_pin_number(pin);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Toggle pin using toggle register */
    return gpio_toggle_pins(dev, (1u << pin));
}


system_error_t gpio_set_inputs(gpio_t *dev, uint8_t pin_mask)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Get current direction */
    uint8_t current_direction;
    system_error_t err = gpio_get_direction_all(dev, &current_direction);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Clear direction bits for specified pins */
    current_direction &= ~pin_mask;
    
    /* Apply new direction */
    return gpio_set_direction_all(dev, current_direction);
}


system_error_t gpio_set_outputs(gpio_t *dev, uint8_t pin_mask, uint8_t initial_value)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Get current direction */
    uint8_t current_direction;
    system_error_t err = gpio_get_direction_all(dev, &current_direction);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Set direction bits for specified pins */
    current_direction |= pin_mask;
    
    /* Apply new direction */
    err = gpio_set_direction_all(dev, current_direction);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Set initial values for outputs */
    uint8_t set_mask = initial_value & pin_mask;
    if (set_mask != 0) {
        err = gpio_set_pins(dev, set_mask);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    /* Clear any pins that should be low */
    uint8_t clear_mask = pin_mask & ~initial_value;
    if (clear_mask != 0) {
        err = gpio_clear_pins(dev, clear_mask);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    return SYSTEM_SUCCESS;
}


system_error_t gpio_get_status(gpio_t *dev, gpio_status_t *status)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, status);
    
    /* Update status from hardware */
    system_error_t err = gpio_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Copy status */
    *status = dev->status;
    
    return SYSTEM_SUCCESS;
}


system_error_t gpio_reset(gpio_t *dev)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Set all pins as inputs (hardware default) */
    WRITE_REG(dev->base.base_address + REG_GPIO_DIR_OFFSET, 0x00);
    
    /* Clear all outputs (hardware default) */
    WRITE_REG(dev->base.base_address + REG_GPIO_DATA_OFFSET, 0x00);
    
    /* Clear any set/clear/toggle operations */
    WRITE_REG(dev->base.base_address + REG_GPIO_SET_OFFSET, 0x00);
    WRITE_REG(dev->base.base_address + REG_GPIO_CLEAR_OFFSET, 0x00);
    WRITE_REG(dev->base.base_address + REG_GPIO_TOGGLE_OFFSET, 0x00);
    
    /* Reset configuration to defaults */
    system_memset(&dev->config, 0, sizeof(dev->config));
    
    /* Update status */
    system_error_t err = gpio_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    return SYSTEM_SUCCESS;
}


system_error_t gpio_validate_pin(gpio_pin_t pin)
{
    return validate_pin_number(pin);
}


