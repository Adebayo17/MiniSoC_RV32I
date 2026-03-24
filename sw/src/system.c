/*
 * @file    system.c
 * @brief   System-wide functions implementation with hardware timer support.
 * @details Conforms to Barr Group Embedded C Coding Standard.
 */

#include "../include/system.h"
#include "../include/math.h"
#include "../drivers/timer/include/timer.h"
#include "timer_hw.h"
#include <string.h>


/* ========================================================================== */
/* System Global Variables                                                    */
/* ========================================================================== */

/**
 * @brief Pointer to the hardware timer used as the system time base
 */
static timer_t *g_system_timer = NULL;

/**
 * @struct delay_state_t
 * @brief Non-blocking delay state
 */
typedef struct {
    bool        active;           /*!< Indicates whether the delay is active */
    uint32_t    start_time;       /*!< Delay Start time (in µs) */
    uint32_t    duration_us;      /*!< Delay duration (in µs) */
} delay_state_t;


static delay_state_t g_delay = {
    .active         = false, 
    .start_time     = 0U, 
    .duration_us    = 0U
};


/* ========================================================================== */
/* System Initialization with Timer                                           */
/* ========================================================================== */


void system_init(void)
{
    /* Reset delay state */
    g_delay.active      = false;
    g_delay.start_time  = 0;
    g_delay.duration_us = 0;
    
    /* Clear system timer reference */
    g_system_timer = NULL;
}


system_error_t system_init_with_timer_safe(timer_t *timer)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (timer == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        /* We check that the timer driver itself is properly initialized. */
        status = peripheral_check_valid(timer_to_peripheral(timer));

        if (is_success(status))
        {
            g_system_timer = timer;

            /* Configuring the timer in CONTINUOUS mode to serve as a time base */
            timer_config_t cfg;
            cfg.mode          = TIMER_MODE_CONTINUOUS;
            cfg.prescale      = TIMER_PRESCALE_1;       /* Maximum Precision */
            cfg.compare_value = TIMER_MAX_VALUE;        /* Count to 0xFFFFFFFF */

            status = timer_configure(g_system_timer, &cfg);

            if (is_success(status))
            {
                status = timer_enable(g_system_timer);
            }
        }
    }

    return status;
}


void system_init_with_timer(timer_t *system_timer)
{
    /* The error is being silently ignored */
    (void)system_init_with_timer_safe(system_timer);
}


/* ========================================================================== */
/* System Reset                                                               */
/* ========================================================================== */

__attribute__((noreturn))
void system_reset(void)
{
    /* *Soft Reset
     * Jump to the base address of instruction memory (0x00000000)
     */
    void (*reset_vector)(void) = (void (*)(void))IMEM_BASE_ADDRESS;
    
    /* Performs the unconditional jump */
    reset_vector();

    /* * Code should never reach this line
     * The infinite loop guarantees the '__attribute__((noreturn))' behavior
     */
    while (1) 
    {
        /* Infinite trap */
    }
}


/* ========================================================================== */
/* Address Validation                                                         */
/* ========================================================================== */

system_error_t system_validate_address(uint32_t addr, bool is_write)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (is_imem_address(addr))
    {
        /* * Instruction Memory (IMEM) is generally write-protected
         * from the CPU (Classic Harvard Architecture).
         */
        if (is_write)
        {
            status = SYSTEM_ERROR_MEMORY_ACCESS;
        }
    }
    else if (is_dmem_address(addr))
    {
        /* DMEM is accessible for reading and writing */
        status = SYSTEM_SUCCESS; 
    }
    else if (is_peripheral_address(addr))
    {
        /* Hardware Peripherals are managed independently */
        status = SYSTEM_SUCCESS;
    }
    else
    {
        /* The address does not correspond to any known area */
        status = SYSTEM_ERROR_INVALID_ADDRESS;
    }

    return status;
}


/* ========================================================================== */
/* Time Management Functions                                                  */
/* ========================================================================== */

system_error_t system_get_ticks_safe(uint32_t *ticks)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (ticks == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else if (g_system_timer == NULL)
    {
        status = SYSTEM_ERROR_NOT_READY;
    }
    else
    {
        /* Physical reading of the current counter via the timer driver */
        status = timer_get_count(g_system_timer, ticks);
    }
    
    return status;
}


system_error_t system_get_time_us_safe(uint32_t *time_us)
{
    system_error_t status = SYSTEM_SUCCESS;
    uint32_t ticks = 0U;

    if (time_us == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = system_get_ticks_safe(&ticks);

        if (is_success(status))
        {
            uint32_t ticks_per_us = system_udiv32(g_system_timer->clock_frequency, 1000000U);

            if (ticks_per_us > 0U)
            {
                *time_us = system_udiv32(ticks, ticks_per_us);
            }
            else
            {
                /* If the system clock is < 1 MHz, degraded conversion is used to avoid div by 0 */
                *time_us = 0U; 
            }
        }
    }

    return status;
}


system_error_t system_get_elapsed_time_us_safe(uint32_t previous_tick, uint32_t *elapsed_us)
{
    system_error_t status = SYSTEM_SUCCESS;
    uint32_t current_tick = 0U;

    if (elapsed_us == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = system_get_ticks_safe(&current_tick);

        if (is_success(status))
        {
            uint32_t diff_ticks;

            /* Intelligent management of 32-bit counter overflow */
            if (current_tick >= previous_tick)
            {
                diff_ticks = current_tick - previous_tick;
            }
            else
            {
                diff_ticks = (0xFFFFFFFFU - previous_tick) + current_tick + 1U;
            }

            uint32_t ticks_per_us = system_udiv32(g_system_timer->clock_frequency, 1000000U);
            
            if (ticks_per_us > 0U)
            {
                *elapsed_us = system_udiv32(diff_ticks, ticks_per_us);
            }
            else
            {
                *elapsed_us = 0U;
            }
        }
    }

    return status;
}


/* ========================================================================== */
/* Blocking Delay Functions                                                   */
/* ========================================================================== */

system_error_t system_delay_us_safe(uint32_t us)
{
    system_error_t status = SYSTEM_SUCCESS;
    uint32_t start_tick = 0U;
    uint32_t elapsed_us = 0U;

    status = system_get_ticks_safe(&start_tick);

    if (is_success(status))
    {
        /* Active loop (Busy-wait) without destroying the Timer configuration */
        while (elapsed_us < us)
        {
            status = system_get_elapsed_time_us_safe(start_tick, &elapsed_us);
            
            if (is_error(status))
            {
                /* Immediate exit if the timer crashes or stops mid-journey */
                break;
            }
        }
    }

    return status;
}


system_error_t system_delay_ms_safe(uint32_t ms)
{   
    return system_delay_us_safe(system_umul32(ms, 1000U));
}


/* ========================================================================== */
/* Non-blocking Delay Functions                                               */
/* ========================================================================== */

system_error_t system_delay_us_start_safe(uint32_t us)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (g_system_timer == NULL)
    {
        status = SYSTEM_ERROR_NOT_READY;
    }
    else if (g_delay.active)
    {
        status = SYSTEM_ERROR_BUSY; /* A delay is already underway. */
    }
    else
    {
        status = system_get_ticks_safe(&g_delay.start_time);

        if (is_success(status))
        {
            g_delay.duration_us = us;
            g_delay.active      = true;
        }
    }

    return status;
}


system_error_t system_delay_us_complete_safe(bool *is_complete)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (is_complete == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else if (!g_delay.active)
    {
        /* If no delay has been set, the condition is considered to be met. */
        *is_complete = true;
    }
    else
    {
        uint32_t elapsed_us = 0U;
        status = system_get_elapsed_time_us_safe(g_delay.start_time, &elapsed_us);

        if (is_success(status))
        {
            if (elapsed_us >= g_delay.duration_us)
            {
                *is_complete = true;
                g_delay.active = false; /* Free for next delay */
            }
            else
            {
                *is_complete = false;
            }
        }
    }

    return status;
}


/* ========================================================================== */
/* Legacy Functions (for compatibility)                                       */
/* ========================================================================== */

uint32_t system_get_ticks(void)
{
    uint32_t ticks = 0U;
    (void)system_get_ticks_safe(&ticks);
    return ticks;
}


uint32_t system_get_time_us(void)
{
    uint32_t time_us = 0U;
    (void)system_get_time_us_safe(&time_us);
    return time_us;
}


uint32_t system_get_elapsed_time_us(uint32_t previous_tick)
{
    uint32_t elapsed_us = 0U;
    (void)system_get_elapsed_time_us_safe(previous_tick, &elapsed_us);
    return elapsed_us;
}


void system_delay_us(uint32_t us)
{
    (void)system_delay_us_safe(us);
}


void system_delay_ms(uint32_t ms)
{
    (void)system_delay_ms_safe(ms);
}


bool system_delay_us_start(uint32_t us)
{
    return (system_delay_us_start_safe(us) == SYSTEM_SUCCESS);
}


bool system_delay_us_complete(void)
{
    bool is_complete = false;
    (void)system_delay_us_complete_safe(&is_complete);
    return is_complete;
}
