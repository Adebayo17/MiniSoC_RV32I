/*
 * @file memory.c
 * @brief Memory Access functions implementations for Mini RV32I SoC
*/

#include "../include/system.h"
#include "../include/memory.h"


/* ========================================================================== */
/* Basic Memory Access (Unaligned Safe)                                       */
/* ========================================================================== */

uint8_t system_read_byte(uint32_t addr)
{
    /* In RISC-V, the LBU (Load Byte Unsigned) instruction handles unaligned addresses. */
    return *((volatile uint8_t *)addr);
}


void system_write_byte(uint32_t addr, uint8_t value)
{
    *((volatile uint8_t *)addr) = value;
}


uint16_t system_read_halfword(uint32_t addr)
{
    return *((volatile uint16_t *)addr);
}


void system_write_halfword(uint32_t addr, uint16_t value)
{
    *((volatile uint16_t *)addr) = value;
}


uint32_t system_read_word(uint32_t addr)
{
    return *((volatile uint32_t *)addr);
}


void system_write_word(uint32_t addr, uint32_t value)
{
    *((volatile uint32_t *)addr) = value;
}


/* ========================================================================== */
/* Safe Memory Access with Error Checking                                     */
/* ========================================================================== */

system_error_t system_read_byte_safe(uint32_t addr, uint8_t *value)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (value == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = system_validate_address(addr, false);

        if (is_success(status))
        {
            *value = system_read_byte(addr);
        }
    }

    return status;
}


system_error_t system_write_byte_safe(uint32_t addr, uint8_t value)
{
    system_error_t status = system_validate_address(addr, true);

    if (is_success(status))
    {
        system_write_byte(addr, value);
    }

    return status;
}


system_error_t system_read_halfword_safe(uint32_t addr, uint16_t *value)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (value == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    /* 2-byte (16-bit) alignment check for RISC-V */
    else if ((addr & 1U) != 0U)
    {
        status = SYSTEM_ERROR_MEMORY_ACCESS; 
    }
    else
    {
        status = system_validate_address(addr, false);

        if (is_success(status))
        {
            *value = system_read_halfword(addr);
        }
    }

    return status;
}


system_error_t system_write_halfword_safe(uint32_t addr, uint16_t value)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((addr & 1U) != 0U)
    {
        status = SYSTEM_ERROR_MEMORY_ACCESS;
    }
    else
    {
        status = system_validate_address(addr, true);

        if (is_success(status))
        {
            system_write_halfword(addr, value);
        }
    }

    return status;
}


system_error_t system_read_word_safe(uint32_t addr, uint32_t *value)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (value == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    /* Strict 4-byte (32-bit) alignment check for RISC-V */
    else if ((addr & 3U) != 0U)
    {
        status = SYSTEM_ERROR_MEMORY_ACCESS;
    }
    else
    {
        status = system_validate_address(addr, false);

        if (is_success(status))
        {
            *value = system_read_word(addr);
        }
    }

    return status;
}


system_error_t system_write_word_safe(uint32_t addr, uint32_t value)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((addr & 3U) != 0U)
    {
        status = SYSTEM_ERROR_MEMORY_ACCESS;
    }
    else
    {
        status = system_validate_address(addr, true);

        if (is_success(status))
        {
            system_write_word(addr, value);
        }
    }

    return status;
}


/* ========================================================================== */
/* Standard-Compliant Memory Functions                                        */
/* ========================================================================== */

void *system_memcpy(void *dest, const void *src, size_t n)
{
    if ((dest != NULL) && (src != NULL) && (n > 0U))
    {
        uint8_t *d = (uint8_t *)dest;
        const uint8_t *s = (const uint8_t *)src;
        size_t bytes_left = n;

        /* Copy by 32-bit words if perfect alignment */
        if ((((uintptr_t)d & 3U) == 0U) && (((uintptr_t)s & 3U) == 0U))
        {
            uint32_t *d32 = (uint32_t *)d;
            const uint32_t *s32 = (const uint32_t *)s;
            
            while (bytes_left >= 4U)
            {
                *d32++ = *s32++;
                bytes_left -= 4U;
            }
            
            /* Updating byte pointers for the remainder */
            d = (uint8_t *)d32;
            s = (const uint8_t *)s32;
        }

        /* Copying the remaining bytes */
        while (bytes_left > 0U)
        {
            *d++ = *s++;
            bytes_left--;
        }
    }

    return dest;
}


void *system_memmove(void *dest, const void *src, size_t n)
{
    if ((dest != NULL) && (src != NULL) && (dest != src) && (n > 0U))
    {
        uint8_t *d = (uint8_t *)dest;
        const uint8_t *s = (const uint8_t *)src;

        if (d < s)
        {
            /* No destructive overlap: optimized call */
            (void)system_memcpy(dest, src, n);
        }
        else
        {
            /* Overlap: copy from the back, right to left */
            size_t bytes_left = n;
            
            /* 32-bit block copy backwards */
            if ((((uintptr_t)d & 3U) == 0U) && (((uintptr_t)s & 3U) == 0U))
            {
                uint32_t *d32 = (uint32_t *)(d + n);
                const uint32_t *s32 = (const uint32_t *)(s + n);
                
                while (bytes_left >= 4U)
                {
                    *(--d32) = *(--s32);
                    bytes_left -= 4U;
                }
                
                /* Potential residual (although rare if n is a multiple of 4) */
                d = (uint8_t *)d32;
                s = (const uint8_t *)s32;
            }
            else
            {
                d += n;
                s += n;
            }

            /* Copying the remaining bytes from the back */
            while (bytes_left > 0U)
            {
                *(--d) = *(--s);
                bytes_left--;
            }
        }
    }

    return dest;
}


void *system_memset(void *dest, int c, size_t n)
{
    if ((dest != NULL) && (n > 0U))
    {
        uint8_t *d = (uint8_t *)dest;
        uint8_t val = (uint8_t)c;
        size_t bytes_left = n;

        /* 32-bit word optimization */
        if (((uintptr_t)d & 3U) == 0U)
        {
            uint32_t val32 = ((uint32_t)val << 24) | ((uint32_t)val << 16) | ((uint32_t)val << 8) | (uint32_t)val;
            uint32_t *d32 = (uint32_t *)d;
            
            while (bytes_left >= 4U)
            {
                *d32++ = val32;
                bytes_left -= 4U;
            }
            d = (uint8_t *)d32;
        }

        /* Remainder */
        while (bytes_left > 0U)
        {
            *d++ = val;
            bytes_left--;
        }
    }

    return dest;
}


int system_memcmp(const void *s1, const void *s2, size_t n)
{
    int result = 0;

    if ((s1 != NULL) && (s2 != NULL) && (n > 0U))
    {
        const uint8_t *p1 = (const uint8_t *)s1;
        const uint8_t *p2 = (const uint8_t *)s2;
        size_t i;

        for (i = 0U; i < n; i++)
        {
            if (p1[i] != p2[i])
            {
                result = (p1[i] < p2[i]) ? -1 : 1;
                break;
            }
        }
    }

    return result;
}


void *memcpy(void *dest, const void *src, size_t n)
{
    return system_memcpy(dest, src, n);
}

/* ========================================================================== */
/* Safe Memory Functions Implementation                                       */
/* ========================================================================== */

system_error_t system_memcpy_safe(void *dest, const void *src, size_t n, void **result)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (result != NULL)
    {
        *result = NULL;
    }

    if ((dest == NULL) || (src == NULL))
    {
        if (n > 0U)
        {
            status = SYSTEM_ERROR_INVALID_PARAM;
        }
        else if (result != NULL)
        {
            *result = dest;
        }
    }
    else if (n > 0U)
    {
        status = system_validate_address_range((uint32_t)src, n, false);

        if (is_success(status))
        {
            status = system_validate_address_range((uint32_t)dest, n, true);
        }

        if (is_success(status))
        {
            uint8_t *d = (uint8_t *)dest;
            const uint8_t *s = (const uint8_t *)src;
            void *ret;

            /* Application intelligence: Fallback to memory if overlap */
            if ((d > s && d < (s + n)) || (s > d && s < (d + n)))
            {
                ret = system_memmove(dest, src, n);
            }
            else
            {
                ret = system_memcpy(dest, src, n);
            }
            
            if (result != NULL)
            {
                *result = ret;
            }
        }
    }
    else
    {
        if (result != NULL)
        {
            *result = dest;
        }
    }

    return status;
}


system_error_t system_memmove_safe(void *dest, const void *src, size_t n, void **result)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (result != NULL)
    {
        *result = NULL;
    }

    if ((dest == NULL) || (src == NULL))
    {
        if (n > 0U)
        {
            status = SYSTEM_ERROR_INVALID_PARAM;
        }
        else if (result != NULL)
        {
            *result = dest;
        }
    }
    else if (n > 0U)
    {
        status = system_validate_address_range((uint32_t)src, n, false);

        if (is_success(status))
        {
            status = system_validate_address_range((uint32_t)dest, n, true);
        }

        if (is_success(status))
        {
            void *ret = system_memmove(dest, src, n);
            if (result != NULL)
            {
                *result = ret;
            }
        }
    }
    else
    {
        if (result != NULL)
        {
            *result = dest;
        }
    }

    return status;
}


system_error_t system_memset_safe(void *dest, uint8_t value, size_t n, void **result)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (result != NULL)
    {
        *result = NULL;
    }

    if (dest == NULL)
    {
        if (n > 0U)
        {
            status = SYSTEM_ERROR_INVALID_PARAM;
        }
        else if (result != NULL)
        {
            *result = dest;
        }
    }
    else if (n > 0U)
    {
        status = system_validate_address_range((uint32_t)dest, n, true);

        if (is_success(status))
        {
            void *ret = system_memset(dest, (int)value, n);
            if (result != NULL)
            {
                *result = ret;
            }
        }
    }
    else
    {
        if (result != NULL)
        {
            *result = dest;
        }
    }

    return status;
}


system_error_t system_memcmp_safe(const void *s1, const void *s2, size_t n, int *result)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (result != NULL)
    {
        *result = 0;
    }

    if ((s1 == NULL) || (s2 == NULL))
    {
        if (n > 0U)
        {
            status = SYSTEM_ERROR_INVALID_PARAM;
        }
    }
    else if (n > 0U)
    {
        status = system_validate_address_range((uint32_t)s1, n, false);

        if (is_success(status))
        {
            status = system_validate_address_range((uint32_t)s2, n, false);
        }

        if (is_success(status))
        {
            if (result != NULL)
            {
                *result = system_memcmp(s1, s2, n);
            }
        }
    }
    else
    {
        /* n == 0, everything is ok */
    }

    return status;
}


/* ========================================================================== */
/* Utility Functions Implementation                                           */
/* ========================================================================== */

system_error_t system_validate_address_range(uint32_t addr, uint32_t size, bool is_write)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (size > 0U)
    {
        uint32_t end_addr = (addr + size) - 1U;

        /* Verification: Arithmetic overflow of the end address */
        if (end_addr < addr)
        {
            status = SYSTEM_ERROR_INVALID_ADDRESS;
        }
        else
        {
            /* Verification: memory block endpoints */
            status = system_validate_address(addr, is_write);

            if (is_success(status))
            {
                status = system_validate_address(end_addr, is_write);
            }

            /* Enhanced security: Verifies that the block does not "skip" zones
               This would prevent a silent overflow  between IMEM and DMEM for example. */
            if (is_success(status))
            {
                if (is_imem_address(addr) && !is_imem_address(end_addr))
                {
                    status = SYSTEM_ERROR_MEMORY_ACCESS;
                }
                else if (is_dmem_address(addr) && !is_dmem_address(end_addr))
                {
                    status = SYSTEM_ERROR_MEMORY_ACCESS;
                }
                else if (is_peripheral_address(addr) && !is_peripheral_address(end_addr))
                {
                    status = SYSTEM_ERROR_MEMORY_ACCESS;
                }
                else
                {
                    /* The area is valid and completely contiguous. */
                }
            }
        }
        
    }
    return status;
}


bool system_is_aligned(const void *ptr, size_t alignment)
{
    bool aligned = false;

    if ((alignment != 0U) && ((alignment & (alignment - 1U)) == 0U))
    {
        if (((uintptr_t)ptr & (alignment - 1U)) == 0U)
        {
            aligned = true;
        }
        
    }
    return aligned;
}