/*
 * @file    peripheral_utils.h
 * @brief   Peripheral utility functions for validation
 * @details Conforms to Barr Group Embedded C Coding Standard. 
*/

#ifndef PERIPHERAL_UTILS_H
#define PERIPHERAL_UTILS_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include "errors.h"
#include "system.h"


/* ========================================================================== */
/* Common Validation Inline Functions                                         */
/* ========================================================================== */


/**
 * @brief  Check if pointer parameter is valid (not NULL)
 * @param  [in] ptr Pointer to check
 * @return SYSTEM_SUCCESS if valid, SYSTEM_ERROR_INVALID_PARAM otherwise
 */
static inline system_error_t param_check_not_null(const void *ptr)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (ptr == NULL) 
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }

    return status;
}

/**
 * @brief  Validate memery address range.
 * @param  [in] addr Starting address
 * @param  [in] size Size of memory region
 * @param  [in] is_write true for write access, false for read
 * @return SYSTEM_SUCCESS if valid, error code otherwise
 */
static inline system_error_t validate_memory_range(uint32_t addr, uint32_t size, bool is_write)
{
    system_error_t status = SYSTEM_SUCCESS;
    uint32_t i;

    for (i = 0U; i < size; i++) 
    {
        status = system_validate_address(addr + i, is_write);

        if (is_error(status)) 
        {
            /* Immediate interrupt when error is found */
            break;
        }
    }

    return status;
}


/**
 * @brief  Validate buffer parameters.
 * @param  [in] buffer Pointer to buffer.
 * @param  [in] size   Buffer size in bytes.
 * @return SYSTEM_SUCCESS if valid, error code otherwise.
 */
static inline system_error_t validate_buffer(const void *buffer, uint32_t size)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((buffer == NULL) && (size > 0U))
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else if (size > 0U)
    {
        /* Validate buffer memory range */
        status = validate_memory_range((uint32_t)buffer, size, false);
    }
    else
    {
        /* Buffer size is 0: considered valid */
        status = SYSTEM_SUCCESS; 
    }

    return status;
}


#endif /* PERIPHERAL_UTILS_H */