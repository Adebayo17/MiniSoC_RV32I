/*
 * @file system.c
 * @brief System-wide functions implementation with hardware timer support
 */

#include "system.h"
#include "timer.h"

/* System timer device */
static timer_t *system_timer = NULL;
static volatile uint32_t system_start_ticks = 0;

/* Non-blocking delay state */
static struct {
    bool active;
    uint32_t start_ticks;
    uint32_t delay_ticks;
} delay_state = {false, 0, 0};



/* ========================================================================== */
/* System Initialization                                                      */
/* ========================================================================== */

void system_init_with_timer(timer_t *timer)
{
    if (timer == NULL) return;
    
    system_timer = timer;
    
    /* Initialize system timer for continuous mode, maximum range */
    timer_configure(system_timer, TIMER_MODE_CONTINUOUS, 
                   TIMER_PRESCALE_1, 0xFFFFFFFFu);
    timer_enable(system_timer);
    
    /* Store initial tick count for time reference */
    system_start_ticks = timer_get_count(system_timer);
    delay_state.active = false;
}


/* ========================================================================== */
/* Time Management Functions                                                  */
/* ========================================================================== */

uint32_t system_get_time_us(void)
{
    if (system_timer == NULL) return 0;
    
    /* Calculate time based on timer ticks and clock frequency */
    uint32_t current_ticks = timer_get_count(system_timer);
    uint32_t elapsed_ticks = current_ticks - system_start_ticks;
    
    /* Convert ticks to microseconds */
    return (uint32_t)elapsed_ticks * 1000000ULL / SYSTEM_CLOCK_FREQ;
}


uint32_t system_get_ticks(void)
{
    if (system_timer == NULL) return 0;
    return timer_get_count(system_timer);
}


uint32_t system_get_elapsed_time_us(uint32_t previous_tick)
{
    if (system_timer == NULL) return 0;
    
    uint32_t current_ticks = timer_get_count(system_timer);
    uint32_t elapsed_ticks;
    
    /* Handle timer overflow */
    if (current_ticks >= previous_tick) {
        elapsed_ticks = current_ticks - previous_tick;
    } else {
        /* Timer wrapped around */
        elapsed_ticks = (0xFFFFFFFFu - previous_tick) + current_ticks + 1;
    }
    
    return (uint32_t)((uint32_t)elapsed_ticks * 1000000ULL / SYSTEM_CLOCK_FREQ);
}


/* ========================================================================== */
/* Non-blocking Delay Functions                                               */
/* ========================================================================== */

bool system_delay_us_start(uint32_t us)
{
    if (system_timer == NULL || delay_state.active) return false;
    
    /* Calculate required ticks for the delay */
    uint32_t delay_ticks = (uint32_t)((uint32_t)us * SYSTEM_CLOCK_FREQ / 1000000ULL);
    if (delay_ticks == 0) delay_ticks = 1; /* Minimum 1 tick */
    
    /* Setup delay state */
    delay_state.start_ticks = timer_get_count(system_timer);
    delay_state.delay_ticks = delay_ticks;
    delay_state.active = true;
    
    return true;
}

bool system_delay_us_complete(void)
{
    if (!delay_state.active || system_timer == NULL) return true;
    
    uint32_t current_ticks = timer_get_count(system_timer);
    uint32_t elapsed_ticks;
    
    /* Handle timer overflow */
    if (current_ticks >= delay_state.start_ticks) {
        elapsed_ticks = current_ticks - delay_state.start_ticks;
    } else {
        elapsed_ticks = (0xFFFFFFFFu - delay_state.start_ticks) + current_ticks + 1;
    }
    
    /* Check if delay completed */
    if (elapsed_ticks >= delay_state.delay_ticks) {
        delay_state.active = false;
        return true;
    }
    
    return false;
}


/* ========================================================================== */
/* Blocking Delay Functions                                                   */
/* ========================================================================== */

void system_delay_us(uint32_t us)
{
    if (system_timer == NULL) {
        /* Fallback to software delay if no timer available */
        uint32_t cycles = (us * (SYSTEM_CLOCK_FREQ / 1000000U)) / 10U;
        for (volatile uint32_t i = 0; i < cycles; i++) {
            __asm__ volatile ("nop");
        }
        return;
    }
    
    /* Use one-shot timer for precise blocking delay */
    timer_configure(system_timer, TIMER_MODE_ONESHOT, 
                   TIMER_PRESCALE_1, us * (SYSTEM_CLOCK_FREQ / 1000000U));
    timer_clear_status(system_timer);
    timer_enable(system_timer);
    
    /* Wait for timer match */
    while (!timer_is_match(system_timer)) {
        /* Could add idle/wfi instruction here to save power */
    }
    
    timer_clear_match(system_timer);
}


void system_delay_ms(uint32_t ms)
{
    system_delay_us(ms * 1000U);
}


/* ========================================================================== */
/* Legacy Functions (for compatibility)                                       */
/* ========================================================================== */

/* Keep legacy system_tick_count for compatibility */
static volatile uint32_t system_tick_count = 0;


void system_init(void)
{
    /* Legacy initialization without timer */
    system_tick_count = 0;
}


void system_tick_handler(void)
{
    system_tick_count++;
}

uint32_t system_get_ticks_legacy(void)
{
    return system_tick_count;
}


/* ========================================================================== */
/* Address Validation                                                         */
/* ========================================================================== */

int system_validate_address(uint32_t addr, bool is_write)
{
    /* Check IMEM access (read-only) */
    if (IS_IMEM_ADDRESS(addr)) {
        if (is_write) {
            return SYSTEM_ERROR_MEMORY_ACCESS; /* Cannot write to IMEM */
        }
        return SYSTEM_SUCCESS;
    }
    
    /* Check DMEM access (read-write) */
    if (IS_DMEM_ADDRESS(addr)) {
        return SYSTEM_SUCCESS; /* DMEM supports both read and write */
    }
    
    /* Check peripheral access (read-write) */
    if (IS_PERIPHERAL_ADDRESS(addr)) {
        return SYSTEM_SUCCESS; /* Peripherals support both read and write */
    }
    
    /* Address is outside valid ranges */
    return SYSTEM_ERROR_INVALID_ADDRESS;
}


/* ========================================================================== */
/* Peripheral Functions                                                       */
/* ========================================================================== */

void peripheral_init(peripheral_t *dev, uint32_t base_addr) 
{
    dev->base_address = base_addr;
}

uint32_t peripheral_get_base_address(const peripheral_t *dev) 
{
    return dev->base_address;
}

bool peripheral_validate_address(const peripheral_t *dev, uint32_t offset) 
{
    return (dev != NULL) && (offset < 0x1000);  // 4KB peripheral space check
}


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