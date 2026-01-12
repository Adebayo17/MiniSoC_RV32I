/**
 * @file uart_usage.c
 * @brief UART Driver Test with Error Handling
 */

#include "../../include/system.h"
#include "../../include/errors.h"
#include "../../include/memory.h"
#include "../../drivers/uart/include/uart.h"


/**
 * @brief Test UART initialization and configuration
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_uart_init(void)
{
    uart_t uart_dev;
    system_error_t err;
    
    /* Test 1: Invalid parameters */
    err = uart_init(NULL, UART_BASE_ADDRESS);
    if (err != SYSTEM_ERROR_INVALID_PARAM) {
        return SYSTEM_ERROR_HARDWARE;
    }
    
    err = uart_init(&uart_dev, 0xDEADBEEF); /* Invalid address */
    if (err != SYSTEM_ERROR_INVALID_ADDRESS) {
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test 2: Normal initialization */
    err = uart_init(&uart_dev, UART_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Test 3: Double initialization */
    err = uart_init(&uart_dev, UART_BASE_ADDRESS);
    if (err != SYSTEM_ERROR_BUSY) {
        uart_deinit(&uart_dev);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test 4: Configuration */
    uart_config_t config = {
        .baudrate = UART_BAUD_115200,
        .enable_tx = true,
        .enable_rx = true
    };
    
    err = uart_configure(&uart_dev, &config);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Test 5: Get configuration */
    uart_config_t read_config;
    err = uart_get_config(&uart_dev, &read_config);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    if (read_config.baudrate != config.baudrate ||
        read_config.enable_tx != config.enable_tx ||
        read_config.enable_rx != config.enable_rx) {
        uart_deinit(&uart_dev);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Cleanup */
    err = uart_deinit(&uart_dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    return SYSTEM_SUCCESS;
}


/**
 * @brief Test UART transmit functions
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_uart_transmit(void)
{
    uart_t uart_dev;
    system_error_t err;
    
    err = uart_init(&uart_dev, UART_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Enable transmitter */
    err = uart_enable_tx(&uart_dev);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Test single byte transmission */
    err = uart_transmit_byte(&uart_dev, 'A', 100);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Test string transmission */
    err = uart_transmit_string(&uart_dev, "Hello, UART!", 100);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Test data buffer transmission */
    uint8_t data[] = {0x01, 0x02, 0x03, 0x04};
    err = uart_transmit_data(&uart_dev, data, sizeof(data), 100);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Cleanup */
    err = uart_deinit(&uart_dev);
    
    return err;
}


/**
 * @brief Test UART status functions
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_uart_status(void)
{
    uart_t uart_dev;
    system_error_t err;
    
    err = uart_init(&uart_dev, UART_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    bool is_ready;
    
    /* Check transmitter status */
    err = uart_is_tx_ready(&uart_dev, &is_ready);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Check transmitter busy */
    err = uart_is_tx_busy(&uart_dev, &is_ready);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Get full status */
    uart_status_t status;
    err = uart_get_status(&uart_dev, &status);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Clear status */
    err = uart_clear_status(&uart_dev);
    if (IS_ERROR(err)) {
        uart_deinit(&uart_dev);
        return err;
    }
    
    /* Cleanup */
    err = uart_deinit(&uart_dev);
    
    return err;
}


/**
 * @brief Main UART test function
 * @return SYSTEM_SUCCESS if all tests pass, error code otherwise
 */
int main(void)
{
    system_error_t err;
    system_init();
    
    err = test_uart_init();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_uart_transmit();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_uart_status();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    return 0;
}




