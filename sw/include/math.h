/*
 * @file math.h
 * @brief Software math functions for Mini RV32I SoC
*/

#ifndef MATH_H
#define MATH_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* ========================================================================== */
/* Fast Math Helpers (for common cases)                                       */
/* ========================================================================== */

/**
 * @brief Check if a number is power of two
 * @param x Number to check
 * @return true if x is power of two
 */
static inline bool is_power_of_two(uint32_t x) {
    return (x != 0) && ((x & (x - 1)) == 0);
}


/**
 * @brief Fast division by power of two (using shift)
 * @param value Value to divide
 * @param power_two_divisor Must be power of two (2, 4, 8, 16, ...)
 * @return value / power_two_divisor
 */
static inline uint32_t fast_udiv_pow2(uint32_t value, uint32_t power_two_divisor) {
    // Find the shift amount by counting trailing zeros
    uint32_t shift = 0;
    uint32_t temp = power_two_divisor;
    while (temp > 1) {
        temp >>= 1;
        shift++;
    }
    return value >> shift;
}


/**
 * @brief Fast modulus by power of two (using mask)
 * @param value Value for modulus
 * @param power_two_modulus Must be power of two (2, 4, 8, 16, ...)
 * @return value % power_two_modulus
 */
static inline uint32_t fast_umod_pow2(uint32_t value, uint32_t power_two_modulus) {
    return value & (power_two_modulus - 1);
}


/* ========================================================================== */
/* Software Math Functions (RV32I without M extension)                       */
/* ========================================================================== */

/**
 * @brief 32-bit unsigned multiplication
 * @param a First operand
 * @param b Second operand
 * @return a * b
 */
uint32_t system_umul32(uint32_t a, uint32_t b);


/**
 * @brief 32-bit signed multiplication
 * @param a First operand
 * @param b Second operand
 * @return a * b
 */
int32_t system_mul32(int32_t a, int32_t b);


/**
 * @brief 32-bit unsigned division
 * @param dividend Number to be divided
 * @param divisor Number to divide by
 * @return dividend / divisor
 */
uint32_t system_udiv32(uint32_t dividend, uint32_t divisor);


/**
 * @brief 32-bit signed division
 * @param dividend Number to be divided
 * @param divisor Number to divide by
 * @return dividend / divisor
 */
int32_t system_div32(int32_t dividend, int32_t divisor);


/**
 * @brief 32-bit unsigned modulus
 * @param dividend Number to be divided
 * @param divisor Number to divide by
 * @return dividend % divisor
 */
uint32_t system_umod32(uint32_t dividend, uint32_t divisor);


/**
 * @brief 32-bit signed modulus
 * @param dividend Number to be divided
 * @param divisor Number to divide by
 * @return dividend % divisor
 */
int32_t system_mod32(int32_t dividend, int32_t divisor);


/**
 * @brief Multiply two 32-bit values and return 64-bit result
 * @param a First operand
 * @param b Second operand
 * @return a * b as 64-bit value (lower 32 bits in result[0], upper in result[1])
 */
void system_umul64(uint32_t a, uint32_t b, uint32_t result[2]);


#endif /* MATH_H */