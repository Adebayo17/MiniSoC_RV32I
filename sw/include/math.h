/*
 * @file    math.h
 * @brief   Software math functions for Mini RV32I SoC.
 * @details Conforms to Barr Group Embedded C Coding Standard.
 * Provides essential mathematical operations (multiplication, division)
 * for a RISC-V core not implementing the 'M' hardware extension.
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
 * @brief   Check if a number is power of two.
 * @param   [in] x Number to check.
 * @return  true if x is power of two, false otherwise.
 */
static inline bool is_power_of_two(uint32_t x) 
{
    return (x != 0) && ((x & (x - 1)) == 0);
}


/**
 * @brief   Fast division by power of two (using bit shift).
 * @param   [in] value Value to divide.
 * @param   [in] power_two_divisor Must be power of two (2, 4, 8, 16, ...).
 * @return  value / power_two_divisor
 */
static inline uint32_t fast_udiv_pow2(uint32_t value, uint32_t power_two_divisor) 
{
    uint32_t shift = 0U;
    uint32_t temp = power_two_divisor;

    /* Find the shift amount by counting trailing zeros */
    while (temp > 1U) 
    {
        temp >>= 1U;
        shift++;
    }

    return (value >> shift);
}


/**
 * @brief   Fast modulus by power of two (using mask)
 * @param   [in] value Value for modulus
 * @param   [in] power_two_modulus Must be power of two (2, 4, 8, 16, ...)
 * @return  value % power_two_modulus
 */
static inline uint32_t fast_umod_pow2(uint32_t value, uint32_t power_two_modulus) 
{
    return (value & (power_two_modulus - 1));
}


/* ========================================================================== */
/* Software Math Functions (RV32I without M extension)                       */
/* ========================================================================== */

/**
 * @brief  32-bit unsigned multiplication.
 * @param  [in] a First operand.
 * @param  [in] b Second operand.
 * @return a * b.
 */
uint32_t system_umul32(uint32_t a, uint32_t b);


/**
 * @brief  32-bit signed multiplication.
 * @param  [in] a First operand.
 * @param  [in] b Second operand.
 * @return a * b.
 */
int32_t system_mul32(int32_t a, int32_t b);


/**
 * @brief  32-bit unsigned division.
 * @param  [in] dividend Number to be divided.
 * @param  [in] divisor  Number to divide by.
 * @return dividend / divisor (returns 0xFFFFFFFF if divisor is 0).
 */
uint32_t system_udiv32(uint32_t dividend, uint32_t divisor);


/**
 * @brief  32-bit signed division.
 * @param  [in] dividend Number to be divided.
 * @param  [in] divisor  Number to divide by.
 * @return dividend / divisor (returns -1 if divisor is 0).
 */
int32_t system_div32(int32_t dividend, int32_t divisor);


/**
 * @brief  32-bit unsigned modulus.
 * @param  [in] dividend Number to be divided.
 * @param  [in] divisor  Number to divide by.
 * @return dividend % divisor (returns dividend if divisor is 0).
 */
uint32_t system_umod32(uint32_t dividend, uint32_t divisor);


/**
 * @brief  32-bit signed modulus.
 * @param  [in] dividend Number to be divided.
 * @param  [in] divisor  Number to divide by.
 * @return dividend % divisor.
 */
int32_t system_mod32(int32_t dividend, int32_t divisor);


/**
 * @brief  Multiply two 32-bit values and return 64-bit result.
 * @param  [in]  a      First operand.
 * @param  [in]  b      Second operand.
 * @param  [out] result Array to hold result (result[0] = lower 32 bits, result[1] = upper 32 bits).
 */
void system_umul64(uint32_t a, uint32_t b, uint32_t result[2]);


#endif /* MATH_H */