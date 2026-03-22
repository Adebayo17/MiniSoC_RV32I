/*
 * @file    math.c
 * @brief   Software math functions for Mini RV32I SoC implementation.
 * @details Conforms to Barr Group Embedded C Coding Standard.
 */

#include "../include/math.h"

/* ========================================================================== */
/* Unsigned Mathematics                                                       */
/* ========================================================================== */

uint32_t system_umul32(uint32_t a, uint32_t b)
{
    uint32_t result = 0U;
    uint32_t temp_a = a;
    uint32_t temp_b = b;
    
    /* Algorithm: Shift-and-Add Multiplication */
    while (temp_b != 0u) 
    {
        /* If the least significant bit of b is 1, we add a to the result. */
        if ((temp_b & 1u) != 0u) 
        {
            result += temp_a;
        }

        /* Shift a to the left (multiply by 2) */
        temp_a <<= 1u;
        /* Shift b to the right (divide by 2) */
        temp_b >>= 1u;
    }
    
    return result;
}


uint32_t system_udiv32(uint32_t dividend, uint32_t divisor)
{
    uint32_t quotient = 0u;
    uint32_t remainder = 0u;
    int32_t  i;
    
    /* RISC-V Specification: Division by zero returns all bits to 1 */
    if (divisor == 0u) 
    {
        quotient = 0xFFFFFFFFU;
    }
    else
    {
        /* Algorithm: Restoring Division (Binary Long Division) */
        for (i = 31; i >= 0; i--)
        {
            /* Shift remainder to the left and add the next bit to the dividend */
            remainder = (remainder << 1u) | ((dividend >> (uint32_t)i) & 1u);

            if (remainder >= divisor)
            {
                remainder -= divisor;
                quotient  |= (1u << (uint32_t)i);
            }
            
        }
        
    }

    return quotient;
}


uint32_t system_umod32(uint32_t dividend, uint32_t divisor)
{
    uint32_t remainder = 0u;
    int32_t  i;

    /* RISC-V Specification: Modulus by zero returns dividend */
    if (divisor == 0u) 
    {
        remainder = dividend;
    }
    else
    {
        for (i = 31; i >= 0; i--)
        {
            remainder = (remainder << 1u) | ((dividend >> (uint32_t)i) & 1u);

            if (remainder >= divisor)
            {
                remainder -= divisor;
            }
        }
    }
    
    return remainder;
}


void system_umul64(uint32_t a, uint32_t b, uint32_t result[2])
{
    if (result != NULL)
    {
        uint32_t a_lo = a;
        uint32_t a_hi = 0U;
        uint32_t temp_b = b;
        
        uint32_t res_lo = 0U;
        uint32_t res_hi = 0U;
        
        while (temp_b != 0U)
        {
            if ((temp_b & 1U) != 0U)
            {
                uint32_t old_lo = res_lo;
                res_lo += a_lo;
                
                /* Overrun detection (carry) on the lower part */
                if (res_lo < old_lo)
                {
                    res_hi++; 
                }
                res_hi += a_hi;
            }
            
            /* Shifting a_hi and a_lo as if they formed a 64-bit integer */
            a_hi = (a_hi << 1U) | (a_lo >> 31U);
            a_lo <<= 1U;
            
            temp_b >>= 1U;
        }
        
        result[0] = res_lo;
        result[1] = res_hi;
    }
}


/* ========================================================================== */
/* Signed Mathematics                                                         */
/* ========================================================================== */

int32_t system_mul32(int32_t a, int32_t b)
{
    uint32_t ua = (a < 0) ? (uint32_t)(-a) : (uint32_t)a;
    uint32_t ub = (b < 0) ? (uint32_t)(-b) : (uint32_t)b;
    
    uint32_t ures = system_umul32(ua, ub);
    
    /* The result is negative if one (but not both) of the operands is negative. */
    bool is_negative = ((a < 0) != (b < 0));
    
    return is_negative ? (int32_t)(-ures) : (int32_t)ures;
}


int32_t system_div32(int32_t dividend, int32_t divisor)
{
    int32_t result;

    if (divisor == 0)
    {
        result = -1; /* Typical RISC-V specification for division by 0 */
    }
    else if ((dividend == (int32_t)0x80000000) && (divisor == -1))
    {
        /* RISC-V overflow case: INT_MIN / -1 */
        result = dividend; 
    }
    else
    {
        uint32_t udividend = (dividend < 0) ? (uint32_t)(-dividend) : (uint32_t)dividend;
        uint32_t udivisor  = (divisor < 0) ? (uint32_t)(-divisor) : (uint32_t)divisor;
        
        uint32_t ures = system_udiv32(udividend, udivisor);
        
        bool is_negative = ((dividend < 0) != (divisor < 0));
        result = is_negative ? (int32_t)(-ures) : (int32_t)ures;
    }

    return result;
}


int32_t system_mod32(int32_t dividend, int32_t divisor)
{
    int32_t result;

    if (divisor == 0)
    {
        result = dividend;
    }
    else if ((dividend == (int32_t)0x80000000) && (divisor == -1))
    {
        result = 0; /* Overflow INT_MIN / -1, the remainder is 0 */
    }
    else
    {
        uint32_t udividend = (dividend < 0) ? (uint32_t)(-dividend) : (uint32_t)dividend;
        uint32_t udivisor  = (divisor < 0) ? (uint32_t)(-divisor) : (uint32_t)divisor;
        
        uint32_t ures = system_umod32(udividend, udivisor);
        
        /* In C, the sign of the remainder is always the same as the sign of the dividend. */
        result = (dividend < 0) ? (int32_t)(-ures) : (int32_t)ures;
    }

    return result;
}

