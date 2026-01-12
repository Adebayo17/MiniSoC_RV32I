/*
 * @file system.c
 * @brief System-wide functions implementation with hardware timer support
 */

#include "../include/system.h"
#include "../drivers/timer/include/timer.h"
#include "../include/peripheral_utils.h"
#include <string.h>


/* ========================================================================== */
/* System Global Variables                                                    */
/* ========================================================================== */


/* System timer device */
static timer_t *system_timer = NULL;

/* System start time reference */
static uint32_t system_start_ticks = 0;


/* Non-blocking delay state */
typedef struct {
    bool active;
    uint32_t start_ticks;
    uint32_t delay_ticks;
} delay_state_t;


static delay_state_t delay_state = {false, 0, 0};


/* Legacy tick count for compatibility */
static volatile uint32_t system_tick_count = 0;


/* ========================================================================== */
/* System Initialization with Timer                                           */
/* ========================================================================== */


/* Legacy initialization (for compatibility) */
void system_init(void)
{
    /* Reset legacy tick count */
    system_tick_count = 0;
    
    /* Reset delay state */
    delay_state.active = false;
    delay_state.start_ticks = 0;
    delay_state.delay_ticks = 0;
    
    /* Clear system timer reference */
    system_timer = NULL;
    system_start_ticks = 0;
}


system_error_t system_init_with_timer_safe(timer_t *timer)
{
    PARAM_CHECK_NOT_NULL(timer);
    
    /* Validate timer is initialized */
    bool timer_initialized = false;
    system_error_t err = peripheral_is_initialized(&timer->base, &timer_initialized);
    if (IS_ERROR(err)) {
        return err;
    }
    
    if (!timer_initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Store timer reference */
    system_timer = timer;
    
    /* Configure system timer for continuous mode, maximum range */
    timer_config_t timer_config = {
        .mode = TIMER_MODE_CONTINUOUS,
        .prescale = TIMER_PRESCALE_1,
        .compare_value = 0xFFFFFFFFu,
        .auto_reload = true
    };
    
    err = timer_configure(system_timer, &timer_config);
    if (IS_ERROR(err)) {
        system_timer = NULL;
        return err;
    }
    
    err = timer_enable(system_timer);
    if (IS_ERROR(err)) {
        timer_disable(system_timer);
        system_timer = NULL;
        return err;
    }
    
    /* Get initial tick count for time reference */
    err = timer_get_count(system_timer, &system_start_ticks);
    if (IS_ERROR(err)) {
        timer_disable(system_timer);
        system_timer = NULL;
        return err;
    }
    
    /* Reset delay state */
    delay_state.active = false;
    delay_state.start_ticks = 0;
    delay_state.delay_ticks = 0;
    
    return SYSTEM_SUCCESS;
}


/* Legacy function (for compatibility) */
void system_init_with_timer(timer_t *timer)
{
    (void)system_init_with_timer_safe(timer);
}


/* ========================================================================== */
/* System Reset                                                               */
/* ========================================================================== */

__attribute__((noreturn))
void system_reset(void)
{
    /* Perform any necessary cleanup */
    system_timer = NULL;
    system_start_ticks = 0;
    delay_state.active = false;
    system_tick_count = 0;
    
    /* In a real system, this would trigger a hardware reset */
    /* For simulation, we'll just hang */
    while (1) {
        /* Wait for watchdog or external reset */
    }
}


/* ========================================================================== */
/* Address Validation                                                         */
/* ========================================================================== */

system_error_t system_validate_address(uint32_t addr, bool is_write)
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
/* Time Management Functions                                                  */
/* ========================================================================== */

system_error_t system_get_time_us_safe(uint32_t *time_us)
{
    PARAM_CHECK_NOT_NULL(time_us);
    
    if (system_timer == NULL) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Get current timer count */
    uint32_t current_ticks;
    system_error_t err = timer_get_count(system_timer, &current_ticks);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Calculate elapsed ticks */
    uint32_t elapsed_ticks;
    if (current_ticks >= system_start_ticks) {
        elapsed_ticks = current_ticks - system_start_ticks;
    } else {
        /* Timer wrapped around */
        elapsed_ticks = (0xFFFFFFFFu - system_start_ticks) + current_ticks + 1;
    }
    
    /* Convert ticks to microseconds */
    *time_us = (uint32_t)((uint64_t)elapsed_ticks * 1000000ULL / SYSTEM_CLOCK_FREQ);
    
    return SYSTEM_SUCCESS;
}


uint32_t system_get_time_us(void)
{
    uint32_t time_us = 0;
    (void)system_get_time_us_safe(&time_us);
    return time_us;
}


system_error_t system_get_ticks_safe(uint32_t *ticks)
{
    PARAM_CHECK_NOT_NULL(ticks);
    
    if (system_timer == NULL) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    return timer_get_count(system_timer, ticks);
}


uint32_t system_get_ticks(void)
{
    uint32_t ticks = 0;
    (void)system_get_ticks_safe(&ticks);
    return ticks;
}


system_error_t system_get_elapsed_time_us_safe(uint32_t previous_tick, uint32_t *elapsed_us)
{
    PARAM_CHECK_NOT_NULL(elapsed_us);
    
    if (system_timer == NULL) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    uint32_t current_ticks;
    system_error_t err = timer_get_count(system_timer, &current_ticks);
    if (IS_ERROR(err)) {
        return err;
    }
    
    uint32_t elapsed_ticks;
    
    /* Handle timer overflow */
    if (current_ticks >= previous_tick) {
        elapsed_ticks = current_ticks - previous_tick;
    } else {
        /* Timer wrapped around */
        elapsed_ticks = (0xFFFFFFFFu - previous_tick) + current_ticks + 1;
    }
    
    *elapsed_us = (uint32_t)((uint64_t)elapsed_ticks * 1000000ULL / SYSTEM_CLOCK_FREQ);
    
    return SYSTEM_SUCCESS;
}

uint32_t system_get_elapsed_time_us(uint32_t previous_tick)
{
    uint32_t elapsed_us = 0;
    (void)system_get_elapsed_time_us_safe(previous_tick, &elapsed_us);
    return elapsed_us;
}

/* ========================================================================== */
/* Non-blocking Delay Functions                                               */
/* ========================================================================== */

system_error_t system_delay_us_start_safe(uint32_t us)
{
    if (system_timer == NULL) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    if (delay_state.active) {
        return SYSTEM_ERROR_BUSY;
    }
    
    if (us == 0) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Calculate required ticks for the delay */
    uint64_t delay_ticks = (uint64_t)us * SYSTEM_CLOCK_FREQ / 1000000ULL;
    if (delay_ticks == 0) {
        delay_ticks = 1; /* Minimum 1 tick */
    }
    
    if (delay_ticks > 0xFFFFFFFFu) {
        return SYSTEM_ERROR_INVALID_PARAM; /* Delay too long */
    }
    
    /* Get current timer count */
    uint32_t current_ticks;
    system_error_t err = timer_get_count(system_timer, &current_ticks);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Setup delay state */
    delay_state.start_ticks = current_ticks;
    delay_state.delay_ticks = (uint32_t)delay_ticks;
    delay_state.active = true;
    
    return SYSTEM_SUCCESS;
}


bool system_delay_us_start(uint32_t us)
{
    return (system_delay_us_start_safe(us) == SYSTEM_SUCCESS);
}


system_error_t system_delay_us_complete_safe(bool *is_complete)
{
    PARAM_CHECK_NOT_NULL(is_complete);
    
    if (!delay_state.active || system_timer == NULL) {
        *is_complete = true;
        return SYSTEM_SUCCESS;
    }
    
    uint32_t current_ticks;
    system_error_t err = timer_get_count(system_timer, &current_ticks);
    if (IS_ERROR(err)) {
        return err;
    }
    
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
        *is_complete = true;
    } else {
        *is_complete = false;
    }
    
    return SYSTEM_SUCCESS;
}


bool system_delay_us_complete(void)
{
    bool is_complete = false;
    (void)system_delay_us_complete_safe(&is_complete);
    return is_complete;
}


/* ========================================================================== */
/* Blocking Delay Functions                                                   */
/* ========================================================================== */

system_error_t system_delay_us_safe(uint32_t us)
{
    if (us == 0) {
        return SYSTEM_SUCCESS; /* No delay needed */
    }
    
    if (system_timer == NULL) {
        /* Fallback to software delay if no timer available */
        uint32_t cycles = (us * (SYSTEM_CLOCK_FREQ / 1000000U)) / 10U;
        for (volatile uint32_t i = 0; i < cycles; i++) {
            __asm__ volatile ("nop");
        }
        return SYSTEM_SUCCESS;
    }
    
    return timer_delay_us(system_timer, us);
}


void system_delay_us(uint32_t us)
{
    (void)system_delay_us_safe(us);
}


system_error_t system_delay_ms_safe(uint32_t ms)
{
    /* Convert milliseconds to microseconds */
    if (ms > (0xFFFFFFFFu / 1000u)) {
        return SYSTEM_ERROR_INVALID_PARAM; /* Would overflow */
    }
    
    return system_delay_us_safe(ms * 1000u);
}


void system_delay_ms(uint32_t ms)
{
    (void)system_delay_ms_safe(ms);
}


/* ========================================================================== */
/* Legacy Functions (for compatibility)                                       */
/* ========================================================================== */

void system_tick_handler(void)
{
    system_tick_count++;
}


uint32_t system_get_ticks_legacy(void)
{
    return system_tick_count;
}


/* ========================================================================== */
/* Utility Functions                                                          */
/* ========================================================================== */


uint32_t system_align_up(uint32_t value, uint32_t alignment)
{
    if (alignment == 0 || (alignment & (alignment - 1)) != 0) {
        return value; /* Invalid alignment, return unchanged */
    }
    
    return (value + alignment - 1) & ~(alignment - 1);
}


uint32_t system_align_down(uint32_t value, uint32_t alignment)
{
    if (alignment == 0 || (alignment & (alignment - 1)) != 0) {
        return value; /* Invalid alignment, return unchanged */
    }
    
    return value & ~(alignment - 1);
}