#include "timer.h"
#include <stdbool.h>

int main(void)
{
    timer_t timer0;
    
    /* Initialize timer with 50MHz clock frequency */
    timer_init(&timer0, TIMER_BASE_ADDRESS, 50000000u);
    
    /* Example 1: Simple timeout */
    timer_start_timeout(&timer0, 1000000u, TIMER_MODE_ONESHOT); /* 1 second timeout */
    
    while (!timer_is_timeout(&timer0)) {
        /* Wait for timeout */
    }
    timer_clear_match(&timer0);
    
    /* Example 2: Periodic interrupts using compare match */
    timer_configure(&timer0, TIMER_MODE_CONTINUOUS, TIMER_PRESCALE_1, 50000u); /* 1ms period @ 50MHz */
    timer_enable(&timer0);
    
    while (true) {
        if (timer_is_match(&timer0)) {
            /* 1ms period elapsed */
            timer_clear_match(&timer0);
            
            /* Do periodic task */
        }
        
        /* Check for overflow (optional) */
        if (timer_is_overflow(&timer0)) {
            timer_clear_overflow(&timer0);
        }
    }
    
    /* Example 3: Precise delays */
    timer_delay_ms(&timer0, 100);  /* Delay 100ms */
    timer_delay_us(&timer0, 500);  /* Delay 500us */
    
    /* Example 4: Measure elapsed time */
    timer_reset(&timer0);
    timer_enable(&timer0);
    
    /* Do some work... */
    
    uint32_t elapsed_ticks = timer_get_count(&timer0);
    uint32_t elapsed_us = (elapsed_ticks * 1000000u) / 50000000u; /* Convert to microseconds */
    
    return 0;
}