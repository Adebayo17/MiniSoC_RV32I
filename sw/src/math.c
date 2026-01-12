/*
 * @file math.c
 * @brief Software math functions for Mini RV32I SoC implementation
 */

#include "../include/math.h"

/* ========================================================================== */
/* Software Math Functions Implementation                                     */
/* ========================================================================== */


// Unsigned multiplication using shift-and-add algorithm
uint32_t system_umul32(uint32_t a, uint32_t b)
{
    uint32_t result = 0;
    
    while (b > 0) {
        if (b & 1) {
            result += a;
        }
        a <<= 1;
        b >>= 1;
    }
    
    return result;
}

// Signed multiplication
int32_t system_mul32(int32_t a, int32_t b)
{
    // Handle sign and use unsigned multiplication
    bool negative = (a < 0) != (b < 0);
    uint32_t abs_a = (a < 0) ? -a : a;
    uint32_t abs_b = (b < 0) ? -b : b;
    uint32_t abs_result = system_umul32(abs_a, abs_b);
    
    return negative ? -abs_result : abs_result;
}

// Unsigned division using restoring division algorithm
uint32_t system_udiv32(uint32_t dividend, uint32_t divisor)
{
    if (divisor == 0) {
        // Division by zero - return maximum value
        return 0xFFFFFFFF;
    }
    
    // Handle power of two divisors efficiently
    if (is_power_of_two(divisor)) {
        return fast_udiv_pow2(dividend, divisor);
    }
    
    // Restoring division algorithm
    uint32_t quotient = 0;
    uint32_t remainder = 0;
    
    for (int i = 31; i >= 0; i--) {
        remainder = (remainder << 1) | ((dividend >> i) & 1);
        if (remainder >= divisor) {
            remainder -= divisor;
            quotient |= (1 << i);
        }
    }
    
    return quotient;
}

// Signed division
int32_t system_div32(int32_t dividend, int32_t divisor)
{
    if (divisor == 0) {
        // Division by zero
        return 0x7FFFFFFF; // Maximum positive value
    }
    
    // Handle sign and use unsigned division
    bool negative = (dividend < 0) != (divisor < 0);
    uint32_t abs_dividend = (dividend < 0) ? -dividend : dividend;
    uint32_t abs_divisor = (divisor < 0) ? -divisor : divisor;
    uint32_t abs_quotient = system_udiv32(abs_dividend, abs_divisor);
    
    return negative ? -abs_quotient : abs_quotient;
}

// Unsigned modulus
uint32_t system_umod32(uint32_t dividend, uint32_t divisor)
{
    if (divisor == 0) {
        return dividend; // Modulus by zero returns dividend
    }
    
    // Handle power of two divisors efficiently
    if (is_power_of_two(divisor)) {
        return fast_umod_pow2(dividend, divisor);
    }
    
    return dividend - system_umul32(system_udiv32(dividend, divisor), divisor);
}

// Signed modulus
int32_t system_mod32(int32_t dividend, int32_t divisor)
{
    if (divisor == 0) {
        return dividend;
    }
    
    // C99 standard: (a/b)*b + a%b == a
    return dividend - system_mul32(system_div32(dividend, divisor), divisor);
}

// 64-bit multiplication result
void system_umul64(uint32_t a, uint32_t b, uint32_t result[2])
{
    // Split into 16-bit chunks to avoid overflow
    uint32_t a_low = a & 0xFFFF;
    uint32_t a_high = a >> 16;
    uint32_t b_low = b & 0xFFFF;
    uint32_t b_high = b >> 16;
    
    uint32_t p0 = a_low * b_low;
    uint32_t p1 = a_low * b_high;
    uint32_t p2 = a_high * b_low;
    uint32_t p3 = a_high * b_high;
    
    uint32_t low = p0 + ((p1 + p2) << 16);
    uint32_t high = p3 + ((p1 + p2) >> 16) + ((low < p0) ? 1 : 0); // Carry
    
    result[0] = low;
    result[1] = high;
}