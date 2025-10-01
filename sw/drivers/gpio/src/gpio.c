/*
 * @file gpio.c
 * @brief GPIO Driver Implementation
*/

#include "gpio.h"
#include <stddef.h>


void gpio_init(gpio_t *dev, uint32_t base_addr) 
{
    /* Initialize base */
    peripheral_init(&dev->base, base_addr);

    /* Initialize all pins as inputs by default */
    gpio_set_direction_all(dev, 0x00);

    /* Set all outputs to low */
    gpio_write_all(dev, 0x00);
}


void gpio_set_direction_all(gpio_t *dev, uint8_t direction_mask)
{
    WRITE_REG(dev->base.base_address + REG_GPIO_DIR_OFFSET, direction_mask);
}


void gpio_set_direction_pin(gpio_t *dev, gpio_pin_t pin, gpio_direction_t direction)
{
    if (pin >= GPIO_PIN_MAX) return;

    uint8_t current_dir = gpio_get_direction_all(dev);

    if (direction == GPIO_DIR_OUTPUT)
    {
        current_dir |= (1u << pin);
    }
    else
    {
        current_dir &= ~(1u << pin);
    }

    gpio_set_direction_all(dev, current_dir);
    
}


uint8_t gpio_get_direction_all(gpio_t *dev)
{
    return (uint8_t)(READ_REG(dev->base.base_address + REG_GPIO_DIR_OFFSET) & 0xFF);
}


gpio_direction_t gpio_get_direction_pin(gpio_t *dev, gpio_pin_t pin)
{
    if (pin >= GPIO_PIN_MAX) return GPIO_DIR_INPUT;

    uint8_t direction = gpio_get_direction_all(dev);
    return (direction & (1u << pin)) ? GPIO_DIR_OUTPUT : GPIO_DIR_INPUT;
}


void gpio_write_all(gpio_t *dev, uint8_t value)
{
    WRITE_REG(dev->base.base_address + REG_GPIO_DATA_OFFSET, value);
}


void gpio_write_pin(gpio_t *dev, gpio_pin_t pin, bool value)
{
    if (pin >= GPIO_PIN_MAX) return;

    if (value)
    {
        gpio_set_pin(dev, pin);
    }
    else
    {
        gpio_clear_pin(dev, pin);
    }
    
}



uint8_t gpio_read_all(gpio_t *dev)
{
    return (uint8_t)(READ_REG(dev->base.base_address + REG_GPIO_DATA_OFFSET) & 0xFF);
}


bool gpio_read_pin(gpio_t *dev, gpio_pin_t pin)
{
    if (pin >= GPIO_PIN_MAX) return false;

    uint8_t input_value = gpio_read_all(dev);
    return ( (input_value & (1u << pin)) != 0 );
}


void gpio_set_pins(gpio_t *dev, uint8_t pin_mask)
{
    WRITE_REG(dev->base.base_address + REG_GPIO_SET_OFFSET, pin_mask);
}


void gpio_set_pin(gpio_t *dev, gpio_pin_t pin)
{
    if (pin >= GPIO_PIN_MAX) return;
    gpio_set_pins(dev, (1u << pin));
}


void gpio_clear_pins(gpio_t *dev, uint8_t pin_mask)
{
    WRITE_REG(dev->base.base_address + REG_GPIO_CLEAR_OFFSET, pin_mask);
}


void gpio_clear_pin(gpio_t *dev, gpio_pin_t pin)
{
    if (pin >= GPIO_PIN_MAX) return;
    gpio_clear_pins(dev, (1u << pin));
}


void gpio_toggle_pins(gpio_t *dev, uint8_t pin_mask)
{
    WRITE_REG(dev->base.base_address + REG_GPIO_TOGGLE_OFFSET, pin_mask);
}


void gpio_toggle_pin(gpio_t *dev, gpio_pin_t pin)
{
    if (pin >= GPIO_PIN_MAX) return;
    gpio_toggle_pins(dev, (1u << pin));
}


void gpio_set_direction_mask(gpio_t *dev, uint8_t pin_mask, gpio_direction_t direction)
{
    uint8_t current_dir = gpio_get_direction_all(dev);

    if (direction == GPIO_DIR_OUTPUT)
    {
        current_dir |= pin_mask;   // Set pins as outputs
    }
    else
    {
        current_dir &= ~pin_mask;  // Set pins as inputs
    }

    gpio_set_direction_all(dev, current_dir);
}


void gpio_set_inputs(gpio_t *dev, uint8_t pin_mask)
{
    gpio_set_direction_mask(dev, pin_mask, GPIO_DIR_INPUT);
}


void gpio_set_outputs(gpio_t *dev, uint8_t pin_mask)
{
    gpio_set_direction_mask(dev, pin_mask, GPIO_DIR_OUTPUT);
}


