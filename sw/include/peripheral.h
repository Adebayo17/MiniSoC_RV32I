/*
 * @file peripheral.h
 * @brief Peripheral functions prototypes for Mini RV32I SoC
*/

#ifndef PERIPHERAL_H
#define PERIPHERAL_H

#include "system.h"  /* For uint32_t */

/* ========================================================================== */
/* Base Peripheral Structure                                                  */
/* ========================================================================== */


/**
 * @brief Base peripheral structure
 * All peripheral drivers should include this as their first member
 */
typedef struct {
    uint32_t base_address;
} peripheral_t;


/* ========================================================================== */
/* Peripheral Functions Prototypes                                            */
/* ========================================================================== */

/* Generic peripheral operations */

/**
 * @brief Initialize Peripheral driver
 * @param dev Pointer to Peripheral structure
 * @param base_addr Base address of the peripheral
 */
void peripheral_init(peripheral_t *dev, uint32_t base_addr);


/**
 * @brief Get peripheral base address
 * @param dev Pointer to Peripheral structure
 * @return Base address of the peripheral
 */
uint32_t peripheral_get_base_address(const peripheral_t *dev);


/**
 * @brief Check if the offset is in the peripheral memory space
 * @param dev Pointer to Peripheral structure
 * @param offset Offset to check 
 * @return true if device valid and in peripheral memory space, false otherwise
 */
bool peripheral_validate_address(const peripheral_t *dev, uint32_t offset);


#endif /* PERIPHERAL_H */