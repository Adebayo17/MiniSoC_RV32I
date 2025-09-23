/*
 * @file uart.c
 * @brief UART Driver Implementation
*/

#include "uart.h"
#include <stddef.h>


void uart_init(uart_t *dev, uint32_t base_addr)
{
    dev->base_addr = base_addr;

    /* Initialize uart to know state*/
    uart_disable_tx(dev);
    uart_disable_rx(dev);

    /* Set default baud rate (115200 @ 12MHz)*/
    uart_set_baud_divisor(dev, 104);

    /* Clear any pending flags */
    uart_clear_status(dev);
}


void uart_set_baud_divisor(uart_t *dev, uint16_t divisor)
{
    WRITE_REG(dev->base_addr + REG_BAUD_DIV_OFFSET, divisor);
}


uint16_t uart_get_baud_divisor(uart_t *dev)
{
    return (uint16_t)(READ_REG(dev->base_addr + REG_BAUD_DIV_OFFSET) && BAUD_DIV_MASK);
}


void uart_enable_tx(uart_t *dev)
{
    uint32_t reg = READ_REG(dev->base_addr + REG_CTRL_OFFSET);
    reg |= CTRL_TX_ENABLE_BIT;
    WRITE_REG(dev->base_addr + REG_CTRL_OFFSET, reg);
}


void uart_disable_tx(uart_t *dev)
{
    uint32_t reg = READ_REG(dev->base_addr + REG_CTRL_OFFSET);
    reg &= ~CTRL_TX_ENABLE_BIT;
    WRITE_REG(dev->base_addr + REG_CTRL_OFFSET, reg);
}


void uart_enable_rx(uart_t *dev)
{
    uint32_t reg = READ_REG(dev->base_addr + REG_CTRL_OFFSET);
    reg |= CTRL_RX_ENABLE_BIT;
    WRITE_REG(dev->base_addr + REG_CTRL_OFFSET, reg);
}


void uart_disable_rx(uart_t *dev)
{
    uint32_t reg = READ_REG(dev->base_addr + REG_CTRL_OFFSET);
    reg &= ~CTRL_RX_ENABLE_BIT;
    WRITE_REG(dev->base_addr + REG_CTRL_OFFSET, reg);
}


bool uart_tx_ready(uart_t *dev)
{
    uint32_t status = READ_REG(dev->base_addr + REG_STATUS_OFFSET);
    return (status & STATUS_TX_EMPTY_BIT) != 0;
}


bool uart_tx_busy(uart_t *dev)
{
    uint32_t status = READ_REG(dev->base_addr + REG_STATUS_OFFSET);
    return (status & STATUS_TX_BUSY_BIT) != 0;
}


bool uart_rx_ready(uart_t *dev)
{
    uint32_t status = READ_REG(dev->base_addr + REG_STATUS_OFFSET);
    return (status & STATUS_RX_READY_BIT) != 0;
}


bool uart_rx_overrun(uart_t *dev)
{
    uint32_t status = READ_REG(dev->base_addr + REG_STATUS_OFFSET);
    return (status & STATUS_RX_OVERRUN_BIT) != 0;
}


bool uart_rx_frame_error(uart_t *dev)
{
    uint32_t status = READ_REG(dev->base_addr + REG_STATUS_OFFSET);
    return (status & STATUS_RX_FRAME_ERR_BIT) != 0;
}


bool uart_transmit_byte(uart_t *dev, uint8_t data)
{
    /* Check if transmitter is busy */
    if (!uart_tx_ready(dev)) {
        return false;
    }

    /* Write data to transmit register */
    WRITE_REG(dev->base_addr + REG_TX_DATA_OFFSET, data);
    return true;
}


bool uart_receive_byte(uart_t *dev, uint8_t *data)
{
    /* Check if data is available */
    if (!uart_rx_ready(dev)) {
        return false;
    }

    /* Read data from receive register (clears RX_READY flag) */
    *data = (uint8_t)(READ_REG(dev->base_addr + REG_TX_DATA_OFFSET) && RX_DATA_MASK);
    return true;
}


void uart_transmit_string(uart_t *dev, const char *str)
{
    if (str == NULL) {
        return;
    }

    /* Enable transmitter if not already enabled*/
    uart_enable_tx(dev);

    /* Transmit each character */
    while (*str != '\0') {
        /* Wait until transmitter is ready */
        while (!uart_tx_ready(dev)) {
            /* Busy wait */
        }

        /* Transmit character */
        WRITE_REG(dev->base_addr + REG_TX_DATA_OFFSET, *str);
        str++;
    }
}


void uart_transmit_data(uart_t *dev, const uint8_t *str, uint32_t length)
{
    if (data == NULL || length == 0) {
        return;
    }

    /* Enable transmitter if not already enabled*/
    uart_enable_tx(dev);

    /* Transmit each byte */
    for (uint32_t i = 0; i < length; i = i + 1) {
        /* Wait until transmitter is ready */
        while (!uart_tx_ready(dev)) {
            /* Busy wait */
        }

        /* Transmit byte */
        WRITE_REG(dev->base_addr + REG_TX_DATA_OFFSET, data[i]);
    }
}


void uart_clear_status(uart_t *dev)
{
    /* Reading the status register might clear some flags */
    /* For this UART design, overrun and frame errors might need explicit clearing */
    /* This would be implementation-specific */
    (void)(READ_REG(dev->base_addr + REG_STATUS_OFFSET));
}



