/*
 * @file register_access.h
 * @brief Register Access Macros
*/

#ifndef REG_ACCESS_H
#define REG_ACCESS_H


/* ========================================================================== */
/* Register Access Macros                                                     */
/* ========================================================================== */


/**
 * @brief Read from memory-map register
 * @param addr Memory addr to read from
 * @return 32-bit value read from the address
 */
#define READ_REG(addr)              (*(volatile uint32_t *)(addr))


/**
 * @brief Write to a memory-mapped register
 * @param addr Memory address to read to
 * @param value 32-bit value to write
 */
#define WRITE_REG(addr, value)      (*(volatile uint32_t *)(addr) = (value))


/**
 * @brief Set bits in a register (read-modify-write)
 * @param addr Register address
 * @param mask Bitmask of bits to set
 */
#define SET_BITS(addr, mask)        do { \
    uint32_t reg = READ_REG(addr); \
    reg |= (mask); \
    WRITE_REG(addr, reg); \
} while (0)


/**
 * @brief Clear bits in a register (read-modify-write)
 * @param addr Register address
 * @param mask Bitmask of bits to clear
 */
#define CLEAR_BITS(addr, mask)      do { \
    uint32_t reg = READ_REG(addr); \
    reg &= ~(mask); \
    WRITE_REG(addr, reg); \
} while (0)


/**
 * @brief Modify specific bits in a register (read-modify-write)
 * @param addr Register address
 * @param mask Bitmask of bits to modify
 * @param value New value for the bits (shifted to correct position)
 */
#define MODIFY_BITS(addr, mask, value) do { \
    uint32_t reg = READ_REG(addr); \
    reg &= ~(mask); \
    reg |= ((value) & (mask)); \
    WRITE_REG(addr, reg); \
} while (0)


/* ========================================================================== */
/* Bit Manipulation Macros                                                    */
/* ========================================================================== */


/**
 * @brief Create a bitmask with specified width at given position
 * @param width Number of bits in the mask
 * @param pos Starting bit position (0-based)
 * @return Bitmask value
 */
#define BITMASK(width, pos)         (((1u << (width)) - 1u) << (pos))


/**
 * @brief Extract a field from a register value
 * @param reg Register value
 * @param mask Bitmask for the field
 * @param pos Starting bit position of the field
 * @return Extracted field value
 */
#define GET_FIELD(reg, mask, pos)   (((reg) & (mask)) >> (pos))


/**
 * @brief Set a field in a register value
 * @param reg Register value
 * @param mask Bitmask for the field
 * @param pos Starting bit position of the field
 * @param value Value to set
 * @return Modified register value with field set
 */
#define SET_FIELD(reg, mask, pos, value) \
    (((reg) & ~(mask)) | (((value) << (pos)) & (mask)))


#endif /* REG_ACCESS_H */