/**
 * @file    uart_usage.c
 * @brief   UART Driver Test with Error Handling.
 * @details Conforms to the Barr Group Embedded C Coding Standard. 
 */

#include "../../include/system.h"
#include "../../include/errors.h"
#include "../../include/memory.h"
#include "../../drivers/uart/include/uart.h"


/* ========================================================================== */
/* UART Test Functions                                                        */
/* ========================================================================== */

/**
 * @brief  Test UART initialization and configuration.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_uart_init(void)
{
    uart_t uart_dev;
    system_error_t status = SYSTEM_SUCCESS;
    system_error_t test_err;
    
    /* Test 1: Invalid parameters (NULL pointer) */
    test_err = uart_init(NULL, UART_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (test_err != SYSTEM_ERROR_INVALID_PARAM) 
    {
        status = SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test 2: Invalid hardware address */
    if (is_success(status))
    {
        test_err = uart_init(&uart_dev, 0xDEADBEEFUL, SYSTEM_CLOCK_FREQ); 
        if (test_err != SYSTEM_ERROR_INVALID_ADDRESS) 
        {
            status = SYSTEM_ERROR_HARDWARE;
        }
    }
    
    /* Test 3: Normal initialization */
    if (is_success(status))
    {
        status = uart_init(&uart_dev, UART_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    }
    
    /* Test 4: Configuration */
    if (is_success(status))
    {
        uart_config_t config;
        config.baudrate  = UART_BAUD_115200;
        config.enable_tx = true;
        config.enable_rx = true;
        
        status = uart_configure(&uart_dev, &config);
        
        /* Test 5: Configuration Readback */
        if (is_success(status))
        {
            uart_config_t read_config;
            status = uart_get_config(&uart_dev, &read_config);
            
            if (is_success(status))
            {
                if ((read_config.baudrate != config.baudrate) ||
                    (read_config.enable_tx != config.enable_tx) ||
                    (read_config.enable_rx != config.enable_rx)) 
                {
                    status = SYSTEM_ERROR_HARDWARE;
                }
            }
        }
    }
    
    /* Cleanup (Safe to call even if init failed) */
    (void)uart_deinit(&uart_dev);
    
    return status;
}

/**
 * @brief  Test UART transmit functions.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_uart_transmit(void)
{
    uart_t uart_dev;
    system_error_t status = SYSTEM_SUCCESS;
    
    status = uart_init(&uart_dev, UART_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    
    if (is_success(status)) 
    {
        /* Enable transmitter */
        status = uart_enable_tx(&uart_dev);
    }
    
    if (is_success(status)) 
    {
        /* Test single byte transmission (1000us timeout per byte) */
        status = uart_transmit_byte(&uart_dev, (uint8_t)'A', 1000U);
    }
    
    if (is_success(status)) 
    {
        /* Test string transmission */
        status = uart_transmit_string(&uart_dev, "Hello, UART!\r\n", 1000U);
    }
    
    if (is_success(status)) 
    {
        /* Test data buffer transmission */
        uint8_t data[] = {0x01U, 0x02U, 0x03U, 0x04U};
        status = uart_transmit_data(&uart_dev, data, 4U, 1000U);
    }
    
    /* Cleanup */
    (void)uart_deinit(&uart_dev);
    
    return status;
}


/**
 * @brief  Test UART status functions.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_uart_status(void)
{
    uart_t uart_dev;
    system_error_t status = SYSTEM_SUCCESS;
    bool is_ready = false;
    uart_status_t uart_stat;
    
    status = uart_init(&uart_dev, UART_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    
    if (is_success(status)) 
    {
        /* Check transmitter status */
        status = uart_is_tx_ready(&uart_dev, &is_ready);
    }
    
    if (is_success(status)) 
    {
        /* Check transmitter busy */
        status = uart_is_tx_busy(&uart_dev, &is_ready);
    }
    
    if (is_success(status)) 
    {
        /* Get full status */
        status = uart_get_status(&uart_dev, &uart_stat);
    }
    
    if (is_success(status)) 
    {
        /* Clear status */
        status = uart_clear_status(&uart_dev);
    }
    
    /* Cleanup */
    (void)uart_deinit(&uart_dev);
    
    return status;
}

/* ========================================================================== */
/* Main Test Runner                                                           */
/* ========================================================================== */

/**
 * @brief  Main UART test function.
 * @return 0 if all tests pass, 1 otherwise.
 */
int main(void)
{
    system_error_t status = SYSTEM_SUCCESS;
    int ret_val = 0;
    
    system_init();
    
    /* Run Tests sequentially, stop if one fails */
    status = test_uart_init();
    
    if (is_success(status)) 
    {
        status = test_uart_transmit();
    }
    
    if (is_success(status)) 
    {
        status = test_uart_status();
    }
    
    /* Set return value based on final status */
    if (is_error(status)) 
    {
        ret_val = 1;
    }
    
    return ret_val;
}



