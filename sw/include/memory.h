/**
 * @file    memory.h
 * @brief   Memory Access functions for Mini RV32I SoC.
 * @details Conforms to Barr Group Embedded C Coding Standard.
 * Provides functions for direct, safe, and standard-compliant 
 * memory manipulation.
 */

#ifndef MEMORY_H
#define MEMORY_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "errors.h"


/* ========================================================================== */
/* Basic Memory Access (Unaligned Safe)                                       */
/* ========================================================================== */

/**
 * @brief  Read a byte from memory (emulated for word-aligned systems).
 * @param  [in] addr Memory address (can be unaligned).
 * @return 8-bit value read from the address.
 */
uint8_t system_read_byte(uint32_t addr);


/**
 * @brief  Write a byte to memory (emulated for word-aligned systems).
 * @param  [in] addr Memory address (can be unaligned).
 * @param  [in] value 8-bit value to write.
 */
void system_write_byte(uint32_t addr, uint8_t value);


/**
 * @brief  Read a half-word (16-bit) from memory.
 * @param  [in] addr Memory address (should be 2-byte aligned for efficiency).
 * @return 16-bit value read from the address.
 */
uint16_t system_read_halfword(uint32_t addr);


/**
 * @brief  Write a half-word (16-bit) to memory.
 * @param  [in] addr Memory address (should be 2-byte aligned for efficiency).
 * @param  [in] value 16-bit value to write.
 */
void system_write_halfword(uint32_t addr, uint16_t value);


/**
 * @brief  Read a word (32-bit) from memory.
 * @param  [in] addr Memory address (must be 4-byte aligned).
 * @return 32-bit value read from the address.
 */
uint32_t system_read_word(uint32_t addr);


/**
 * @brief  Write a word (32-bit) to memory.
 * @param  [in] addr Memory address (must be 4-byte aligned).
 * @param  [in] value 32-bit value to write.
 */
void system_write_word(uint32_t addr, uint32_t value);


/* ========================================================================== */
/* Safe Memory Access with Error Checking                                     */
/* ========================================================================== */


/**
 * @brief  Read a byte from memory with error checking.
 * @param  [in] addr Memory address.
 * @param  [out] value Pointer to store read value.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_read_byte_safe(uint32_t addr, uint8_t *value);


/**
 * @brief  Write a byte to memory with error checking.
 * @param  [in] addr Memory address.
 * @param  [in] value 8-bit value to write.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_write_byte_safe(uint32_t addr, uint8_t value);


/**
 * @brief  Read a half-word from memory with error checking.
 * @param  [in] addr Memory address.
 * @param  [out] value Pointer to store read value.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_read_halfword_safe(uint32_t addr, uint16_t *value);


/**
 * @brief  Write a half-word to memory with error checking.
 * @param  [in] addr Memory address.
 * @param  [in] value 16-bit value to write.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_write_halfword_safe(uint32_t addr, uint16_t value);


/**
 * @brief  Read a word from memory with error checking.
 * @param  [in] addr Memory address.
 * @param  [out] value Pointer to store read value.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_read_word_safe(uint32_t addr, uint32_t *value);


/**
 * @brief  Write a word to memory with error checking.
 * @param  [in] addr Memory address.
 * @param  [in] value 32-bit value to write.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_write_word_safe(uint32_t addr, uint32_t value);


/* ========================================================================== */
/* Standard-Compliant Memory Functions                                        */
/* ========================================================================== */


/**
 * @brief  Copy memory block (memcpy equivalent).
 * @param  [out] dest Destination address.
 * @param  [in] src Source address.
 * @param  [in] n Number of bytes to copy.
 * @return Pointer to dest.
 * @note   For non-overlapping memory areas only.
 */
void *system_memcpy(void *dest, const void *src, size_t n);


/**
 * @brief  Copy memory area handling overlap (memmove equivalent).
 * @param  [out] dest Destination address.
 * @param  [in] src Source address.
 * @param  [in] n Number of bytes to copy.
 * @return Pointer to dest.
 * @note   Safe for overlapping memory areas.
 */
void *system_memmove(void *dest, const void *src, size_t n);


/**
 * @brief  Fill memory with a constant byte (memset equivalent).
 * @param  [out] dest Destination address.
 * @param  [in] c Value to set (as int, only lowest byte used).
 * @param  [in] n Number of bytes to set.
 * @return Pointer to dest.
 */
void *system_memset(void *dest, int c, size_t n);


/**
 * @brief  Compare memory areas (memcmp equivalent).
 * @param  [in] s1 First memory area.
 * @param  [in] s2 Second memory area.
 * @param  [in] n Number of bytes to compare.
 * @return <0 if s1 < s2, 0 if s1 == s2, >0 if s1 > s2.
 */
int system_memcmp(const void *s1, const void *s2, size_t n);


/**
 * @brief  Copy memory block (named for linter search).
 * @param  [out] dest Destination address.
 * @param  [in] src Source address.
 * @param  [in] n Number of bytes to copy.
 * @return Pointer to dest.
 * @note   For non-overlapping memory areas only.
 */
void *memcpy(void *dest, const void *src, size_t n);


/* ========================================================================== */
/* Safe Memory Functions with Error Checking                                  */
/* ========================================================================== */

/**
 * @brief  Safe memory copy with error checking.
 * @param  [out] dest Destination address.
 * @param  [in] src Source address.
 * @param  [in] n Number of bytes to copy.
 * @param  [out] result Pointer to store result pointer (optional, can be NULL).
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_memcpy_safe(void *dest, const void *src, size_t n, void **result);


/**
 * @brief  Safe memory move with error checking.
 * @param  [out] dest Destination address.
 * @param  [in] src Source address.
 * @param  [in] n Number of bytes to copy.
 * @param  [out] result Pointer to store result pointer (optional, can be NULL).
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_memmove_safe(void *dest, const void *src, size_t n, void **result);


/**
 * @brief  Safe memory set with error checking.
 * @param  [out] dest Destination address.
 * @param  [in] value Value to set.
 * @param  [in] n Number of bytes to set.
 * @param  [out] result Pointer to store result pointer (optional, can be NULL).
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_memset_safe(void *dest, uint8_t value, size_t n, void **result);


/**
 * @brief  Safe memory compare with error checking.
 * @param  [in] s1 First memory area.
 * @param  [in] s2 Second memory area.
 * @param  [in] n Number of bytes to compare.
 * @param  [out] result Pointer to store comparison result.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t system_memcmp_safe(const void *s1, const void *s2, size_t n, int *result);


/* ========================================================================== */
/* Utility Functions                                                          */
/* ========================================================================== */

/**
 * @brief  Validate memory address range.
 * @param  [in] addr Starting address.
 * @param  [in] size Size of memory region in bytes.
 * @param  [in] is_write true for write access, false for read.
 * @return SYSTEM_SUCCESS if valid, error code otherwise.
 */
system_error_t system_validate_address_range(uint32_t addr, uint32_t size, bool is_write);


/**
 * @brief  Check if pointer is aligned to specific boundary.
 * @param  [in] ptr Pointer to check.
 * @param  [in] alignment Alignment boundary (must be power of two).
 * @return true if aligned, false otherwise.
 */
bool system_is_aligned(const void *ptr, size_t alignment);


/**
 * @brief  Get minimum of two size values.
 * @param  [in] a First value.
 * @param  [in] b Second value.
 * @return Minimum of a and b.
 */
static inline size_t min_size(size_t a, size_t b) 
{
    return (a < b) ? a : b;
}


/**
 * @brief  Get maximum of two size values.
 * @param  [in] a First value.
 * @param  [in] b Second value.
 * @return Maximum of a and b.
 */
static inline size_t max_size(size_t a, size_t b) 
{
    return (a > b) ? a : b;
}

#endif /* MEMORY_H */