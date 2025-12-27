/*
 * @file peripheral.c
 * @brief Peripheral functions prototypes implementation for Mini RV32I SoC
*/

#include "peripheral.h"


/* ========================================================================== */
/* Peripheral Functions                                                       */
/* ========================================================================== */

void peripheral_init(peripheral_t *dev, uint32_t base_addr) 
{
    dev->base_address = base_addr;
}

uint32_t peripheral_get_base_address(const peripheral_t *dev) 
{
    return dev->base_address;
}

bool peripheral_validate_address(const peripheral_t *dev, uint32_t offset) 
{
    return (dev != NULL) && (offset < 0x1000);  // 4KB peripheral space check
}

