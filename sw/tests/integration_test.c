/**
 * @file    integration_test.c
 * @brief   Integration Test for All Peripherals.
 * @details Conforms to the Barr Group Embedded C Coding Standard.
 */

#include "../include/system.h"
#include "../include/errors.h"
#include "../include/memory.h"
#include "../drivers/uart/include/uart.h"
#include "../drivers/gpio/include/gpio.h"
#include "../drivers/timer/include/timer.h"


/* ========================================================================== */
/* Integration Test Functions                                                 */
/* ========================================================================== */

/**
 * @brief  Test all peripherals working together.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_peripheral_integration(void)
{
    uart_t uart_dev;
    gpio_t gpio_dev;
    timer_t timer_dev;
    system_error_t status = SYSTEM_SUCCESS;
    
    /* Initialize all peripherals */
    status = uart_init(&uart_dev, UART_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (is_success(status)) status = gpio_init(&gpio_dev, GPIO_BASE_ADDRESS);
    if (is_success(status)) status = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    
    /* Configure UART */
    if (is_success(status)) 
    {
        uart_config_t uart_config;
        uart_config.baudrate  = UART_BAUD_115200;
        uart_config.enable_tx = true;
        uart_config.enable_rx = false;
        
        status = uart_configure(&uart_dev, &uart_config);
    }
    
    /* Configure GPIO */
    if (is_success(status)) 
    {
        gpio_pin_config_t led_config;
        led_config.pin           = GPIO_PIN_0;
        led_config.direction     = GPIO_DIR_OUTPUT;
        led_config.initial_value = false;
        
        status = gpio_configure_pin(&gpio_dev, &led_config);
    }
    
    /* Send start message */
    if (is_success(status)) 
    {
        status = uart_transmit_string(&uart_dev, "Integration Test Started\r\n", 1000U);
    }
    
    /* Perform integrated test: Blink LED and send status */
    if (is_success(status)) 
    {
        uint32_t i;
        for (i = 0U; (i < 5U) && is_success(status); i++) 
        {
            /* Toggle LED */
            status = gpio_toggle_pin(&gpio_dev, GPIO_PIN_0);
            
            /* Send status over UART */
            if (is_success(status)) 
            {
                if ((i & 1U) == 0U) 
                {
                    status = uart_transmit_string(&uart_dev, "LED ON\r\n", 1000U);
                } 
                else 
                {
                    status = uart_transmit_string(&uart_dev, "LED OFF\r\n", 1000U);
                }
            }
            
            /* Delay using timer */
            if (is_success(status)) 
            {
                status = timer_delay_ms(&timer_dev, 500U);
            }
        }
    }
    
    /* Send completion message */
    if (is_success(status)) 
    {
        status = uart_transmit_string(&uart_dev, "Integration Test Completed\r\n", 1000U);
    }

    /* Cleanup all peripherals (Safe to call even if an error occurred midway) */
    (void)timer_deinit(&timer_dev);
    (void)gpio_deinit(&gpio_dev);
    (void)uart_deinit(&uart_dev);
    
    return status;
}


/**
 * @brief  Test memory functions with peripherals.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_memory_integration(void)
{
    uart_t uart_dev;
    system_error_t status = SYSTEM_SUCCESS;
    
    status = uart_init(&uart_dev, UART_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    
    /* Configure UART */
    if (is_success(status)) 
    {
        uart_config_t uart_config;
        uart_config.baudrate  = UART_BAUD_115200;
        uart_config.enable_tx = true;
        uart_config.enable_rx = false;
        
        status = uart_configure(&uart_dev, &uart_config);
    }
    
    /* Test memory operations */
    if (is_success(status)) 
    {
        uint8_t buffer1[64];
        uint8_t buffer2[64];
        int cmp_result = -1;
        
        /* Test memset */
        status = system_memset_safe(buffer1, 0xAAU, sizeof(buffer1), NULL);
        
        /* Test memcpy */
        if (is_success(status)) 
        {
            status = system_memcpy_safe(buffer2, buffer1, sizeof(buffer1), NULL);
        }
        
        /* Test memcmp */
        if (is_success(status)) 
        {
            status = system_memcmp_safe(buffer1, buffer2, sizeof(buffer1), &cmp_result);
        }
        
        /* Verify result */
        if (is_success(status) && (cmp_result != 0)) 
        {
            status = SYSTEM_ERROR_HARDWARE;
        }
    }
    
    /* Send success message */
    if (is_success(status)) 
    {
        status = uart_transmit_string(&uart_dev, "Memory Test Passed\r\n", 1000U);
    }
    
    (void)uart_deinit(&uart_dev);
    return status;
}


/**
 * @brief  Test error handling mechanisms.
 * @return SYSTEM_SUCCESS if errors are properly handled.
 */
system_error_t test_error_handling(void)
{
    system_error_t status = SYSTEM_SUCCESS;
    system_error_t test_err;
    
    /* Test 1: Invalid peripheral access (Out of bounds) */
    test_err = system_write_word_safe(0xDEADBEEFUL, 0x12345678UL);
    if (test_err != SYSTEM_ERROR_INVALID_ADDRESS) 
    {
        status = SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test 2: Invalid parameter (NULL pointer) */
    if (is_success(status))
    {
        test_err = system_read_word_safe(DMEM_BASE_ADDRESS, NULL);
        if (test_err != SYSTEM_ERROR_INVALID_PARAM) 
        {
            status = SYSTEM_ERROR_HARDWARE;
        }
    }
    
    /* Test 3: Hardware misalignment detection (Reading Word on non-4-byte boundary) */
    if (is_success(status))
    {
        uint32_t dummy_val;
        test_err = system_read_word_safe(DMEM_BASE_ADDRESS + 1U, &dummy_val);
        if (test_err != SYSTEM_ERROR_MEMORY_ACCESS) 
        {
            status = SYSTEM_ERROR_HARDWARE;
        }
    }
    
    return status;
}


/* ========================================================================== */
/* Main Test Runner                                                           */
/* ========================================================================== */

/**
 * @brief  Main integration test function.
 * @return 0 if all tests pass, 1 otherwise.
 */
int main(void)
{
    system_error_t status = SYSTEM_SUCCESS;
    int ret_val = 0;
    
    system_init();
    
    /* Run Tests sequentially, stop if one fails */
    status = test_peripheral_integration();
    
    if (is_success(status)) status = test_memory_integration();
    if (is_success(status)) status = test_error_handling();
    
    /* Set return value based on final status */
    if (is_error(status)) 
    {
        ret_val = 1;
    }
    
    return ret_val;
}