/*
 * @file uart.c
 * @brief UART Driver Implementation
*/

#include "../include/uart.h"
#include "uart_hw.h"
#include <stddef.h>


/* ========================================================================== */
/* Private Helper Functions                                                   */
/* ========================================================================== */

/**
 * @brief   Gets the hardware structure (registers) based on the UART handle.
 * @param   [in] dev Pointer to UART structure.
 * @return  Pointer to UART hardware registers, or NULL if invalid handle.
 */
static inline uart_regs_t* uart_get_hw_regs(const uart_t *dev)
{
    /* Base address guaranted to be valid if peripheral_check_valid is a successful call */
    return (uart_regs_t *)(dev->base.base_address);
}


/* ========================================================================== */
/* Public API UART Functions Implementation                                   */
/* ========================================================================== */


system_error_t uart_init(uart_t *dev, uint32_t base_addr)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (dev == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else 
    {
        /* Call to initialize the base class (inheritance) */
        status = peripheral_init(uart_to_peripheral(dev), base_addr);

        if (is_success(status))
        {
            /* Re-initialize the UART to known software state */
            dev->config.baudrate        = UART_BAUD_115200;
            dev->config.enable_tx       = false;
            dev->config.enable_rx       = false;

            dev->status.tx_ready        = false;
            dev->status.tx_busy         = false;
            dev->status.rx_ready        = false;
            dev->status.rx_overrun      = false;
            dev->status.rx_frame_error  = false;

            /* Re-initialize hardware state */
            uart_regs_t *hw = uart_get_hw_regs(dev);
            hw->CTRL    = 0U;                       /* Disable transmitter and receiver */

            /* Clear pending errors using Write-1-to-Clear (W1C) */
            hw->STATUS = (UART_STATUS_RX_OVERRUN_BIT | UART_STATUS_FRAME_ERR_BIT);
            
            /* Read the rx data register to clear any pending data/RX_READY flag */
            (void)hw->RX_DATA;
        }
    }

    return status;
}


system_error_t uart_deinit(uart_t *dev)
{
    system_error_t status = SYSTEM_SUCCESS;

    status = peripheral_check_valid(uart_to_peripheral(dev));

    if (is_success(status))
    {
        /* Hardware deactivation */
        uart_regs_t *hw = uart_get_hw_regs(dev);
        hw->CTRL = 0U;

        /* Software deactivation */
        status = peripheral_deinit(uart_to_peripheral(dev));
    }

    return status;
}


system_error_t uart_configure(uart_t *dev, const uart_config_t *config)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (config == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(uart_to_peripheral(dev));

        if (is_success(status))
        {
            /* Update hardware with system frequency (standard assumption) */
            status = uart_set_baud_rate(dev, SYSTEM_CLOCK_FREQ, config->baudrate);

            if (is_success(status))
            {
                if (config->enable_tx)
                {
                    (void)uart_enable_tx(dev);
                }
                else
                {
                    (void)uart_disable_tx(dev);
                }

                if (config->enable_rx)
                {
                    (void)uart_enable_rx(dev);
                }
                else
                {
                    (void)uart_disable_rx(dev);
                }
            }
        }
    }

    return status;
}


system_error_t uart_get_config(uart_t *dev, uart_config_t *config)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (config == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(uart_to_peripheral(dev));

        if (is_success(status))
        {
            *config = dev->config;
        }
    }

    return status;
}


system_error_t uart_set_baud_rate(uart_t *dev, uint32_t clk_freq, uint32_t baudrate)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((clk_freq == 0U) || (baudrate == 0U))
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(uart_to_peripheral(dev));

        if (is_success(status))
        {
            uart_regs_t *hw = uart_get_hw_regs(dev);
            
            /* Calculate the clock divisor. Note: depends on the exact Verilog implementation.
               Often (clk_freq / baudrate) or (clk_freq / (16 * baudrate))
               Here: (clk_freq / baudrate) */
            uint32_t divider = clk_freq / baudrate;
            
            hw->BAUD_DIV = divider;
            dev->config.baudrate = baudrate;
        }
    }

    return status;
}


system_error_t uart_get_baud_rate(uart_t *dev, uint32_t clk_freq, uint32_t *baudrate)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((clk_freq == 0U) || (baudrate == NULL))
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(uart_to_peripheral(dev));

        if (is_success(status))
        {
            uart_regs_t *hw = uart_get_hw_regs(dev);
            uint32_t divider = hw->BAUD_DIV;

            if (divider > 0U)
            {
                *baudrate = clk_freq / divider;
            }
            else
            {
                *baudrate = 0U; /* Avoid division by zero if not configured */
            }
        }
    }

    return status;
}


system_error_t uart_enable_tx(uart_t *dev)
{
    system_error_t status = peripheral_check_valid(uart_to_peripheral(dev));

    if (is_success(status))
    {
        uart_regs_t *hw = uart_get_hw_regs(dev);
        hw->CTRL |= UART_CTRL_TX_ENABLE_BIT;
        dev->config.enable_tx = true;
    }

    return status;
}


system_error_t uart_disable_tx(uart_t *dev)
{
    system_error_t status = peripheral_check_valid(uart_to_peripheral(dev));

    if (is_success(status))
    {
        uart_regs_t *hw = uart_get_hw_regs(dev);
        hw->CTRL &= ~UART_CTRL_TX_ENABLE_BIT;
        dev->config.enable_tx = false;
    }

    return status;
}


system_error_t uart_enable_rx(uart_t *dev)
{
    system_error_t status = peripheral_check_valid(uart_to_peripheral(dev));

    if (is_success(status))
    {
        uart_regs_t *hw = uart_get_hw_regs(dev);
        hw->CTRL |= UART_CTRL_RX_ENABLE_BIT;
        dev->config.enable_rx = true;
    }

    return status;
}


system_error_t uart_disable_rx(uart_t *dev)
{
    system_error_t status = peripheral_check_valid(uart_to_peripheral(dev));

    if (is_success(status))
    {
        uart_regs_t *hw = uart_get_hw_regs(dev);
        hw->CTRL &= ~UART_CTRL_RX_ENABLE_BIT;
        dev->config.enable_rx = false;
    }

    return status;
}


system_error_t uart_enable(uart_t *dev)
{
    system_error_t status = uart_enable_tx(dev);
    
    if (is_success(status))
    {
        status = uart_enable_rx(dev);
    }

    return status;
}


system_error_t uart_disable(uart_t *dev)
{
    system_error_t status = uart_disable_tx(dev);
    
    if (is_success(status))
    {
        status = uart_disable_rx(dev);
    }

    return status;
}


system_error_t uart_get_status(uart_t *dev, uart_status_t *status_out)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (status_out == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(uart_to_peripheral(dev));

        if (is_success(status))
        {
            uart_regs_t *hw = uart_get_hw_regs(dev);
            uint32_t hw_status = hw->STATUS;

            /* Update software cache */
            dev->status.tx_ready       = ((hw_status & UART_STATUS_TX_EMPTY_BIT)   != 0U);
            dev->status.tx_busy        = ((hw_status & UART_STATUS_TX_BUSY_BIT)    != 0U);
            dev->status.rx_ready       = ((hw_status & UART_STATUS_RX_READY_BIT)   != 0U);
            dev->status.rx_overrun     = ((hw_status & UART_STATUS_RX_OVERRUN_BIT) != 0U);
            dev->status.rx_frame_error = ((hw_status & UART_STATUS_FRAME_ERR_BIT)  != 0U);

            *status_out = dev->status;
        }
    }

    return status;
}


system_error_t uart_is_tx_ready(uart_t *dev, bool *is_ready)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (is_ready == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(uart_to_peripheral(dev));

        if (is_success(status))
        {
            uart_regs_t *hw = uart_get_hw_regs(dev);
            *is_ready = ((hw->STATUS & UART_STATUS_TX_EMPTY_BIT) != 0U);
        }
    }

    return status;
}


system_error_t uart_is_tx_busy(uart_t *dev, bool *is_busy)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (is_busy == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(uart_to_peripheral(dev));

        if (is_success(status))
        {
            uart_regs_t *hw = uart_get_hw_regs(dev);
            *is_busy = ((hw->STATUS & UART_STATUS_TX_BUSY_BIT) != 0U);
        }
    }

    return status;
}


system_error_t uart_is_rx_ready(uart_t *dev, bool *is_ready)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (is_ready == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(uart_to_peripheral(dev));

        if (is_success(status))
        {
            uart_regs_t *hw = uart_get_hw_regs(dev);
            *is_ready = ((hw->STATUS & UART_STATUS_RX_READY_BIT) != 0U);
        }
    }

    return status;
}


system_error_t uart_transmit_byte(uart_t *dev, uint8_t data, uint32_t timeout_us)
{
    system_error_t status = peripheral_check_valid(uart_to_peripheral(dev));

    if (is_success(status))
    {
        if (!(dev->config.enable_tx))
        {
            status = SYSTEM_ERROR_NOT_READY;
        }
        else
        {
            uart_regs_t *hw         = uart_get_hw_regs(dev);
            uint32_t start_time     = 0U;
            uint32_t current_time   = 0U;
            bool is_ready           = false;

            /* Gets initial time for timeout */
            if (timeout_us > 0U)
            {
                (void)system_get_time_us_safe(&start_time);
            }

            /* Pooling loop to wait until TX buffer is empty */
            while (!is_ready)
            {
                if ((hw->STATUS & UART_STATUS_TX_EMPTY_BIT) != 0U)
                {
                    is_ready = true;
                    hw->TX_DATA = (uint32_t)data; /* Send the character */
                }
                else if (timeout_us > 0U)
                {
                    (void)system_get_time_us_safe(&current_time);
                    
                    /* Basic time elapsed handling (supports wrap-around) */
                    uint32_t elapsed = (current_time >= start_time) ? 
                                       (current_time - start_time) : 
                                       ((UINT32_MAX - start_time) + current_time + 1U);

                    if (elapsed >= timeout_us)
                    {
                        status = SYSTEM_ERROR_TIMEOUT;
                        break;
                    }
                }
                else
                {
                    /* If timeout_us == 0, pool indefinitely (not recommended but possible) */
                }
            }
        }
    }

    return status;
}


system_error_t uart_receive_byte(uart_t *dev, uint8_t *data, uint32_t timeout_us)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (data == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(uart_to_peripheral(dev));

        if (is_success(status))
        {
            if (!(dev->config.enable_rx))
            {
                status = SYSTEM_ERROR_NOT_READY;
            }
            else
            {
                uart_regs_t *hw         = uart_get_hw_regs(dev);
                uint32_t start_time     = 0U;
                uint32_t current_time   = 0U;
                bool is_ready           = false;

                if (timeout_us > 0U)
                {
                    (void)system_get_time_us_safe(&start_time);
                }

                while (!is_ready)
                {
                    uint32_t hw_status = hw->STATUS;

                    /* Check for hardware errors first */
                    if ((hw_status & UART_STATUS_RX_OVERRUN_BIT) != 0U)
                    {
                        status = SYSTEM_ERROR_UART_OVERRUN;
                        break;
                    }
                    if ((hw_status & UART_STATUS_FRAME_ERR_BIT) != 0U)
                    {
                        status = SYSTEM_ERROR_UART_FRAME;
                        break;
                    }

                    /* Check if data is available */
                    if ((hw_status & UART_STATUS_RX_READY_BIT) != 0U)
                    {
                        is_ready = true;
                        *data = (uint8_t)(hw->RX_DATA & 0xFFU); /* Read the character */
                    }
                    else if (timeout_us > 0U)
                    {
                        (void)system_get_time_us_safe(&current_time);
                        uint32_t elapsed = (current_time >= start_time) ? 
                                           (current_time - start_time) : 
                                           ((UINT32_MAX - start_time) + current_time + 1U);

                        if (elapsed >= timeout_us)
                        {
                            status = SYSTEM_ERROR_TIMEOUT;
                            break;
                        }
                    }
                    else
                    {
                        /* Polling infini */
                    }
                }
            }
        }
    }

    return status;
}


system_error_t uart_transmit_string(uart_t *dev, const char *str, uint32_t timeout_us)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (str == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        uint32_t i = 0U;
        
        while (str[i] != '\0')
        {
            status = uart_transmit_byte(dev, (uint8_t)str[i], timeout_us);
            
            if (is_error(status))
            {
                /* Error: Early termination due to error (e.g., Timeout) */
                break;
            }
            i++;
        }
    }

    return status;
}


system_error_t uart_transmit_data(uart_t *dev, const uint8_t *data, uint32_t length, uint32_t timeout_us)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((data == NULL) && (length > 0U))
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        uint32_t i;

        for (i = 0U; i < length; i++)
        {
            status = uart_transmit_byte(dev, data[i], timeout_us);

            if (is_error(status))
            {
                break;
            }
        }
    }

    return status;
}


system_error_t uart_clear_status(uart_t *dev)
{
    system_error_t status = peripheral_check_valid(uart_to_peripheral(dev));

    if (is_success(status))
    {
        uart_regs_t *hw = uart_get_hw_regs(dev);
        
        /* Clean hardware errors using Write-1-to-Clear (W1C).
           Writing a 1 to the error bits clears them in the hardware. */
        hw->STATUS = (UART_STATUS_RX_OVERRUN_BIT | UART_STATUS_FRAME_ERR_BIT);

        dev->status.rx_overrun      = false;
        dev->status.rx_frame_error  = false;
    }

    return status;
}


system_error_t uart_reset(uart_t *dev)
{
    system_error_t status = peripheral_check_valid(uart_to_peripheral(dev));

    if (is_success(status))
    {
        /* Deactivation */
        (void)uart_disable(dev);

        /* Complete register re-initialization */
        uart_regs_t *hw = uart_get_hw_regs(dev);
        hw->BAUD_DIV    = 0U;
        hw->CTRL        = 0U;

        /* Clear status errors (W1C) and empty RX data register */
        hw->STATUS = (UART_STATUS_RX_OVERRUN_BIT | UART_STATUS_FRAME_ERR_BIT);
        (void)hw->RX_DATA;

        /* Reset software states */
        dev->config.baudrate        = 0U;
        dev->config.enable_tx       = false;
        dev->config.enable_rx       = false;

        dev->status.tx_ready        = false;
        dev->status.tx_busy         = false;
        dev->status.rx_ready        = false;
        dev->status.rx_overrun      = false;
        dev->status.rx_frame_error  = false;
    }

    return status;
}