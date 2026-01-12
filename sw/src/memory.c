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
    uint32_t word_addr = addr & ~0x3;  // Align to word boundary
    uint32_t byte_offset = addr & 0x3; // Byte position within word
    uint32_t word = READ_REG(word_addr);
    
    return (word >> (byte_offset * 8)) & 0xFF;
}


void system_write_byte(uint32_t addr, uint8_t value)
{
    uint32_t word_addr = addr & ~0x3;  // Align to word boundary
    uint32_t byte_offset = addr & 0x3; // Byte position within word
    uint32_t word = READ_REG(word_addr);
    uint32_t mask = 0xFF << (byte_offset * 8);
    
    word = (word & ~mask) | ((uint32_t)value << (byte_offset * 8));
    WRITE_REG(word_addr, word);
}


uint16_t system_read_halfword(uint32_t addr)
{
    // Check if address is halfword-aligned
    if ((addr & 0x1) == 0) {
        // Aligned access - read word and extract halfword
        uint32_t word_addr = addr & ~0x3;
        uint32_t halfword_offset = (addr & 0x2) >> 1;
        uint32_t word = READ_REG(word_addr);
        
        return (word >> (halfword_offset * 16)) & 0xFFFF;
    } else {
        // Unaligned access - read two bytes
        uint8_t byte0 = system_read_byte(addr);
        uint8_t byte1 = system_read_byte(addr + 1);
        return (byte1 << 8) | byte0;
    }
}


void system_write_halfword(uint32_t addr, uint16_t value)
{
    // Check if address is halfword-aligned
    if ((addr & 0x1) == 0) {
        // Aligned access
        uint32_t word_addr = addr & ~0x3;
        uint32_t halfword_offset = (addr & 0x2) >> 1;
        uint32_t word = READ_REG(word_addr);
        uint32_t mask = 0xFFFF << (halfword_offset * 16);
        
        word = (word & ~mask) | ((uint32_t)value << (halfword_offset * 16));
        WRITE_REG(word_addr, word);
    } else {
        // Unaligned access - write two bytes
        system_write_byte(addr, value & 0xFF);
        system_write_byte(addr + 1, (value >> 8) & 0xFF);
    }
}


uint32_t system_read_word(uint32_t addr)
{
    // Address must be word-aligned
    if ((addr & 0x3) != 0) {
        // Fallback to byte reads for unaligned access
        uint8_t b0 = system_read_byte(addr);
        uint8_t b1 = system_read_byte(addr + 1);
        uint8_t b2 = system_read_byte(addr + 2);
        uint8_t b3 = system_read_byte(addr + 3);
        return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
    }
    
    return READ_REG(addr);
}


void system_write_word(uint32_t addr, uint32_t value)
{
    // Address must be word-aligned
    if ((addr & 0x3) != 0) {
        // Fallback to byte writes for unaligned access
        system_write_byte(addr, value & 0xFF);
        system_write_byte(addr + 1, (value >> 8) & 0xFF);
        system_write_byte(addr + 2, (value >> 16) & 0xFF);
        system_write_byte(addr + 3, (value >> 24) & 0xFF);
        return;
    }
    
    WRITE_REG(addr, value);
}


/* ========================================================================== */
/* Safe Memory Access with Error Checking                                     */
/* ========================================================================== */

system_error_t system_read_byte_safe(uint32_t addr, uint8_t *value)
{
    if (value == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }

    system_error_t err = system_validate_address(addr, false);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *value = system_read_byte(addr);
    
    /* Check for hardware error patterns */
    if (IS_HARDWARE_ERROR(*value)) {
        return HARDWARE_ERROR_TO_SYSTEM_ERROR(*value);
    }
    
    return SYSTEM_SUCCESS;
}


system_error_t system_write_byte_safe(uint32_t addr, uint8_t value)
{
    system_error_t err = system_validate_address(addr, true);
    if (IS_ERROR(err)) {
        return err;
    }
    
    system_write_byte(addr, value);
    return SYSTEM_SUCCESS;
}


system_error_t system_read_halfword_safe(uint32_t addr, uint16_t *value)
{
    if (value == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }

    /* Validate both bytes of the halfword */
    system_error_t err = system_validate_address_range(addr, 2, false);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *value = system_read_halfword(addr);
    
    /* Check for hardware error patterns */
    if (IS_HARDWARE_ERROR(*value)) {
        return HARDWARE_ERROR_TO_SYSTEM_ERROR(*value);
    }
    
    return SYSTEM_SUCCESS;
}


system_error_t system_write_halfword_safe(uint32_t addr, uint16_t value)
{
    /* Validate both bytes of the halfword */
    system_error_t err = system_validate_address_range(addr, 2, true);
    if (IS_ERROR(err)) {
        return err;
    }
    
    system_write_halfword(addr, value);
    return SYSTEM_SUCCESS;
}


system_error_t system_read_word_safe(uint32_t addr, uint32_t *value)
{
    if (value == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }

    /* Validate all bytes of the word */
    system_error_t err = system_validate_address_range(addr, 4, false);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *value = system_read_word(addr);
    
    /* Check for hardware error patterns */
    if (IS_HARDWARE_ERROR(*value)) {
        return HARDWARE_ERROR_TO_SYSTEM_ERROR(*value);
    }
    
    return SYSTEM_SUCCESS;
}


system_error_t system_write_word_safe(uint32_t addr, uint32_t value)
{
    /* Validate all bytes of the word */
    system_error_t err = system_validate_address_range(addr, 4, true);
    if (IS_ERROR(err)) {
        return err;
    }
    
    system_write_word(addr, value);
    return SYSTEM_SUCCESS;
}


/* ========================================================================== */
/* Standard-Compliant Memory Functions                                        */
/* ========================================================================== */

void *system_memcpy(void *dest, const void *src, size_t n)
{
    if (dest == NULL || src == NULL || n == 0) {
        return dest;
    }
    
    uint8_t *d = (uint8_t *)dest;
    const uint8_t *s = (const uint8_t *)src;
    
    /* If no overlap or dest > src, copy forward */
    if (d > s || (d + n) <= s) {
        /* Try to copy words when possible for efficiency */
        while (n >= 4 && ((uint32_t)d & 0x3) == 0 && ((uint32_t)s & 0x3) == 0) {
            system_write_word((uint32_t)d, system_read_word((uint32_t)s));
            d += 4;
            s += 4;
            n -= 4;
        }
        
        /* Copy remaining bytes */
        while (n > 0) {
            system_write_byte((uint32_t)d, system_read_byte((uint32_t)s));
            d++;
            s++;
            n--;
        }
    }
    
    return dest;
}


void *system_memmove(void *dest, const void *src, size_t n)
{
    if (dest == NULL || src == NULL || n == 0) {
        return dest;
    }
    
    uint8_t *d = (uint8_t *)dest;
    const uint8_t *s = (const uint8_t *)src;
    
    /* Check for overlap */
    if (d < s) {
        /* Copy forward (no overlap or dest before src) */
        return system_memcpy(dest, src, n);
    } else if (d > s) {
        /* Copy backward (overlap, dest after src) */
        d += n;
        s += n;
        
        while (n >= 4) {
            d -= 4;
            s -= 4;
            system_write_word((uint32_t)d, system_read_word((uint32_t)s));
            n -= 4;
        }
        
        while (n > 0) {
            d--;
            s--;
            system_write_byte((uint32_t)d, system_read_byte((uint32_t)s));
            n--;
        }
    }
    
    /* If dest == src, nothing to do */
    return dest;
}


void *system_memset(void *dest, int c, size_t n)
{
    if (dest == NULL || n == 0) {
        return dest;
    }
    
    uint8_t value = (uint8_t)(c & 0xFF);  /* Only use lowest byte */
    uint8_t *d = (uint8_t *)dest;
    
    /* For very small buffers, use simple byte writes */
    if (n < 8) {
        while (n > 0) {
            system_write_byte((uint32_t)d, value);
            d++;
            n--;
        }
        return dest;
    }
    
    /* Handle initial unaligned bytes */
    while (n > 0 && ((uint32_t)d & 0x3) != 0) {
        system_write_byte((uint32_t)d, value);
        d++;
        n--;
    }
    
    /* Create a word with the repeated byte value */
    uint32_t word_value = (value << 24) | (value << 16) | (value << 8) | value;
    
    /* Write aligned words */
    while (n >= 4) {
        system_write_word((uint32_t)d, word_value);
        d += 4;
        n -= 4;
    }
    
    /* Handle remaining bytes */
    while (n > 0) {
        system_write_byte((uint32_t)d, value);
        d++;
        n--;
    }
    
    return dest;
}


int system_memcmp(const void *s1, const void *s2, size_t n)
{
    if (s1 == NULL || s2 == NULL || n == 0) {
        return 0;
    }
    
    const uint8_t *p1 = (const uint8_t *)s1;
    const uint8_t *p2 = (const uint8_t *)s2;
    
    while (n-- > 0) {
        uint8_t b1 = system_read_byte((uint32_t)p1);
        uint8_t b2 = system_read_byte((uint32_t)p2);
        
        if (b1 != b2) {
            return (int)b1 - (int)b2;
        }
        
        p1++;
        p2++;
    }
    
    return 0;
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
    if (result != NULL) {
        *result = NULL;
    }
    
    if (dest == NULL || src == NULL) {
        if (n > 0) {
            return SYSTEM_ERROR_INVALID_PARAM;
        }
        if (result != NULL) {
            *result = dest;
        }
        return SYSTEM_SUCCESS;
    }
    
    if (n == 0) {
        if (result != NULL) {
            *result = dest;
        }
        return SYSTEM_SUCCESS;
    }
    
    /* Validate source memory range (read access) */
    system_error_t err = system_validate_address_range((uint32_t)src, n, false);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Validate destination memory range (write access) */
    err = system_validate_address_range((uint32_t)dest, n, true);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Check for overlap */
    uint8_t *d = (uint8_t *)dest;
    const uint8_t *s = (const uint8_t *)src;
    
    if ((d > s && d < (s + n)) || (s > d && s < (d + n))) {
        /* Overlap detected - use memmove instead */
        void *ret = system_memmove(dest, src, n);
        if (result != NULL) {
            *result = ret;
        }
        return (ret != NULL) ? SYSTEM_SUCCESS : SYSTEM_ERROR_MEMORY_ACCESS;
    }
    
    /* No overlap - use memcpy */
    void *ret = system_memcpy(dest, src, n);
    if (result != NULL) {
        *result = ret;
    }
    
    return (ret != NULL) ? SYSTEM_SUCCESS : SYSTEM_ERROR_MEMORY_ACCESS;
}


system_error_t system_memmove_safe(void *dest, const void *src, size_t n, void **result)
{
    if (result != NULL) {
        *result = NULL;
    }
    
    if (dest == NULL || src == NULL) {
        if (n > 0) {
            return SYSTEM_ERROR_INVALID_PARAM;
        }
        if (result != NULL) {
            *result = dest;
        }
        return SYSTEM_SUCCESS;
    }
    
    if (n == 0) {
        if (result != NULL) {
            *result = dest;
        }
        return SYSTEM_SUCCESS;
    }
    
    /* Validate source memory range (read access) */
    system_error_t err = system_validate_address_range((uint32_t)src, n, false);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Validate destination memory range (write access) */
    err = system_validate_address_range((uint32_t)dest, n, true);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* memmove handles overlap automatically */
    void *ret = system_memmove(dest, src, n);
    if (result != NULL) {
        *result = ret;
    }
    
    return (ret != NULL) ? SYSTEM_SUCCESS : SYSTEM_ERROR_MEMORY_ACCESS;
}


system_error_t system_memset_safe(void *dest, uint8_t value, size_t n, void **result)
{
    if (result != NULL) {
        *result = NULL;
    }
    
    if (dest == NULL) {
        if (n > 0) {
            return SYSTEM_ERROR_INVALID_PARAM;
        }
        if (result != NULL) {
            *result = dest;
        }
        return SYSTEM_SUCCESS;
    }
    
    if (n == 0) {
        if (result != NULL) {
            *result = dest;
        }
        return SYSTEM_SUCCESS;
    }
    
    /* Validate destination memory range (write access) */
    system_error_t err = system_validate_address_range((uint32_t)dest, n, true);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Call standard memset (which will work since we validated addresses) */
    void *ret = system_memset(dest, value, n);
    if (result != NULL) {
        *result = ret;
    }
    
    return (ret != NULL) ? SYSTEM_SUCCESS : SYSTEM_ERROR_MEMORY_ACCESS;
}


system_error_t system_memcmp_safe(const void *s1, const void *s2, size_t n, int *result)
{
    if (result != NULL) {
        *result = 0;
    }
    
    if (s1 == NULL || s2 == NULL) {
        if (n > 0) {
            return SYSTEM_ERROR_INVALID_PARAM;
        }
        return SYSTEM_SUCCESS;
    }
    
    if (n == 0) {
        if (result != NULL) {
            *result = 0;
        }
        return SYSTEM_SUCCESS;
    }
    
    /* Validate both memory ranges (read access) */
    system_error_t err = system_validate_address_range((uint32_t)s1, n, false);
    if (IS_ERROR(err)) {
        return err;
    }
    
    err = system_validate_address_range((uint32_t)s2, n, false);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Perform comparison */
    int cmp_result = system_memcmp(s1, s2, n);
    
    if (result != NULL) {
        *result = cmp_result;
    }
    
    return SYSTEM_SUCCESS;
}


/* ========================================================================== */
/* Utility Functions Implementation                                           */
/* ========================================================================== */

system_error_t system_validate_address_range(uint32_t addr, uint32_t size, bool is_write)
{
    if (size == 0) {
        return SYSTEM_SUCCESS; /* Empty range is always valid */
    }
    
    /* Check for overflow in address calculation */
    if ((addr + size) < addr) {
        return SYSTEM_ERROR_INVALID_ADDRESS; /* Address wrapped around */
    }
    
    /* Check each byte in the range */
    for (uint32_t i = 0; i < size; i++) {
        system_error_t err = system_validate_address(addr + i, is_write);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    return SYSTEM_SUCCESS;
}


bool system_is_aligned(const void *ptr, size_t alignment)
{
    /* alignment must be power of two */
    if (alignment == 0 || (alignment & (alignment - 1)) != 0) {
        return false;
    }
    
    return ((uintptr_t)ptr & (alignment - 1)) == 0;
}