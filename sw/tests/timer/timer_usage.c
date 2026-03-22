/**
 * @file    timer_usage.c
 * @brief   TIMER Driver Test with Error Handling.
 * @details Conforms to the Barr Group Embedded C Coding Standard.
 */

#include "../../include/system.h"
#include "../../include/errors.h"
#include "../../include/memory.h"
#include "../../drivers/uart/include/uart.h"
#include "../../drivers/timer/include/timer.h"


/* ========================================================================== */
/* TIMER Test Functions                                                       */
/* ========================================================================== */

/**
 * @brief  Test timer initialization.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_timer_init(void)
{
    timer_t timer_dev;
    system_error_t status = SYSTEM_SUCCESS;
    system_error_t test_err;
    
    /* Test 1: Invalid parameters (NULL pointer) */
    test_err = timer_init(NULL, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (test_err != SYSTEM_ERROR_INVALID_PARAM) 
    {
        status = SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test 2: Invalid hardware address */
    if (is_success(status))
    {
        test_err = timer_init(&timer_dev, 0xDEADBEEFUL, SYSTEM_CLOCK_FREQ);
        if (test_err != SYSTEM_ERROR_INVALID_ADDRESS) 
        {
            status = SYSTEM_ERROR_HARDWARE;
        }
    }
    
    /* Test 3: Invalid Clock Frequency (0 Hz) */
    if (is_success(status))
    {
        test_err = timer_init(&timer_dev, TIMER_BASE_ADDRESS, 0U);
        if (test_err != SYSTEM_ERROR_INVALID_PARAM) 
        {
            status = SYSTEM_ERROR_HARDWARE;
        }
    }
    
    /* Test 4: Normal initialization */
    if (is_success(status))
    {
        status = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    }
    
    /* Cleanup (Safe to call even if init failed) */
    (void)timer_deinit(&timer_dev);
    
    return status;
}


/**
 * @brief  Test timer configuration.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_timer_configuration(void)
{
    timer_t timer_dev;
    system_error_t status = SYSTEM_SUCCESS;
    
    status = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    
    if (is_success(status)) 
    {
        /* Test configuration */
        timer_config_t config;
        config.mode          = TIMER_MODE_CONTINUOUS;
        config.prescale      = TIMER_PRESCALE_1;
        config.compare_value = 1000000U;
        
        status = timer_configure(&timer_dev, &config);
        
        /* Test get configuration */
        if (is_success(status)) 
        {
            timer_config_t read_config;
            status = timer_get_config(&timer_dev, &read_config);
            
            if (is_success(status)) 
            {
                if ((read_config.mode != config.mode) ||
                    (read_config.prescale != config.prescale) ||
                    (read_config.compare_value != config.compare_value)) 
                {
                    status = SYSTEM_ERROR_HARDWARE;
                }
            }
        }
    }
    
    /* Test individual configuration functions */
    if (is_success(status)) status = timer_set_mode(&timer_dev, TIMER_MODE_ONESHOT);
    if (is_success(status)) status = timer_set_prescaler(&timer_dev, TIMER_PRESCALE_8);
    if (is_success(status)) status = timer_set_compare(&timer_dev, 500000U);
    
    /* Cleanup */
    (void)timer_deinit(&timer_dev);
    
    return status;
}


/**
 * @brief  Test timer delay functions.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_timer_delay(void)
{
    timer_t timer_dev;
    system_error_t status = SYSTEM_SUCCESS;
    
    status = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    
    if (is_success(status)) 
    {
        /* Test microsecond delay (1ms total) */
        status = timer_delay_us(&timer_dev, 1000U); 
    }
    
    if (is_success(status)) 
    {
        /* Test millisecond delay (10ms total) */
        status = timer_delay_ms(&timer_dev, 10U); 
    }
    
    /* Cleanup */
    (void)timer_deinit(&timer_dev);
    
    return status;
}


/**
 * @brief  Test timer timeout functionality (non-blocking simulation).
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_timer_timeout(void)
{
    timer_t timer_dev;
    system_error_t status = SYSTEM_SUCCESS;
    
    status = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    
    if (is_success(status)) 
    {
        /* Test one-shot timeout (100ms) */
        status = timer_start_timeout(&timer_dev, 100000U, TIMER_MODE_ONESHOT); 
    }
    
    if (is_success(status)) 
    {
        /* Check timeout status in a blocking loop (polling) */
        bool timeout_occurred = false;
        
        while (!timeout_occurred && is_success(status)) 
        {
            status = timer_is_timeout(&timer_dev, &timeout_occurred);
        }
    }
    
    if (is_success(status)) 
    {
        /* Clear match flag */
        status = timer_clear_match(&timer_dev);
    }
    
    /* Cleanup */
    (void)timer_deinit(&timer_dev);
    
    return status;
}


/**
 * @brief  Test timer status functions.
 * @return SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t test_timer_status(void)
{
    timer_t timer_dev;
    system_error_t status = SYSTEM_SUCCESS;
    
    status = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    
    if (is_success(status)) 
    {
        uint32_t count = 0U;
        status = timer_get_count(&timer_dev, &count);
    }
    
    if (is_success(status)) 
    {
        uint32_t compare = 0U;
        status = timer_get_compare(&timer_dev, &compare);
    }
    
    if (is_success(status)) 
    {
        bool is_running = false;
        status = timer_is_running(&timer_dev, &is_running);
    }
    
    if (is_success(status)) 
    {
        timer_status_t timer_stat;
        status = timer_get_status(&timer_dev, &timer_stat);
    }
    
    /* Cleanup */
    (void)timer_deinit(&timer_dev);
    
    return status;
}


/* ========================================================================== */
/* Main Test Runner                                                           */
/* ========================================================================== */

/**
 * @brief  Main timer test function.
 * @return 0 if all tests pass, 1 otherwise.
 */
int main(void)
{
    system_error_t status = SYSTEM_SUCCESS;
    int ret_val = 0;
    
    system_init();
    
    /* Run Tests sequentially, stop if one fails */
    status = test_timer_init();
    
    if (is_success(status)) status = test_timer_configuration();
    if (is_success(status)) status = test_timer_delay();
    if (is_success(status)) status = test_timer_timeout();
    if (is_success(status)) status = test_timer_status();
    
    /* Set return value based on final status */
    if (is_error(status)) 
    {
        ret_val = 1;
    }
    
    return ret_val;
}
