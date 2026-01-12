/*
 * @file uart.c
 * @brief UART Driver Implementation
*/

#include "../include/uart.h"
#include "../../../include/system.h"
#include "../../../include/peripheral.h"
#include <stddef.h>


/* ========================================================================== */
/* Private Helper Functions                                                   */
/* ========================================================================== */

/**
 * @brief Wait for transmitter ready with timeout
 * @param dev Pointer to UART structure
 * @param timeout_ms Timeout in milliseconds
 * @return SYSTEM_SUCCESS if ready, error code on timeout or failure
 */
static system_error_t uart_wait_tx_ready(uart_t *dev, uint32_t timeout_ms)
{
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    uint32_t start_time = system_get_ticks();
    bool is_ready = false;
    system_error_t err;
    
    do {
        err = uart_is_tx_ready(dev, &is_ready);
        if (IS_ERROR(err)) {
            return err;
        }
        
        if (is_ready) {
            return SYSTEM_SUCCESS;
        }
        
        /* Small delay to prevent busy-wait CPU hog */
        system_delay_us(10);
        
    } while (timeout_ms == 0 || 
             system_get_elapsed_time_us(start_time) < (timeout_ms * 1000));
    
    return SYSTEM_ERROR_TIMEOUT;
}


/**
 * @brief Wait for receiver ready with timeout
 * @param dev Pointer to UART structure
 * @param timeout_ms Timeout in milliseconds
 * @return SYSTEM_SUCCESS if ready, error code on timeout or failure
 */
static system_error_t uart_wait_rx_ready(uart_t *dev, uint32_t timeout_ms)
{
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    uint32_t start_time = system_get_ticks();
    bool is_ready = false;
    system_error_t err;
    
    do {
        err = uart_is_rx_ready(dev, &is_ready);
        if (IS_ERROR(err)) {
            return err;
        }
        
        if (is_ready) {
            return SYSTEM_SUCCESS;
        }
        
        /* Small delay to prevent busy-wait CPU hog */
        system_delay_us(10);
        
    } while (timeout_ms == 0 || 
             system_get_elapsed_time_us(start_time) < (timeout_ms * 1000));
    
    return SYSTEM_ERROR_TIMEOUT;
}


/**
 * @brief Update UART status from hardware registers
 * @param dev Pointer to UART structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t uart_update_status(uart_t *dev)
{
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    uint32_t status_reg = READ_REG(dev->base.base_address + REG_STATUS_OFFSET);
    
    dev->status.tx_ready = (status_reg & STATUS_TX_EMPTY_BIT) != 0;
    dev->status.tx_busy = (status_reg & STATUS_TX_BUSY_BIT) != 0;
    dev->status.rx_ready = (status_reg & STATUS_RX_READY_BIT) != 0;
    dev->status.rx_overrun = (status_reg & STATUS_RX_OVERRUN_BIT) != 0;
    dev->status.rx_frame_error = (status_reg & STATUS_RX_FRAME_ERR_BIT) != 0;
    
    return SYSTEM_SUCCESS;
}


/* ========================================================================== */
/* Public UART Functions                                                      */
/* ========================================================================== */


system_error_t uart_init(uart_t *dev, uint32_t base_addr)
{
    /* Parameter validation */
    if (dev == NULL)
    {
        return SYSTEM_ERROR_INVALID_PARAM;
    }

    /* Validate base address */
    if (!IS_UART_ADDRESS(base_addr))
    {
        return SYSTEM_ERROR_INVALID_ADDRESS;
    }

    /* Check if already initialized */
    bool is_initialized = false;
    system_error_t err = peripheral_is_initialized(&dev->base, &is_initialized);
    if (IS_ERROR(err))
    {
        return err;
    }

    if (is_initialized)
    {
        return SYSTEM_ERROR_BUSY;
    }

    /* Initialize base peripheral */
    err = peripheral_init(&dev->base, base_addr);
    if (IS_ERROR(err))
    {
        return err;
    }

    /* Initialize UART to known state */
    dev->config.baudrate  = UART_BAUD_115200;
    dev->config.enable_tx = false;
    dev->config.enable_tx = false;
    
    system_memset(&dev->status, 0, sizeof(dev->status));

    /* Disable transmitter and receiver */
    WRITE_REG(dev->base.base_address + REG_CTRL_OFFSET, 0);

    /* SSet default baud rate (115200 @ 100MHz) */
    uint32_t divisor = (SYSTEM_CLOCK_FREQ + UART_BAUD_115200 / 2) / UART_BAUD_115200;
    if (divisor > 0xFFFF)
    {
        divisor = 0xFFFF;
    }
    WRITE_REG(dev->base.base_address + REG_BAUD_DIV_OFFSET, divisor);

    /* Clear any pending status flags */
    (void)READ_REG(dev->base.base_address + REG_STATUS_OFFSET);

    return SYSTEM_SUCCESS;
    
}


system_error_t uart_deinit(uart_t *dev)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Disable UART before deinitialization */
    system_error_t err = uart_disable(dev);
    if (IS_ERROR(err) && err != SYSTEM_ERROR_NOT_READY) {
        /* Continue deinitialization even if disable fails */
    }
    
    /* Deinitialize base peripheral */
    return peripheral_deinit(&dev->base);
}


system_error_t uart_configure(uart_t *dev, const uart_config_t *config)
{
    /* Parameter validation */
    if (dev == NULL || config == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Validate baud rate */
    if (config->baudrate == 0) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Store configuration */
    dev->config = *config;
    
    /* Set baud rate */
    system_error_t err = uart_set_baud_rate(dev, SYSTEM_CLOCK_FREQ, config->baudrate);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Configure transmitter and receiver */
    uint32_t ctrl_reg = 0;
    
    if (config->enable_tx) {
        ctrl_reg |= CTRL_TX_ENABLE_BIT;
    }
    
    if (config->enable_rx) {
        ctrl_reg |= CTRL_RX_ENABLE_BIT;
    }
    
    WRITE_REG(dev->base.base_address + REG_CTRL_OFFSET, ctrl_reg);
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_get_config(uart_t *dev, uart_config_t *config)
{
    /* Parameter validation */
    if (dev == NULL || config == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Copy configuration */
    *config = dev->config;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_set_baud_rate(uart_t *dev, uint32_t clk_freq, uint32_t baudrate)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    if (baudrate == 0) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    if (clk_freq == 0) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Compute divisor (rounded) */
    uint32_t divisor = (clk_freq + baudrate / 2) / baudrate;
    
    if (divisor == 0) {
        divisor = 1; /* Minimum divisor */
    }
    
    if (divisor > 0xFFFF) {
        divisor = 0xFFFF; /* Maximum supported divisor */
    }
    
    /* Update hardware register */
    WRITE_REG(dev->base.base_address + REG_BAUD_DIV_OFFSET, divisor);
    
    /* Update stored configuration */
    dev->config.baudrate = baudrate;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_get_baud_rate(uart_t *dev, uint32_t clk_freq, uint32_t *baudrate)
{
    /* Parameter validation */
    if (dev == NULL || baudrate == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    if (clk_freq == 0) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Read divisor from hardware */
    uint32_t divisor = READ_REG(dev->base.base_address + REG_BAUD_DIV_OFFSET) & 0xFFFF;
    
    if (divisor == 0) {
        *baudrate = 0; /* Invalid configuration */
        return SYSTEM_ERROR_HARDWARE;
    }
    
    *baudrate = clk_freq / divisor;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_enable_tx(uart_t *dev)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Update hardware register */
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_CTRL_OFFSET);
    ctrl_reg |= CTRL_TX_ENABLE_BIT;
    WRITE_REG(dev->base.base_address + REG_CTRL_OFFSET, ctrl_reg);
    
    /* Update configuration */
    dev->config.enable_tx = true;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_disable_tx(uart_t *dev)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Update hardware register */
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_CTRL_OFFSET);
    ctrl_reg &= ~CTRL_TX_ENABLE_BIT;
    WRITE_REG(dev->base.base_address + REG_CTRL_OFFSET, ctrl_reg);
    
    /* Update configuration */
    dev->config.enable_tx = false;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_enable_rx(uart_t *dev)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Update hardware register */
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_CTRL_OFFSET);
    ctrl_reg |= CTRL_RX_ENABLE_BIT;
    WRITE_REG(dev->base.base_address + REG_CTRL_OFFSET, ctrl_reg);
    
    /* Update configuration */
    dev->config.enable_rx = true;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_disable_rx(uart_t *dev)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Update hardware register */
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_CTRL_OFFSET);
    ctrl_reg &= ~CTRL_RX_ENABLE_BIT;
    WRITE_REG(dev->base.base_address + REG_CTRL_OFFSET, ctrl_reg);
    
    /* Update configuration */
    dev->config.enable_rx = false;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_enable(uart_t *dev)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Update hardware register */
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_CTRL_OFFSET);
    ctrl_reg |= (CTRL_TX_ENABLE_BIT | CTRL_RX_ENABLE_BIT);
    WRITE_REG(dev->base.base_address + REG_CTRL_OFFSET, ctrl_reg);
    
    /* Update configuration */
    dev->config.enable_tx = true;
    dev->config.enable_rx = true;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_disable(uart_t *dev)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Update hardware register */
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_CTRL_OFFSET);
    ctrl_reg &= ~(CTRL_TX_ENABLE_BIT | CTRL_RX_ENABLE_BIT);
    WRITE_REG(dev->base.base_address + REG_CTRL_OFFSET, ctrl_reg);
    
    /* Update configuration */
    dev->config.enable_tx = false;
    dev->config.enable_rx = false;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_get_status(uart_t *dev, uart_status_t *status)
{
    /* Parameter validation */
    if (dev == NULL || status == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Update status from hardware */
    system_error_t err = uart_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Copy status */
    *status = dev->status;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_is_tx_ready(uart_t *dev, bool *is_ready)
{
    /* Parameter validation */
    if (dev == NULL || is_ready == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Update status from hardware */
    system_error_t err = uart_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *is_ready = dev->status.tx_ready;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_is_tx_busy(uart_t *dev, bool *is_busy)
{
    /* Parameter validation */
    if (dev == NULL || is_busy == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Update status from hardware */
    system_error_t err = uart_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *is_busy = dev->status.tx_busy;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_is_rx_ready(uart_t *dev, bool *is_ready)
{
    /* Parameter validation */
    if (dev == NULL || is_ready == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Update status from hardware */
    system_error_t err = uart_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Check for errors */
    if (dev->status.rx_overrun) {
        return SYSTEM_ERROR_UART_OVERRUN;
    }
    
    if (dev->status.rx_frame_error) {
        return SYSTEM_ERROR_UART_FRAME;
    }
    
    *is_ready = dev->status.rx_ready;
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_transmit_byte(uart_t *dev, uint8_t data, uint32_t timeout_ms)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Check if transmitter is enabled */
    if (!dev->config.enable_tx) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Wait for transmitter to be ready */
    system_error_t err = uart_wait_tx_ready(dev, timeout_ms);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Write data to transmit register */
    WRITE_REG(dev->base.base_address + REG_TX_DATA_OFFSET, data);
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_receive_byte(uart_t *dev, uint8_t *data, uint32_t timeout_ms)
{
    /* Parameter validation */
    if (dev == NULL || data == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Check if receiver is enabled */
    if (!dev->config.enable_rx) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Wait for receiver to have data */
    system_error_t err = uart_wait_rx_ready(dev, timeout_ms);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Read data from receive register (clears RX_READY flag) */
    *data = (uint8_t)(READ_REG(dev->base.base_address + REG_RX_DATA_OFFSET) & 0xFF);
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_transmit_string(uart_t *dev, const char *str, uint32_t timeout_ms)
{
    /* Parameter validation */
    if (dev == NULL || str == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Check if transmitter is enabled */
    if (!dev->config.enable_tx) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Transmit each character */
    while (*str != '\0') {
        system_error_t err = uart_transmit_byte(dev, *str, timeout_ms);
        if (IS_ERROR(err)) {
            return err;
        }
        str++;
    }
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_transmit_data(uart_t *dev, const uint8_t *data, uint32_t length, uint32_t timeout_ms)
{
    /* Parameter validation */
    if (dev == NULL || data == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Check if transmitter is enabled */
    if (!dev->config.enable_tx) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    if (length == 0) {
        return SYSTEM_SUCCESS; /* Nothing to transmit */
    }
    
    /* Transmit each byte */
    for (uint32_t i = 0; i < length; i++) {
        system_error_t err = uart_transmit_byte(dev, data[i], timeout_ms);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_clear_status(uart_t *dev)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Reading the status register clears some flags */
    (void)READ_REG(dev->base.base_address + REG_STATUS_OFFSET);
    
    /* Clear stored status */
    system_memset(&dev->status, 0, sizeof(dev->status));
    
    return SYSTEM_SUCCESS;
}


system_error_t uart_reset(uart_t *dev)
{
    /* Parameter validation */
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Disable UART */
    WRITE_REG(dev->base.base_address + REG_CTRL_OFFSET, 0);
    
    /* Reset baud rate to default */
    uint32_t divisor = (SYSTEM_CLOCK_FREQ + UART_BAUD_115200 / 2) / UART_BAUD_115200;
    if (divisor > 0xFFFF) {
        divisor = 0xFFFF;
    }
    WRITE_REG(dev->base.base_address + REG_BAUD_DIV_OFFSET, divisor);
    
    /* Clear status */
    (void)READ_REG(dev->base.base_address + REG_STATUS_OFFSET);
    
    /* Reset configuration to defaults */
    dev->config.baudrate = UART_BAUD_115200;
    dev->config.enable_tx = false;
    dev->config.enable_rx = false;
    
    /* Clear status structure */
    system_memset(&dev->status, 0, sizeof(dev->status));
    
    return SYSTEM_SUCCESS;
}