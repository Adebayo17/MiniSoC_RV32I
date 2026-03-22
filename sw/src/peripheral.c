/**
 * @file    peripheral.c
 * @brief   Implementation of generic peripheral management functions.
 * @details Conforms to Barr Group Embedded C Coding Standard.
 */

#include "peripheral.h"
#include <stddef.h>


/* ========================================================================== */
/* Functions Implementation                                                   */
/* ========================================================================== */

system_error_t peripheral_init(peripheral_t *dev, uint32_t base_addr)
{
    
    system_error_t status = SYSTEM_SUCCESS;
    
    if (dev == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM; 
    }
    else if (!is_peripheral_address(base_addr))
    {
        status = SYSTEM_ERROR_INVALID_ADDRESS;
    }
    else if (dev->initialized)
    {
        status = SYSTEM_ERROR_BUSY;
    }
    else
    {
        /* Initiaize structure */
        dev->base_address = base_addr;
        dev->initialized  = true;    
    }

    return status;    
}


system_error_t peripheral_deinit(peripheral_t *dev)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (dev == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        dev->base_address = 0U;
        dev->initialized  = false;
    }

    return status;
}


system_error_t peripheral_get_base_address(const peripheral_t *dev, uint32_t *base_addr)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((dev == NULL) || (base_addr == NULL))
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else if (!(dev->initialized))
    {
        status = SYSTEM_ERROR_NOT_READY;
    }
    else
    {
        *base_addr = dev->base_address;
    }

    return status;
}


system_error_t peripheral_is_initialized(const peripheral_t *dev, bool *is_initialized)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((dev == NULL) || (is_initialized == NULL))
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        *is_initialized = dev->initialized;
    }

    return status;
}


system_error_t peripheral_validate_address(const peripheral_t *dev, uint32_t offset, bool *is_valid)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((dev == NULL) || (is_valid == NULL))
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else if (!(dev->initialized))
    {
        status = SYSTEM_ERROR_NOT_READY;
    }
    else
    {
        /* In our architecture (system.h), each peripheral has 4 KB (PERIPH_SIZE) */
        if (offset < PERIPH_SIZE)
        {
            *is_valid = true;
        }
        else
        {
            *is_valid = false;
        }
    }

    return status;
}


system_error_t peripheral_reset(peripheral_t *dev)
{
    system_error_t status = SYSTEM_SUCCESS;

    /* Using the inline function defined in peripheral.h */
    status = peripheral_check_valid(dev);

    if (is_success(status))
    {
        /* * For the generic base structure, the software reset does nothing but 
         * confirm that the peripheral is ready. 
         * The overlays (e.g., uart_reset) will handle resetting 
         * their specific statistics (rx_count, tx_count, etc.).
         */
        dev->initialized = true;
    }

    return status;
}
