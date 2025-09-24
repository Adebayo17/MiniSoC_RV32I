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

uint64_t system_get_time_us(void)
{
    if (system_timer == NULL) return 0;
    
    /* Calculate time based on timer ticks and clock frequency */
    uint32_t current_ticks = timer_get_count(system_timer);
    uint32_t elapsed_ticks = current_ticks - system_start_ticks;
    
    /* Convert ticks to microseconds */
    return (uint64_t)elapsed_ticks * 1000000ULL / SYSTEM_CLOCK_FREQ;
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
    
    return (uint32_t)((uint64_t)elapsed_ticks * 1000000ULL / SYSTEM_CLOCK_FREQ);
}


/* ========================================================================== */
/* Non-blocking Delay Functions                                               */
/* ========================================================================== */

bool system_delay_us_start(uint32_t us)
{
    if (system_timer == NULL || delay_state.active) return false;
    
    /* Calculate required ticks for the delay */
    uint32_t delay_ticks = (uint32_t)((uint64_t)us * SYSTEM_CLOCK_FREQ / 1000000ULL);
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
    return (offset < 0x1000);  // 4KB peripheral space check
}