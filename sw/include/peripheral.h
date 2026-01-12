/*
 * @file peripheral.h
 * @brief Peripheral functions prototypes for Mini RV32I SoC
*/

#ifndef PERIPHERAL_H
#define PERIPHERAL_H

#include "system.h"  /* For uint32_t */
#include "peripheral_utils.h"


/* ========================================================================== */
/* Base Peripheral Structure                                                  */
/* ========================================================================== */

/**
 * @brief Base peripheral structure
 * All peripheral drivers should include this as their first member
 */
typedef struct {
    uint32_t    base_address;
    bool        initialized;        /* Track initialization state */
} peripheral_t;


/* ========================================================================== */
/* Peripheral Functions Prototypes                                            */
/* ========================================================================== */

/* Generic peripheral operations with error checking */

/**
 * @brief Initialize Peripheral driver
 * @param dev Pointer to Peripheral structure
 * @param base_addr Base address of the peripheral
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t peripheral_init(peripheral_t *dev, uint32_t base_addr);


/**
 * @brief Deinitialize Peripheral driver
 * @param dev Pointer to Peripheral structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t peripheral_deinit(peripheral_t *dev);


/**
 * @brief Get peripheral base address
 * @param dev Pointer to Peripheral structure
 * @param base_addr Pointer to store base address
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t peripheral_get_base_address(const peripheral_t *dev, uint32_t *base_addr);


/**
 * @brief Check if peripheral is initialized
 * @param dev Pointer to Peripheral structure
 * @param is_initialized Pointer to store initialization status
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t peripheral_is_initialized(const peripheral_t *dev, bool *is_initialized);


/**
 * @brief Validate peripheral address
 * @param dev Pointer to Peripheral structure
 * @param offset Offset to validate
 * @param is_valid Pointer to store validation result
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t peripheral_validate_address(const peripheral_t *dev, uint32_t offset, bool *is_valid);


/**
 * @brief Reset peripheral to default state
 * @param dev Pointer to Peripheral structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t peripheral_reset(peripheral_t *dev);


#endif /* PERIPHERAL_H */