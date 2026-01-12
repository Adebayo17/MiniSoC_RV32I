/**
 * @file gpio_usage.c
 * @brief GPIO Driver Test with Error Handling
 */

#include "../../include/system.h"
#include "../../include/errors.h"
#include "../../include/memory.h"
#include "../../drivers/gpio/include/gpio.h"
#include "../../drivers/timer/include/timer.h"


/**
 * @brief Test GPIO initialization and configuration
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_gpio_init(void)
{
    gpio_t gpio_dev;
    system_error_t err;
    
    /* Test 1: Invalid parameters */
    err = gpio_init(NULL, GPIO_BASE_ADDRESS);
    if (err != SYSTEM_ERROR_INVALID_PARAM) {
        return SYSTEM_ERROR_HARDWARE;
    }
    
    err = gpio_init(&gpio_dev, 0xDEADBEEF); /* Invalid address */
    if (err != SYSTEM_ERROR_INVALID_ADDRESS) {
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test 2: Normal initialization */
    err = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Test 3: Double initialization */
    err = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    if (err != SYSTEM_ERROR_BUSY) {
        gpio_deinit(&gpio_dev);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Cleanup */
    err = gpio_deinit(&gpio_dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    return SYSTEM_SUCCESS;
}


/**
 * @brief Test GPIO direction control
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_gpio_direction(void)
{
    gpio_t gpio_dev;
    system_error_t err;
    
    err = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Test setting all pins as inputs */
    err = gpio_set_direction_all(&gpio_dev, 0x00);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    uint8_t direction_mask;
    err = gpio_get_direction_all(&gpio_dev, &direction_mask);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    if (direction_mask != 0x00) {
        gpio_deinit(&gpio_dev);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test setting pin 0 as output */
    err = gpio_set_direction_pin(&gpio_dev, GPIO_PIN_0, GPIO_DIR_OUTPUT);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    gpio_direction_t direction;
    err = gpio_get_direction_pin(&gpio_dev, GPIO_PIN_0, &direction);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    if (direction != GPIO_DIR_OUTPUT) {
        gpio_deinit(&gpio_dev);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test invalid pin */
    err = gpio_set_direction_pin(&gpio_dev, (gpio_pin_t)10, GPIO_DIR_OUTPUT);
    if (err != SYSTEM_ERROR_INVALID_PARAM) {
        gpio_deinit(&gpio_dev);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Cleanup */
    err = gpio_deinit(&gpio_dev);
    
    return err;
}


/**
 * @brief Test GPIO read/write operations
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_gpio_read_write(void)
{
    gpio_t gpio_dev;
    system_error_t err;
    
    err = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Configure pin 0 as output */
    err = gpio_set_direction_pin(&gpio_dev, GPIO_PIN_0, GPIO_DIR_OUTPUT);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    /* Test writing HIGH */
    err = gpio_write_pin(&gpio_dev, GPIO_PIN_0, true);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    /* Test writing LOW */
    err = gpio_write_pin(&gpio_dev, GPIO_PIN_0, false);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    /* Test set/clear/toggle operations */
    err = gpio_set_pin(&gpio_dev, GPIO_PIN_0);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    err = gpio_clear_pin(&gpio_dev, GPIO_PIN_0);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    err = gpio_toggle_pin(&gpio_dev, GPIO_PIN_0);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    /* Configure pin 1 as input */
    err = gpio_set_direction_pin(&gpio_dev, GPIO_PIN_1, GPIO_DIR_INPUT);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    /* Test reading pin */
    bool pin_value;
    err = gpio_read_pin(&gpio_dev, GPIO_PIN_1, &pin_value);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    /* Test reading all pins */
    uint8_t all_values;
    err = gpio_read_all(&gpio_dev, &all_values);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    /* Cleanup */
    err = gpio_deinit(&gpio_dev);
    
    return err;
}


/**
 * @brief Test GPIO LED blinking
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_gpio_blink(void)
{
    gpio_t gpio_dev;
    timer_t timer_dev;
    system_error_t err;
    
    /* Initialize peripherals */
    err = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    err = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    /* Configure pin 0 as output */
    err = gpio_set_direction_pin(&gpio_dev, GPIO_PIN_0, GPIO_DIR_OUTPUT);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        gpio_deinit(&gpio_dev);
        return err;
    }
    
    /* Blink LED 5 times */
    for (int i = 0; i < 5; i++) {
        err = gpio_toggle_pin(&gpio_dev, GPIO_PIN_0);
        if (IS_ERROR(err)) {
            break;
        }
        
        err = timer_delay_ms(&timer_dev, 250);
        if (IS_ERROR(err)) {
            break;
        }
    }
    
    /* Cleanup */
    timer_deinit(&timer_dev);
    err = gpio_deinit(&gpio_dev);
    
    return err;
}


/**
 * @brief Main GPIO test function
 * @return SYSTEM_SUCCESS if all tests pass, error code otherwise
 */
int main(void)
{
    system_error_t err;
    system_init();
    
    err = test_gpio_init();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_gpio_direction();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_gpio_read_write();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_gpio_blink();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    return 0;
}


