/*
 * @file    gpio.c
 * @brief   GPIO Driver Implementation.
 * @details Conforms to the Barr Group Embedded C Coding Standard.
*/

#include "../include/gpio.h"
#include "gpio_hw.h"
#include <stddef.h>


/* ========================================================================== */
/* Private Helper Functions                                                   */
/* ========================================================================== */

/**
 * @brief   Gets the hardware structure (registers) based on the GPIO handle.
 * @param   [in] dev Pointeur to the GPIO structure.
 * @return  Pointer to GPIO hardware registers, or NULL if invalid handle.
 */
static inline gpio_regs_t* gpio_get_hw_regs(const gpio_t *dev)
{
    return (gpio_regs_t *)(dev->base.base_address);
}


/* ========================================================================== */
/* Specific Validation                                                        */
/* ========================================================================== */

system_error_t gpio_validate_pin(gpio_pin_t pin)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((uint32_t)pin >= GPIO_MAX_PINS)
    {
        status = SYSTEM_ERROR_GPIO_INVALID_PIN;
    }

    return status;
}


/* ========================================================================== */
/* Initialization and Basic Configuration                                     */
/* ========================================================================== */

system_error_t gpio_init(gpio_t *dev, uint32_t base_addr)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (dev == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_init(gpio_to_peripheral(dev), base_addr);

        if (is_success(status))
        {
            gpio_regs_t *hw = gpio_get_hw_regs(dev);

            /* Hardware initialization: all inputs, all outputs at 0 */
            hw->DIR   = 0U;
            hw->CLEAR = GPIO_ALL_PINS_MASK; 

            /* Software context initialization */
            dev->config.direction_mask = 0U;
            dev->config.initial_values = 0U;

            dev->status.direction     = 0U;
            dev->status.output_values = 0U;
            dev->status.input_values  = 0U;
        }
    }

    return status;
}


system_error_t gpio_deinit(gpio_t *dev)
{
    system_error_t status = SYSTEM_SUCCESS;

    status = peripheral_check_valid(gpio_to_peripheral(dev));

    if (is_success(status))
    {
        gpio_regs_t *hw = gpio_get_hw_regs(dev);
        
        /* Hardware : Restoring safety to a state of disrepair (all entrances) */
        hw->DIR = 0U;

        /* Software : Deactivation */
        status = peripheral_deinit(gpio_to_peripheral(dev));
    }

    return status;
}


system_error_t gpio_reset(gpio_t *dev)
{
    system_error_t status = SYSTEM_SUCCESS;

    status = peripheral_check_valid(gpio_to_peripheral(dev));

    if (is_success(status))
    {
        gpio_regs_t *hw = gpio_get_hw_regs(dev);

        hw->DIR   = 0U;
        hw->CLEAR = GPIO_ALL_PINS_MASK;

        dev->config.direction_mask = 0U;
        dev->config.initial_values = 0U;
        
        dev->status.direction     = 0U;
        dev->status.output_values = 0U;
        dev->status.input_values  = 0U;
    }

    return status;
}


/* ========================================================================== */
/* Advanced Configuration (Port & Pins)                                       */
/* ========================================================================== */


system_error_t gpio_configure_port(gpio_t *dev, const gpio_port_config_t *config)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (config == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(gpio_to_peripheral(dev));

        if (is_success(status))
        {
            gpio_regs_t *hw = gpio_get_hw_regs(dev);

            /* 1. Apply the initial values ​​to the outputs via the DATA register */
            hw->DATA = config->initial_values;
            
            /* 2. Apply the directions */
            hw->DIR = config->direction_mask;

            /* 3. Update software cache */
            dev->config                 = *config;
            dev->status.direction       = config->direction_mask;
            dev->status.output_values   = config->initial_values;
        }
    }

    return status;
}


system_error_t gpio_get_port_config(gpio_t *dev, gpio_port_config_t *config)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (config == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(gpio_to_peripheral(dev));

        if (is_success(status))
        {
            *config = dev->config;
        }
        
    }
    
    return status;
}


system_error_t gpio_configure_pin(gpio_t *dev, const gpio_pin_config_t *pin_config)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (pin_config == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(gpio_to_peripheral(dev));

        if (is_success(status))
        {
            status = gpio_validate_pin(pin_config->pin);

            if (is_success(status))
            {
                gpio_regs_t *hw = gpio_get_hw_regs(dev);
                uint32_t pin_mask = (1UL << (uint32_t)pin_config->pin);

                /* Configuration of the direction and initial value */
                if (pin_config->direction == GPIO_DIR_OUTPUT)
                {
                    /* The initial value is forced before the output is activated. */
                    if (pin_config->initial_value)
                    {
                        hw->SET = pin_mask;
                        dev->status.output_values |= pin_mask;
                    }
                    else
                    {
                        hw->CLEAR = pin_mask;
                        dev->status.output_values &= ~pin_mask;
                    }

                    /* The DIR register does not have a hardware Set/Clear function; we perform an RMW (Read-Modify-Write). */
                    hw->DIR |= pin_mask;
                    dev->status.direction |= pin_mask;
                }
                else
                {
                    /* Input Configuration */
                    hw->DIR &= ~pin_mask;
                    dev->status.direction &= ~pin_mask;
                }
            }
        }
    }

    return status;
}


system_error_t gpio_get_pin_config(gpio_t *dev, gpio_pin_t pin, gpio_pin_config_t *pin_config)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (pin_config == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(gpio_to_peripheral(dev));

        if (is_success(status))
        {
            status = gpio_validate_pin(pin);

            if (is_success(status))
            {
                uint8_t pin_mask = (1U << (uint8_t)pin);

                pin_config->pin = pin;

                if ((dev->status.direction & pin_mask) != 0U)
                {
                    pin_config->direction = GPIO_DIR_OUTPUT;
                }
                else
                {
                    pin_config->direction = GPIO_DIR_INPUT;
                }

                if ((dev->status.output_values & pin_mask) != 0U)
                {
                    pin_config->initial_value = true;
                }
                else
                {
                    pin_config->initial_value = false;
                }
                
            }
            
        }
        
    }

    return status;
}


system_error_t gpio_set_direction_all(gpio_t *dev, uint8_t direction_mask)
{
    system_error_t status = peripheral_check_valid(gpio_to_peripheral(dev));

    if (is_success(status))
    {
        gpio_regs_t *hw = gpio_get_hw_regs(dev);
        
        hw->DIR = (uint32_t)direction_mask;
        dev->status.direction = direction_mask;
        dev->config.direction_mask = direction_mask;
    }

    return status;
}


system_error_t gpio_set_direction_pin(gpio_t *dev, gpio_pin_t pin, gpio_direction_t direction)
{
    system_error_t status = peripheral_check_valid(gpio_to_peripheral(dev));

    if (is_success(status))
    {
        status = gpio_validate_pin(pin);

        if (is_success(status))
        {
            gpio_regs_t *hw = gpio_get_hw_regs(dev);
            uint32_t pin_mask = (1UL << (uint32_t)pin);

            if (direction == GPIO_DIR_OUTPUT)
            {
                hw->DIR |= pin_mask;
                dev->status.direction |= (uint8_t)pin_mask;
            }
            else
            {
                hw->DIR &= ~pin_mask;
                dev->status.direction &= (uint8_t)(~pin_mask);
            }
        }
    }

    return status;
}


system_error_t gpio_get_direction_all(gpio_t *dev, uint8_t *direction_mask)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (direction_mask == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(gpio_to_peripheral(dev));

        if (is_success(status))
        {
            *direction_mask = dev->status.direction;
        }
    }

    return status;
}


system_error_t gpio_get_direction_pin(gpio_t *dev, gpio_pin_t pin, gpio_direction_t *direction)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (direction == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(gpio_to_peripheral(dev));

        if (is_success(status))
        {
            status = gpio_validate_pin(pin);

            if (is_success(status))
            {
                uint8_t pin_mask = (1U << (uint8_t)pin);

                if ((dev->status.direction & pin_mask) != 0U)
                {
                    *direction = GPIO_DIR_OUTPUT;
                }
                else
                {
                    *direction = GPIO_DIR_INPUT;
                }
            }
        }
    }

    return status;
}


/* ========================================================================== */
/* Read & Write (Global Operation / Full Port)                                */
/* ========================================================================== */

system_error_t gpio_write_all(gpio_t *dev, uint8_t value)
{
    system_error_t status = peripheral_check_valid(gpio_to_peripheral(dev));

    if (is_success(status))
    {
        gpio_regs_t *hw = gpio_get_hw_regs(dev);
        
        /* Direct writing across the entire port */
        hw->DATA = (uint32_t)value;
        dev->status.output_values = value;
    }

    return status;
}


system_error_t gpio_read_all(gpio_t *dev, uint8_t *value)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (value == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(gpio_to_peripheral(dev));

        if (is_success(status))
        {
            gpio_regs_t *hw = gpio_get_hw_regs(dev);
            
            /*  The Verilog intelligently manages the reading of the DATA register
                by returning either the synchronized inputs or the output values */
            uint8_t read_val = (uint8_t)(hw->DATA & GPIO_ALL_PINS_MASK);
            
            *value = read_val;
            dev->status.input_values = read_val;
        }
    }

    return status;
}


/* ========================================================================== */
/* Hardware Atomic Operations (Verilog Acceleration)                          */
/* ========================================================================== */


system_error_t gpio_set_pins(gpio_t *dev, uint8_t pin_mask)
{
    system_error_t status = peripheral_check_valid(gpio_to_peripheral(dev));

    if (is_success(status))
    {
        gpio_regs_t *hw = gpio_get_hw_regs(dev);
        
        /* Pure Hardware Atomic Operation (no RMW) */
        hw->SET = (uint32_t)pin_mask;
        dev->status.output_values |= pin_mask;
    }

    return status;
}


system_error_t gpio_set_pin(gpio_t *dev, gpio_pin_t pin)
{
    system_error_t status = gpio_validate_pin(pin);

    if (is_success(status))
    {
        status = gpio_set_pins(dev, (1U << (uint8_t)pin));
    }

    return status;
}


system_error_t gpio_clear_pins(gpio_t *dev, uint8_t pin_mask)
{
    system_error_t status = peripheral_check_valid(gpio_to_peripheral(dev));

    if (is_success(status))
    {
        gpio_regs_t *hw = gpio_get_hw_regs(dev);
        
        /* Pure Hardware Atomic Operation */
        hw->CLEAR = (uint32_t)pin_mask;
        dev->status.output_values &= ~pin_mask;
    }

    return status;
}


system_error_t gpio_clear_pin(gpio_t *dev, gpio_pin_t pin)
{
    system_error_t status = gpio_validate_pin(pin);

    if (is_success(status))
    {
        status = gpio_clear_pins(dev, (1U << (uint8_t)pin));
    }

    return status;
}


system_error_t gpio_toggle_pins(gpio_t *dev, uint8_t pin_mask)
{
    system_error_t status = peripheral_check_valid(gpio_to_peripheral(dev));

    if (is_success(status))
    {
        gpio_regs_t *hw = gpio_get_hw_regs(dev);
        
        /* Pure Hardware Atomic Operation */
        hw->TOGGLE = (uint32_t)pin_mask;
        dev->status.output_values ^= pin_mask;
    }

    return status;
}


system_error_t gpio_toggle_pin(gpio_t *dev, gpio_pin_t pin)
{
    system_error_t status = gpio_validate_pin(pin);

    if (is_success(status))
    {
        status = gpio_toggle_pins(dev, (1U << (uint8_t)pin));
    }

    return status;
}


/* ========================================================================== */
/* Simplified Inherited Functions (Based on Atomic Operations)                */
/* ========================================================================== */


system_error_t gpio_write_pin(gpio_t *dev, gpio_pin_t pin, bool value)
{
    system_error_t status = SYSTEM_SUCCESS;
    
    if (value)
    {
        status = gpio_set_pin(dev, pin);
    }
    else
    {
        status = gpio_clear_pin(dev, pin);
    }

    return status;
}


system_error_t gpio_read_pin(gpio_t *dev, gpio_pin_t pin, bool *value)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (value == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = gpio_validate_pin(pin);

        if (is_success(status))
        {
            uint8_t port_values = 0U;
            status = gpio_read_all(dev, &port_values);
            
            if (is_success(status))
            {
                *value = ((port_values & (1U << (uint8_t)pin)) != 0U);
            }
        }
    }

    return status;
}


/* ========================================================================== */
/* Direction Functions Implementation                                         */
/* ========================================================================== */

system_error_t gpio_set_inputs(gpio_t *dev, uint8_t pin_mask)
{
    system_error_t status = peripheral_check_valid(gpio_to_peripheral(dev));

    if (is_success(status))
    {
        gpio_regs_t *hw = gpio_get_hw_regs(dev);
        
        /* Input Configuration (RMW on the DIR register) */
        hw->DIR &= ~((uint32_t)pin_mask);
        dev->status.direction &= ~pin_mask;
    }

    return status;
}


system_error_t gpio_set_outputs(gpio_t *dev, uint8_t pin_mask, uint8_t initial_value)
{
    system_error_t status = peripheral_check_valid(gpio_to_peripheral(dev));

    if (is_success(status))
    {
        gpio_regs_t *hw = gpio_get_hw_regs(dev);
        
        /* The requested value is applied only to the bits of the mask.
           Since we don't have a masked atomic operation for arbitrary writing, 
           we use the SET and CLEAR registers. */
        uint32_t bits_to_set   = (uint32_t)(pin_mask & initial_value);
        uint32_t bits_to_clear = (uint32_t)(pin_mask & ~initial_value);

        if (bits_to_set > 0U)   hw->SET   = bits_to_set;
        if (bits_to_clear > 0U) hw->CLEAR = bits_to_clear;

        /* Activating outputs (RMW on the DIR register) */
        hw->DIR |= (uint32_t)pin_mask;

        dev->status.output_values = (dev->status.output_values & ~pin_mask) | (initial_value & pin_mask);
        dev->status.direction |= pin_mask;
    }

    return status;
}


system_error_t gpio_get_status(gpio_t *dev, gpio_status_t *status_out)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (status_out == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(gpio_to_peripheral(dev));

        if (is_success(status))
        {
            /* Force une relecture physique du port pour rafraichir input_values */
            uint8_t dummy = 0U;
            (void)gpio_read_all(dev, &dummy);

            *status_out = dev->status;
        }
    }

    return status;
}


