/**
 * @file integration_test.c
 * @brief Integration Test for All Peripherals
 */

#include "../include/system.h"
#include "../include/errors.h"
#include "../include/memory.h"
#include "../drivers/uart/include/uart.h"
#include "../drivers/gpio/include/gpio.h"
#include "../drivers/timer/include/timer.h"

/**
 * @brief Test all peripherals working together
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_peripheral_integration(void)
{
    uart_t uart_dev;
    gpio_t gpio_dev;
    timer_t timer_dev;
    system_error_t err;
    
    /* Initialize all peripherals */
    err = uart_init(&uart_dev, UART_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    err = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    err = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio_dev);
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Configure UART */
    uart_config_t uart_config = {
        .baudrate = UART_BAUD_115200,
        .enable_tx = true,
        .enable_rx = false
    };
    
    err = uart_configure(&uart_dev, &uart_config);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    /* Configure GPIO */
    gpio_pin_config_t led_config = {
        .pin = GPIO_PIN_0,
        .direction = GPIO_DIR_OUTPUT,
        .initial_value = false
    };
    
    err = gpio_configure_pin(&gpio_dev, &led_config);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    /* Send start message */
    err = uart_transmit_string(&uart_dev, "Integration Test Started\r\n", 100);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    /* Perform integrated test: Blink LED and send status */
    for (int i = 0; i < 5; i++) {
        /* Toggle LED */
        err = gpio_toggle_pin(&gpio_dev, GPIO_PIN_0);
        if (IS_ERROR(err)) {
            break;
        }
        
        /* Send status over UART */
        char message[32];
        int len = 0;
        
        if (i % 2 == 0) {
            len = sizeof("LED ON\r\n") - 1;
            system_memcpy(message, "LED ON\r\n", len);
        } else {
            len = sizeof("LED OFF\r\n") - 1;
            system_memcpy(message, "LED OFF\r\n", len);
        }
        
        err = uart_transmit_data(&uart_dev, (uint8_t*)message, len, 100);
        if (IS_ERROR(err)) {
            break;
        }
        
        /* Delay using timer */
        err = timer_delay_ms(&timer_dev, 500);
        if (IS_ERROR(err)) {
            break;
        }
    }
    
    /* Send completion message */
    err = uart_transmit_string(&uart_dev, "Integration Test Completed\r\n", 100);
    

cleanup:
    /* Cleanup all peripherals */
    timer_deinit(&timer_dev);
    gpio_deinit(&gpio_dev);
    uart_deinit(&uart_dev);
    
    return err;
}


/**
 * @brief Test memory functions with peripherals
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_memory_integration(void)
{
    uart_t uart_dev;
    system_error_t err;
    
    err = uart_init(&uart_dev, UART_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Configure UART */
    uart_config_t uart_config = {
        .baudrate = UART_BAUD_115200,
        .enable_tx = true,
        .enable_rx = false
    };
    
    err = uart_configure(&uart_dev, &uart_config);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Test memory operations */
    uint8_t buffer1[64];
    uint8_t buffer2[64];
    
    /* Test memset */
    err = system_memset_safe(buffer1, 0xAA, sizeof(buffer1), NULL);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Test memcpy */
    err = system_memcpy_safe(buffer2, buffer1, sizeof(buffer1), NULL);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Test memcmp */
    int cmp_result;
    err = system_memcmp_safe(buffer1, buffer2, sizeof(buffer1), &cmp_result);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    if (cmp_result != 0) {
        uart_deinit(&uart_dev);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Send success message */
    err = uart_transmit_string(&uart_dev, "Memory Test Passed\r\n", 100);
    
    uart_deinit(&uart_dev);
    return err;
}


/**
 * @brief Test error handling
 * @return SYSTEM_SUCCESS if errors are properly handled
 */
system_error_t test_error_handling(void)
{
    system_error_t err;
    
    /* Test invalid peripheral access */
    err = system_write_word_safe(0xDEADBEEF, 0x12345678);
    if (err != SYSTEM_ERROR_INVALID_ADDRESS) {
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test invalid parameter */
    uint32_t value;
    err = system_read_word_safe(DMEM_BASE_ADDRESS, NULL);
    if (err != SYSTEM_ERROR_INVALID_PARAM) {
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test busy condition */
    uart_t uart_dev1, uart_dev2;
    
    err = uart_init(&uart_dev1, UART_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    err = uart_init(&uart_dev2, UART_BASE_ADDRESS);
    if (err != SYSTEM_ERROR_BUSY) {
        uart_deinit(&uart_dev1);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    uart_deinit(&uart_dev1);
    
    return SYSTEM_SUCCESS;
}


/**
 * @brief Main integration test function
 * @return 0 if all tests pass, 1 otherwise
 */
int main(void)
{
    system_error_t err;
    system_init();
    
    err = test_peripheral_integration();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_memory_integration();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_error_handling();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    return 0;
}

