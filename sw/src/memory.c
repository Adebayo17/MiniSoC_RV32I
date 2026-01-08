/*
 * @file memory.c
 * @brief Memory Access functions implementations for Mini RV32I SoC
*/

#include "system.h"
#include "memory.h"

/* ========================================================================== */
/* Memory Access Functions Implementation                                     */
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


system_error_t system_read_word_safe(uint32_t addr, uint32_t *value)
{
    if (value == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }

    system_error_t err = system_validate_address(addr, false);
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
    system_error_t err = system_validate_address(addr, true);
    if (IS_ERROR(err)) {
        return err;
    }
    
    system_write_word(addr, value);
    return SYSTEM_SUCCESS;
}


void system_memcpy(void *dest, const void *src, size_t n)
{
    uint8_t *d = (uint8_t *)dest;
    const uint8_t *s = (const uint8_t *)src;
    
    // Try to copy words when possible for efficiency
    while (n >= 4 && ((uint32_t)d & 0x3) == 0 && ((uint32_t)s & 0x3) == 0) {
        system_write_word((uint32_t)d, system_read_word((uint32_t)s));
        d += 4;
        s += 4;
        n -= 4;
    }
    
    // Copy remaining bytes
    while (n > 0) {
        system_write_byte((uint32_t)d, system_read_byte((uint32_t)s));
        d++;
        s++;
        n--;
    }
}

void system_memset(void *dest, uint8_t value, size_t n)
{
    uint8_t *d = (uint8_t *)dest;
    
    // Create a word with the repeated byte value
    uint32_t word_value = (value << 24) | (value << 16) | (value << 8) | value;
    
    // Try to set words when possible for efficiency
    while (n >= 4 && ((uint32_t)d & 0x3) == 0) {
        system_write_word((uint32_t)d, word_value);
        d += 4;
        n -= 4;
    }
    
    // Set remaining bytes
    while (n > 0) {
        system_write_byte((uint32_t)d, value);
        d++;
        n--;
    }
}

