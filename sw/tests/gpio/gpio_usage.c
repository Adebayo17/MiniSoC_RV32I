/**
 * @file    gpio_usage.c
 * @brief   GPIO Driver Test with Error Handling.
 * @details Conforms to the Barr Group Embedded C Coding Standard.
 */

#include "../../include/system.h"
#include "../../include/errors.h"
#include "../../include/memory.h"
#include "../../drivers/gpio/include/gpio.h"
#include "../../drivers/timer/include/timer.h"


/* ========================================================================== */
/* GPIO Test Functions                                                        */
/* ========================================================================== */

/**
 * @brief  Test GPIO initialization and configuration.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_gpio_init(void)
{
    gpio_t gpio_dev;
    system_error_t status = SYSTEM_SUCCESS;
    system_error_t test_err;
    
    /* Test 1: Invalid parameters (NULL pointer) */
    test_err = gpio_init(NULL, GPIO_BASE_ADDRESS);
    if (test_err != SYSTEM_ERROR_INVALID_PARAM) 
    {
        status = SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test 2: Invalid hardware address */
    if (is_success(status))
    {
        test_err = gpio_init(&gpio_dev, 0xDEADBEEFUL); 
        if (test_err != SYSTEM_ERROR_INVALID_ADDRESS) 
        {
            status = SYSTEM_ERROR_HARDWARE;
        }
    }
    
    /* Test 3: Normal initialization */
    if (is_success(status))
    {
        status = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    }
    
    /* Cleanup (Safe to call even if init failed) */
    (void)gpio_deinit(&gpio_dev);
    
    return status;
}


/**
 * @brief  Test GPIO direction control.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_gpio_direction(void)
{
    gpio_t gpio_dev;
    system_error_t status = SYSTEM_SUCCESS;
    
    status = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    
    if (is_success(status)) 
    {
        /* Test setting all pins as inputs */
        status = gpio_set_direction_all(&gpio_dev, 0x00U);
    }
    
    if (is_success(status)) 
    {
        uint8_t direction_mask = 0xFFU;
        status = gpio_get_direction_all(&gpio_dev, &direction_mask);
        
        if (is_success(status) && (direction_mask != 0x00U)) 
        {
            status = SYSTEM_ERROR_HARDWARE;
        }
    }
    
    if (is_success(status)) 
    {
        /* Test setting pin 0 as output */
        status = gpio_set_direction_pin(&gpio_dev, GPIO_PIN_0, GPIO_DIR_OUTPUT);
    }
    
    if (is_success(status)) 
    {
        gpio_direction_t direction;
        status = gpio_get_direction_pin(&gpio_dev, GPIO_PIN_0, &direction);
        
        if (is_success(status) && (direction != GPIO_DIR_OUTPUT)) 
        {
            status = SYSTEM_ERROR_HARDWARE;
        }
    }
    
    if (is_success(status)) 
    {
        /* Test invalid pin */
        system_error_t test_err = gpio_set_direction_pin(&gpio_dev, (gpio_pin_t)10U, GPIO_DIR_OUTPUT);
        
        /* Warning: gpio_validate_pin returns SYSTEM_ERROR_GPIO_INVALID_PIN */
        if (test_err != SYSTEM_ERROR_GPIO_INVALID_PIN) 
        {
            status = SYSTEM_ERROR_HARDWARE;
        }
    }
    
    /* Cleanup */
    (void)gpio_deinit(&gpio_dev);
    
    return status;
}


/**
 * @brief  Test GPIO read/write operations.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_gpio_read_write(void)
{
    gpio_t gpio_dev;
    system_error_t status = SYSTEM_SUCCESS;
    
    status = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    
    if (is_success(status)) 
    {
        /* Configure pin 0 as output */
        status = gpio_set_direction_pin(&gpio_dev, GPIO_PIN_0, GPIO_DIR_OUTPUT);
    }
    
    if (is_success(status)) status = gpio_write_pin(&gpio_dev, GPIO_PIN_0, true);
    if (is_success(status)) status = gpio_write_pin(&gpio_dev, GPIO_PIN_0, false);
    
    /* Test Set/Clear/Toggle operations (Hardware Atomic) */
    if (is_success(status)) status = gpio_set_pin(&gpio_dev, GPIO_PIN_0);
    if (is_success(status)) status = gpio_clear_pin(&gpio_dev, GPIO_PIN_0);
    if (is_success(status)) status = gpio_toggle_pin(&gpio_dev, GPIO_PIN_0);
    
    if (is_success(status)) 
    {
        /* Configure pin 1 as input */
        status = gpio_set_direction_pin(&gpio_dev, GPIO_PIN_1, GPIO_DIR_INPUT);
    }
    
    if (is_success(status)) 
    {
        /* Test reading a single pin */
        bool pin_value = false;
        status = gpio_read_pin(&gpio_dev, GPIO_PIN_1, &pin_value);
    }
    
    if (is_success(status)) 
    {
        /* Test reading all pins */
        uint8_t all_values = 0U;
        status = gpio_read_all(&gpio_dev, &all_values);
    }
    
    /* Cleanup */
    (void)gpio_deinit(&gpio_dev);
    
    return status;
}


/**
 * @brief  Test GPIO LED blinking using the hardware timer.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_gpio_blink(void)
{
    gpio_t gpio_dev;
    timer_t timer_dev;
    system_error_t status = SYSTEM_SUCCESS;
    
    /* Initialize peripherals */
    status = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    
    if (is_success(status)) 
    {
        status = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    }
    
    if (is_success(status)) 
    {
        /* Configure pin 0 as output */
        status = gpio_set_direction_pin(&gpio_dev, GPIO_PIN_0, GPIO_DIR_OUTPUT);
    }
    
    if (is_success(status)) 
    {
        uint32_t i;
        
        /* Blink LED 5 times */
        for (i = 0U; (i < 5U) && is_success(status); i++) 
        {
            status = gpio_toggle_pin(&gpio_dev, GPIO_PIN_0);
            
            if (is_success(status)) 
            {
                status = timer_delay_ms(&timer_dev, 250U);
            }
        }
    }
    
    /* Cleanup */
    (void)timer_deinit(&timer_dev);
    (void)gpio_deinit(&gpio_dev);
    
    return status;
}


/* ========================================================================== */
/* Main Test Runner                                                           */
/* ========================================================================== */

/**
 * @brief  Main GPIO test function.
 * @return 0 if all tests pass, 1 otherwise.
 */
int main(void)
{
    system_error_t status = SYSTEM_SUCCESS;
    int ret_val = 0;
    
    system_init();
    
    /* Run Tests sequentially, stop if one fails */
    status = test_gpio_init();
    
    if (is_success(status)) status = test_gpio_direction();
    if (is_success(status)) status = test_gpio_read_write();
    if (is_success(status)) status = test_gpio_blink();
    
    /* Set return value based on final status */
    if (is_error(status)) 
    {
        ret_val = 1;
    }
    
    return ret_val;
}