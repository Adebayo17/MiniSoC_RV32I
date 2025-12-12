/*
 * @file memory.h
 * @brief Memory Access functions for Mini RV32I SoC
*/

#ifndef MEMORY_H
#define MEMORY_H


/* ========================================================================== */
/* Memory Access Functions                                                    */
/* ========================================================================== */

/**
 * @brief Read a byte from memory (emulated for word-aligned systems)
 * @param addr Memory address (can be unaligned)
 * @return 8-bit value read from the address
 */
uint8_t system_read_byte(uint32_t addr);


/**
 * @brief Write a byte to memory (emulated for word-aligned systems)
 * @param addr Memory address (can be unaligned)
 * @param value 8-bit value to write
 */
void system_write_byte(uint32_t addr, uint8_t value);


/**
 * @brief Read a half-word (16-bit) from memory
 * @param addr Memory address (should be 2-byte aligned for efficiency)
 * @return 16-bit value read from the address
 */
uint16_t system_read_halfword(uint32_t addr);


/**
 * @brief Write a half-word (16-bit) to memory
 * @param addr Memory address (should be 2-byte aligned for efficiency)
 * @param value 16-bit value to write
 */
void system_write_halfword(uint32_t addr, uint16_t value);


/**
 * @brief Read a word (32-bit) from memory
 * @param addr Memory address (must be 4-byte aligned)
 * @return 32-bit value read from the address
 */
uint32_t system_read_word(uint32_t addr);


/**
 * @brief Write a word (32-bit) to memory
 * @param addr Memory address (must be 4-byte aligned)
 * @param value 32-bit value to write
 */
void system_write_word(uint32_t addr, uint32_t value);


/**
 * @brief Copy memory block (memcpy equivalent)
 * @param dest Destination address
 * @param src Source address
 * @param n Number of bytes to copy
 */
void system_memcpy(void *dest, const void *src, size_t n);


/**
 * @brief Set memory block to value (memset equivalent)
 * @param dest Destination address
 * @param value Value to set
 * @param n Number of bytes to set
 */
void system_memset(void *dest, uint8_t value, size_t n);



#endif /* MEMORY_H */