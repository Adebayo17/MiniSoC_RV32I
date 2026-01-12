/**
 * @file timer_usage.c
 * @brief TIMER Driver Test with Error Handling
 */

#include "../../include/system.h"
#include "../../include/errors.h"
#include "../../include/memory.h"
#include "../../drivers/uart/include/uart.h"
#include "../../drivers/timer/include/timer.h"


/**
 * @brief Test timer initialization
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_timer_init(void)
{
    timer_t timer_dev;
    system_error_t err;
    
    /* Test 1: Invalid parameters */
    err = timer_init(NULL, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (err != SYSTEM_ERROR_INVALID_PARAM) {
        return SYSTEM_ERROR_HARDWARE;
    }
    
    err = timer_init(&timer_dev, 0xDEADBEEF, SYSTEM_CLOCK_FREQ);
    if (err != SYSTEM_ERROR_INVALID_ADDRESS) {
        return SYSTEM_ERROR_HARDWARE;
    }
    
    err = timer_init(&timer_dev, TIMER_BASE_ADDRESS, 0);
    if (err != SYSTEM_ERROR_INVALID_PARAM) {
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test 2: Normal initialization */
    err = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Test 3: Double initialization */
    err = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (err != SYSTEM_ERROR_BUSY) {
        timer_deinit(&timer_dev);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Cleanup */
    err = timer_deinit(&timer_dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    return SYSTEM_SUCCESS;
}


/**
 * @brief Test timer configuration
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_timer_configuration(void)
{
    timer_t timer_dev;
    system_error_t err;
    
    err = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Test configuration */
    timer_config_t config = {
        .mode = TIMER_MODE_CONTINUOUS,
        .prescale = TIMER_PRESCALE_1,
        .compare_value = 1000000,
        .auto_reload = true
    };
    
    err = timer_configure(&timer_dev, &config);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    /* Test get configuration */
    timer_config_t read_config;
    err = timer_get_config(&timer_dev, &read_config);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    if (read_config.mode != config.mode ||
        read_config.prescale != config.prescale ||
        read_config.compare_value != config.compare_value) {
        timer_deinit(&timer_dev);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test individual configuration functions */
    err = timer_set_mode(&timer_dev, TIMER_MODE_ONESHOT);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    err = timer_set_prescaler(&timer_dev, TIMER_PRESCALE_8);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    err = timer_set_compare(&timer_dev, 500000);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    /* Cleanup */
    err = timer_deinit(&timer_dev);
    
    return err;
}


/**
 * @brief Test timer delay functions
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_timer_delay(void)
{
    timer_t timer_dev;
    system_error_t err;
    
    err = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Test microsecond delay */
    uint32_t start_ticks;
    err = timer_get_count(&timer_dev, &start_ticks);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    err = timer_delay_us(&timer_dev, 1000); /* 1ms */
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    uint32_t end_ticks;
    err = timer_get_count(&timer_dev, &end_ticks);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    uint32_t elapsed_ticks = end_ticks - start_ticks;
    uint32_t expected_ticks = SYSTEM_CLOCK_FREQ / 1000; /* 1ms worth of ticks */
    
    /* Allow 5% tolerance */
    uint32_t tolerance = expected_ticks / 20;
    if (elapsed_ticks < (expected_ticks - tolerance) || 
        elapsed_ticks > (expected_ticks + tolerance)) {
        timer_deinit(&timer_dev);
        return SYSTEM_ERROR_HARDWARE;
    }
    
    /* Test millisecond delay */
    err = timer_delay_ms(&timer_dev, 10); /* 10ms */
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    /* Cleanup */
    err = timer_deinit(&timer_dev);
    
    return err;
}


/**
 * @brief Test timer timeout functionality
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_timer_timeout(void)
{
    timer_t timer_dev;
    system_error_t err;
    
    err = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Test one-shot timeout */
    err = timer_start_timeout(&timer_dev, 100000, TIMER_MODE_ONESHOT); /* 100ms */
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    /* Check timeout status */
    bool timeout_occurred = false;
    while (!timeout_occurred) {
        err = timer_is_timeout(&timer_dev, &timeout_occurred);
        if (IS_ERROR(err)) {
            timer_deinit(&timer_dev);
            return err;
        }
    }
    
    /* Clear match flag */
    err = timer_clear_match(&timer_dev);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    /* Cleanup */
    err = timer_deinit(&timer_dev);
    
    return err;
}


/**
 * @brief Test timer status functions
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t test_timer_status(void)
{
    timer_t timer_dev;
    system_error_t err;
    
    err = timer_init(&timer_dev, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Test get count */
    uint32_t count;
    err = timer_get_count(&timer_dev, &count);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    /* Test get compare */
    uint32_t compare;
    err = timer_get_compare(&timer_dev, &compare);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    /* Test is running */
    bool is_running;
    err = timer_is_running(&timer_dev, &is_running);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    /* Test get status */
    timer_status_t status;
    err = timer_get_status(&timer_dev, &status);
    if (IS_ERROR(err)) {
        timer_deinit(&timer_dev);
        return err;
    }
    
    /* Cleanup */
    err = timer_deinit(&timer_dev);
    
    return err;
}


/**
 * @brief Main timer test function
 * @return SYSTEM_SUCCESS if all tests pass, error code otherwise
 */
int main(void)
{
    system_error_t err;
    system_init();
    
    err = test_timer_init();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_timer_configuration();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_timer_delay();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_timer_timeout();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    err = test_timer_status();
    if (IS_ERROR(err)) {
        return 1;
    }
    
    return 0;
}

