/*
 * @file register_access.h
 * @brief Register Access Macros
*/

#ifndef REG_ACCESS_H
#define REG_ACCESS_H


/* ========================================================================== */
/* Bit Manipulation Macros                                                    */
/* ========================================================================== */

/**
 * @brief Creates a mask with a single bit set to 1 at position 'n'.
 * @note  Use the UL (Unsigned Long) suffix to avoid sign extension bugs.
 */
#define BIT(n)                      (1UL << (n))

/**
 * @brief Sets a specific bit in a register to 1.
 */
#define SET_BIT(reg, bit)           ((reg) |= BIT(bit))

/**
 * @brief Sets a specific bit in a register to 0.
 */
#define CLEAR_BIT(reg, bit)         ((reg) &= ~BIT(bit))

/**
 * @brief Inverts (toggles) a specific bit in a register.
 */
#define TOGGLE_BIT(reg, bit)        ((reg) ^= BIT(bit))

/**
 * @brief Reads the value (0 or 1) of a specific bit in a register.
 */
#define READ_BIT(reg, bit)          (((reg) & BIT(bit)) >> (bit))

/**
 * @brief Applies a mask to clear a region, then writes a value to it.
 * @param reg        The register to modify.
 * @param clear_mask The mask of the bits to reset.
 * @param set_value  The value to write to this location.
 */
#define MODIFY_REG(reg, clear_mask, set_value)  ((reg) = (((reg) & ~(clear_mask)) | (set_value)))



/* ========================================================================== */
/* Raw memory access functions (MMIO - Memory Mapped I/O)                  */
/* ========================================================================== */

/**
 * @brief  Writes a 32-bit value to a specific physical address.
 * @param  [in] address Physical memory address (e.g., peripheral register).
 * @param  [in] value   32-bit value to write.
 */
static inline void write_reg32(uint32_t address, uint32_t value)
{
    /* The cast to (volatile uint32_t *) is critical for forcing material writing */
    *((volatile uint32_t *)address) = value;
}


/**
 * @brief  Reads a 32-bit value from a specific physical address.
 * @param  [in] address Physical memory address (e.g., peripheral register).
 * @return 32-bit value read from this address.
 */
static inline uint32_t read_reg32(uint32_t address)
{
    /* The cast to (volatile uint32_t *) is critical to force the material read */
    return *((volatile uint32_t *)address);
}


/**
 * @brief  Writes a 16-bit value to a specific physical address.
 * @param  [in] address Physical memory address (e.g., peripheral register).
 * @param  [in] value   16-bit value to write.
 */
static inline void write_reg16(uint32_t address, uint16_t value)
{
    /* The cast to (volatile uint16_t *) is critical for forcing material writing */
    *((volatile uint16_t *)address) = value;
}


/**
 * @brief  Reads a 16-bit value from a specific physical address.
 * @param  [in] address Physical memory address (e.g., peripheral register).
 * @return 16-bit value read from this address.
 */
static inline uint16_t read_reg16(uint32_t address)
{
    /* The cast to (volatile uint16_t *) is critical to force the material read */
    return *((volatile uint16_t *)address);
}



/**
 * @brief  Writes a 8-bit value to a specific physical address.
 * @param  [in] address Physical memory address (e.g., peripheral register).
 * @param  [in] value   8-bit value to write.
 */
static inline void write_reg8(uint32_t address, uint8_t value)
{
    *((volatile uint8_t *)address) = value;
}

/**
 * @brief  Reads a 8-bit value from a specific physical address.
 * @param  [in] address Physical memory address (e.g., peripheral register).
 * @return 8-bit value read from this address.
 */
static inline uint8_t read_reg8(uint32_t address)
{
    return *((volatile uint8_t *)address);
}

#endif /* REG_ACCESS_H */