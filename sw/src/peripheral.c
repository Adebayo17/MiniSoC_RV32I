/*
 * @file peripheral.c
 * @brief Peripheral functions prototypes implementation for Mini RV32I SoC
*/

#include "../include/peripheral.h"
#include "../include/system.h"


/* ========================================================================== */
/* Peripheral Functions with System Error Code                                */
/* ========================================================================== */

system_error_t peripheral_init(peripheral_t *dev, uint32_t base_addr)
{
    /* Parameter validation */
    if (dev == NULL)
    {
        return SYSTEM_ERROR_INVALID_PARAM; 
    }

    /* Validate base address */
    if (!IS_PERIPHERAL_ADDRESS(base_addr))
    {
        return SYSTEM_ERROR_INVALID_ADDRESS;
    }

    /* Check if already initialized */
    if (dev->initialized)
    {
        return SYSTEM_ERROR_BUSY;
    }

    /* Initiaize structure */
    dev->base_address = base_addr;
    dev->initialized  = true;

    return SYSTEM_SUCCESS;    
    
}


system_error_t peripheral_deinit(peripheral_t *dev)
{
    /* Parameter validation */
    if (dev == NULL)
    {
        return SYSTEM_ERROR_INVALID_PARAM; 
    }

    /* Check if already initialized */
    if (!dev->initialized)
    {
        return SYSTEM_SUCCESS; /* Already initialized */
    }
    
    /* Reset structure */
    dev->base_address = 0;
    dev->initialized  = false;

    return SYSTEM_SUCCESS;

}


system_error_t peripheral_get_base_address(const peripheral_t *dev, uint32_t *base_addr)
{
    /* Parameter validation */
    if (dev == NULL || base_addr == NULL)
    {
        return SYSTEM_ERROR_INVALID_PARAM; 
    }

    /* Check if initialized */
    if (!dev->initialized)
    {
        return SYSTEM_ERROR_NOT_READY; 
    }

    *base_addr = dev->base_address;
    return SYSTEM_SUCCESS;

}


system_error_t peripheral_is_initialized(const peripheral_t *dev, bool *is_initialized)
{
    /* Parameter validation */
    if (dev == NULL || is_initialized == NULL)
    {
        return SYSTEM_ERROR_INVALID_PARAM; 
    }

    *is_initialized = dev->initialized;
    return SYSTEM_SUCCESS;

}


system_error_t peripheral_validate_address(const peripheral_t *dev, uint32_t offset, bool *is_valid)
{
    /* Parameter validation */
    if (dev == NULL || is_valid == NULL)
    {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->initialized)
    {
        *is_valid = false;
        return SYSTEM_ERROR_NOT_READY;
    }

    /* Validate offset within peripheral space */
    *is_valid = (offset < PERIPH_SIZE);
    
    return SYSTEM_SUCCESS;
    
}


system_error_t peripheral_reset(peripheral_t *dev)
{
    /* Parameter validation */
    if (dev == NULL) 
    {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if initialized */
    if (!dev->initialized) 
    {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* For base peripheral, reset just means clearing the structure */
    dev->base_address = 0;
    dev->initialized  = false;
    
    return SYSTEM_SUCCESS;
}


