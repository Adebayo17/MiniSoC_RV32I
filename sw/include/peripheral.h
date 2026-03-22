/*
 * @file    peripheral.h
 * @brief   Peripheral functions prototypes for Mini RV32I SoC.
 * @details Conforms to Barr Group Embedded C Coding Standard.
 * Define the "Handle" structure for peripherals and common operations.
*/

#ifndef PERIPHERAL_H
#define PERIPHERAL_H

#include <stdint.h>
#include <stdbool.h>

#include "errors.h"                 /* For system_error_t */
#include "system.h"                 /* For uint32_t and system addresses */
#include "peripheral_utils.h"       /* For common validation functions */


/* ========================================================================== */
/* Base Peripheral Structure (Software Handle)                                */
/* ========================================================================== */

/**
 * @struct  peripheral_t
 * @brief   Base peripheral structure
 * @note    This structure serves as a common base for all peripheral drivers (UART, GPIO, etc.).
 * All peripheral drivers should include this as their first member
 */
typedef struct 
{
    uint32_t    base_address;       /*!< Physical base address of the peripheral (MMIO) */
    bool        initialized;        /*!< Indicates if the peripheral is initialized */
} peripheral_t;


/* ========================================================================== */
/* Peripheral Validation Inline Functions                                     */
/* ========================================================================== */

/**
 * @brief  Check if peripheral is valid (not NULL and initialized).
 * @param  [in] dev Pointer to peripheral structure.
 * @return SYSTEM_SUCCESS if valid, error code otherwise.
 */
static inline system_error_t peripheral_check_valid(const peripheral_t *dev)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (dev == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else if (!(dev->initialized))
    {
        status = SYSTEM_ERROR_NOT_READY;
    }
    else
    {
        /* Peripheral is valid and initialized */
    }

    return status;
}


/* ========================================================================== */
/* Peripheral Functions Prototypes                                            */
/* ========================================================================== */


/**
 * @brief  Initialize Generic Peripheral driver.
 * @param  [in,out] dev       Pointer to Peripheral structure (Software Handle).
 * @param  [in]     base_addr Physical base address of the hardware peripheral.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t peripheral_init(peripheral_t *dev, uint32_t base_addr);


/**
 * @brief  Deinitialize Generic Peripheral driver.
 * @param  [in,out] dev Pointer to Peripheral structure.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t peripheral_deinit(peripheral_t *dev);


/**
 * @brief  Get peripheral base address.
 * @param  [in]  dev       Pointer to Peripheral structure.
 * @param  [out] base_addr Pointer to store the base address.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t peripheral_get_base_address(const peripheral_t *dev, uint32_t *base_addr);


/**
 * @brief  Check if peripheral is initialized.
 * @param  [in]  dev            Pointer to Peripheral structure.
 * @param  [out] is_initialized Pointer to store initialization status.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t peripheral_is_initialized(const peripheral_t *dev, bool *is_initialized);


/**
 * @brief  Validate a specific offset within the peripheral's address space.
 * @param  [in]  dev      Pointer to Peripheral structure.
 * @param  [in]  offset   Offset (in bytes) from the base address to validate.
 * @param  [out] is_valid Pointer to store validation result (true if valid).
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t peripheral_validate_address(const peripheral_t *dev, uint32_t offset, bool *is_valid);


/**
 * @brief  Reset peripheral software context to default state.
 * @note   This generally does NOT perform a hardware reset, only software state reset.
 * @param  [in,out] dev Pointer to Peripheral structure.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t peripheral_reset(peripheral_t *dev);


#endif /* PERIPHERAL_H */