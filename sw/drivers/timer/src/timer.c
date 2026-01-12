/*
 * @file timer.c
 * @brief Timer Driver Implementation
 */

#include "../include/timer.h"
#include "../../../include/system.h"
#include "../../../include/peripheral.h"
#include <stddef.h>


/* ========================================================================== */
/* Private Helper Functions                                                   */
/* ========================================================================== */

/**
 * @brief Update timer status from hardware registers
 * @param dev Pointer to timer structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t timer_update_status(timer_t *dev)
{
    if (dev == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    /* Read status register */
    uint32_t status_reg = READ_REG(dev->base.base_address + REG_TIMER_STATUS_OFFSET);
    
    /* Update status structure */
    dev->status.match_occurred = (status_reg & TIMER_STATUS_MATCH_BIT) != 0;
    dev->status.overflow_occurred = (status_reg & TIMER_STATUS_OVERFLOW_BIT) != 0;
    
    /* Read control register to get current mode and prescale */
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET);
    dev->status.is_running = (ctrl_reg & TIMER_CTRL_ENABLE_BIT) != 0;
    dev->status.is_oneshot = (ctrl_reg & TIMER_CTRL_ONESHOT_BIT) != 0;
    dev->status.prescale = (timer_prescale_t)((ctrl_reg & TIMER_CTRL_PRESCALE_MASK) >> TIMER_CTRL_PRESCALE_POS);
    
    /* Read current count and compare values */
    dev->status.count_value = READ_REG(dev->base.base_address + REG_TIMER_COUNT_OFFSET);
    dev->status.compare_value = READ_REG(dev->base.base_address + REG_TIMER_CMP_OFFSET);
    
    return SYSTEM_SUCCESS;
}


/**
 * @brief Validate compare value
 * @param compare_value Compare value to validate
 * @return SYSTEM_SUCCESS if valid, error code otherwise
 */
static system_error_t validate_compare_value(uint32_t compare_value)
{
    if (compare_value == 0) {
        return SYSTEM_ERROR_INVALID_PARAM; /* Compare value of 0 would match immediately */
    }
    
    if (compare_value > TIMER_MAX_VALUE) {
        return SYSTEM_ERROR_INVALID_PARAM; /* Exceeds maximum timer value */
    }
    
    return SYSTEM_SUCCESS;
}


/**
 * @brief Calculate timeout based on compare value and prescaler
 * @param dev Pointer to timer structure
 * @param compare_value Compare value
 * @param timeout_us Pointer to store calculated timeout in microseconds
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t timer_calculate_timeout(timer_t *dev, uint32_t compare_value, uint32_t *timeout_us)
{
    if (dev == NULL || timeout_us == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    if (!dev->base.initialized) {
        return SYSTEM_ERROR_NOT_READY;
    }
    
    if (dev->clock_frequency == 0) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Get current prescaler divisor */
    uint32_t prescaler_div = timer_prescale_to_divisor(dev->status.prescale);
    
    /* Calculate timer period in seconds */
    /* ticks = compare_value * prescaler_div / clock_frequency */
    
    /* To avoid floating point, calculate in microseconds */
    uint64_t ticks_per_us = (uint64_t)dev->clock_frequency / 1000000ULL;
    if (ticks_per_us == 0) {
        ticks_per_us = 1; /* Minimum 1 tick per microsecond */
    }
    
    uint64_t effective_ticks = (uint64_t)compare_value * (uint64_t)prescaler_div;
    uint64_t timeout = effective_ticks / ticks_per_us;
    
    if (timeout > 0xFFFFFFFFu) {
        *timeout_us = 0xFFFFFFFFu; /* Cap at maximum */
    } else {
        *timeout_us = (uint32_t)timeout;
    }
    
    return SYSTEM_SUCCESS;
}


/* ========================================================================== */
/* Public Timer Functions                                                     */
/* ========================================================================== */

system_error_t timer_init(timer_t *dev, uint32_t base_addr, uint32_t clock_freq)
{
    PARAM_CHECK_NOT_NULL(dev);
    
    /* Validate base address */
    if (!IS_TIMER_ADDRESS(base_addr)) {
        return SYSTEM_ERROR_INVALID_ADDRESS;
    }
    
    if (clock_freq == 0) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Check if already initialized */
    bool is_initialized = false;
    system_error_t err = peripheral_is_initialized(&dev->base, &is_initialized);
    if (IS_ERROR(err)) {
        return err;
    }
    
    if (is_initialized) {
        return SYSTEM_ERROR_BUSY;
    }
    
    /* Initialize base peripheral */
    err = peripheral_init(&dev->base, base_addr);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Store clock frequency */
    dev->clock_frequency = clock_freq;
    
    /* Initialize configuration to defaults */
    dev->config.mode = TIMER_MODE_CONTINUOUS;
    dev->config.prescale = TIMER_PRESCALE_1;
    dev->config.compare_value = TIMER_MAX_VALUE; /* Maximum by default */
    dev->config.auto_reload = true;
    
    /* Initialize status */
    system_memset(&dev->status, 0, sizeof(dev->status));
    dev->status.prescale = TIMER_PRESCALE_1;
    dev->status.compare_value = TIMER_MAX_VALUE;
    dev->is_initialized = true;
    
    /* Disable timer and reset to known state */
    err = timer_disable(dev);
    if (IS_ERROR(err)) {
        peripheral_deinit(&dev->base);
        return err;
    }
    
    err = timer_reset(dev);
    if (IS_ERROR(err)) {
        peripheral_deinit(&dev->base);
        return err;
    }
    
    err = timer_clear_status(dev);
    if (IS_ERROR(err)) {
        peripheral_deinit(&dev->base);
        return err;
    }
    
    /* Set default configuration */
    err = timer_set_prescaler(dev, TIMER_PRESCALE_1);
    if (IS_ERROR(err)) {
        peripheral_deinit(&dev->base);
        return err;
    }
    
    err = timer_set_mode(dev, TIMER_MODE_CONTINUOUS);
    if (IS_ERROR(err)) {
        peripheral_deinit(&dev->base);
        return err;
    }
    
    err = timer_set_compare(dev, TIMER_MAX_VALUE);
    if (IS_ERROR(err)) {
        peripheral_deinit(&dev->base);
        return err;
    }
    
    /* Update status */
    return timer_update_status(dev);
}


system_error_t timer_deinit(timer_t *dev)
{
    PARAM_CHECK_NOT_NULL(dev);
    
    /* Disable timer before deinitialization */
    system_error_t err = timer_disable(dev);
    if (IS_ERROR(err) && err != SYSTEM_ERROR_NOT_READY) {
        /* Continue deinitialization even if disable fails */
    }
    
    /* Reset timer to default state */
    err = timer_reset_to_defaults(dev);
    if (IS_ERROR(err) && err != SYSTEM_ERROR_NOT_READY) {
        /* Continue deinitialization */
    }
    
    /* Clear driver state */
    dev->clock_frequency = 0;
    system_memset(&dev->config, 0, sizeof(dev->config));
    system_memset(&dev->status, 0, sizeof(dev->status));
    dev->is_initialized = false;
    
    /* Deinitialize base peripheral */
    return peripheral_deinit(&dev->base);
}


system_error_t timer_configure(timer_t *dev, const timer_config_t *config)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, config);
    
    /* Validate configuration */
    system_error_t err = timer_validate_config(config);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Disable timer during configuration */
    bool was_running = false;
    err = timer_is_running(dev, &was_running);
    if (IS_ERROR(err)) {
        return err;
    }
    
    if (was_running) {
        err = timer_disable(dev);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    /* Apply configuration */
    err = timer_set_mode(dev, config->mode);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    err = timer_set_prescaler(dev, config->prescale);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    err = timer_set_compare(dev, config->compare_value);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    /* Store configuration */
    dev->config = *config;
    
    /* Clear any pending status */
    err = timer_clear_status(dev);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    /* Reset timer counter */
    err = timer_reset(dev);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    /* Re-enable timer if it was running */
    if (was_running) {
        err = timer_enable(dev);
        if (IS_ERROR(err)) {
            goto cleanup;
        }
    }
    
    /* Update status */
    return timer_update_status(dev);
    
cleanup:
    /* Try to restore previous state on error */
    if (was_running) {
        timer_enable(dev); /* Ignore error */
    }
    return err;
}


system_error_t timer_get_config(timer_t *dev, timer_config_t *config)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, config);
    
    /* Copy configuration */
    *config = dev->config;
    
    /* Update from current hardware state */
    system_error_t err = timer_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    config->mode = dev->status.is_oneshot ? TIMER_MODE_ONESHOT : TIMER_MODE_CONTINUOUS;
    config->prescale = dev->status.prescale;
    config->compare_value = dev->status.compare_value;
    
    return SYSTEM_SUCCESS;
}


system_error_t timer_enable(timer_t *dev)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Check if already enabled */
    bool is_running = false;
    system_error_t err = timer_is_running(dev, &is_running);
    if (IS_ERROR(err)) {
        return err;
    }
    
    if (is_running) {
        return SYSTEM_SUCCESS; /* Already enabled */
    }
    
    /* Set enable bit */
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET);
    ctrl_reg |= TIMER_CTRL_ENABLE_BIT;
    WRITE_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET, ctrl_reg);
    
    /* Update configuration */
    dev->config.mode = dev->status.is_oneshot ? TIMER_MODE_ONESHOT : TIMER_MODE_CONTINUOUS;
    
    /* Update status */
    return timer_update_status(dev);
}


system_error_t timer_disable(timer_t *dev)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Check if already disabled */
    bool is_running = false;
    system_error_t err = timer_is_running(dev, &is_running);
    if (IS_ERROR(err)) {
        return err;
    }
    
    if (!is_running) {
        return SYSTEM_SUCCESS; /* Already disabled */
    }
    
    /* Clear enable bit */
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET);
    ctrl_reg &= ~TIMER_CTRL_ENABLE_BIT;
    WRITE_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET, ctrl_reg);
    
    /* Update status */
    return timer_update_status(dev);
}


system_error_t timer_reset(timer_t *dev)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Set reset bit */
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET);
    ctrl_reg |= TIMER_CTRL_RESET_BIT;
    WRITE_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET, ctrl_reg);
    
    /* Clear reset bit (reset is edge-triggered) */
    ctrl_reg &= ~TIMER_CTRL_RESET_BIT;
    WRITE_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET, ctrl_reg);
    
    /* Update status */
    return timer_update_status(dev);
}


system_error_t timer_set_mode(timer_t *dev, timer_mode_t mode)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET);
    
    if (mode == TIMER_MODE_ONESHOT) {
        ctrl_reg |= TIMER_CTRL_ONESHOT_BIT;
    } else {
        ctrl_reg &= ~TIMER_CTRL_ONESHOT_BIT;
    }
    
    WRITE_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET, ctrl_reg);
    
    /* Update configuration */
    dev->config.mode = mode;
    
    /* Update status */
    return timer_update_status(dev);
}


system_error_t timer_set_prescaler(timer_t *dev, timer_prescale_t prescale)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Validate prescaler value */
    if (prescale > TIMER_PRESCALE_1024) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    uint32_t ctrl_reg = READ_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET);
    
    /* Clear current prescaler bits */
    ctrl_reg &= ~TIMER_CTRL_PRESCALE_MASK;
    
    /* Set new prescaler value */
    ctrl_reg |= ((prescale & 0x3u) << TIMER_CTRL_PRESCALE_POS);
    
    WRITE_REG(dev->base.base_address + REG_TIMER_CTRL_OFFSET, ctrl_reg);
    
    /* Update configuration */
    dev->config.prescale = prescale;
    
    /* Update status */
    return timer_update_status(dev);
}


system_error_t timer_get_count(timer_t *dev, uint32_t *count_value)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, count_value);
    
    /* Update status from hardware */
    system_error_t err = timer_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *count_value = dev->status.count_value;
    
    return SYSTEM_SUCCESS;
}


system_error_t timer_set_compare(timer_t *dev, uint32_t compare_value)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Validate compare value */
    system_error_t err = validate_compare_value(compare_value);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Write compare value */
    WRITE_REG(dev->base.base_address + REG_TIMER_CMP_OFFSET, compare_value);
    
    /* Update configuration */
    dev->config.compare_value = compare_value;
    
    /* Update status */
    return timer_update_status(dev);
}


system_error_t timer_get_compare(timer_t *dev, uint32_t *compare_value)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, compare_value);
    
    /* Update status from hardware */
    system_error_t err = timer_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *compare_value = dev->status.compare_value;
    
    return SYSTEM_SUCCESS;
}


system_error_t timer_is_match(timer_t *dev, bool *match_occurred)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, match_occurred);
    
    /* Update status from hardware */
    system_error_t err = timer_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *match_occurred = dev->status.match_occurred;
    
    return SYSTEM_SUCCESS;
}


system_error_t timer_is_overflow(timer_t *dev, bool *overflow_occurred)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, overflow_occurred);
    
    /* Update status from hardware */
    system_error_t err = timer_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *overflow_occurred = dev->status.overflow_occurred;
    
    return SYSTEM_SUCCESS;
}


system_error_t timer_clear_match(timer_t *dev)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    uint32_t status_reg = READ_REG(dev->base.base_address + REG_TIMER_STATUS_OFFSET);
    status_reg &= ~TIMER_STATUS_MATCH_BIT;
    WRITE_REG(dev->base.base_address + REG_TIMER_STATUS_OFFSET, status_reg);
    
    /* Update status */
    return timer_update_status(dev);
}


system_error_t timer_clear_overflow(timer_t *dev)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    uint32_t status_reg = READ_REG(dev->base.base_address + REG_TIMER_STATUS_OFFSET);
    status_reg &= ~TIMER_STATUS_OVERFLOW_BIT;
    WRITE_REG(dev->base.base_address + REG_TIMER_STATUS_OFFSET, status_reg);
    
    /* Update status */
    return timer_update_status(dev);
}


system_error_t timer_clear_status(timer_t *dev)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    WRITE_REG(dev->base.base_address + REG_TIMER_STATUS_OFFSET, 0x00u);
    
    /* Update status */
    return timer_update_status(dev);
}


system_error_t timer_get_status(timer_t *dev, timer_status_t *status)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, status);
    
    /* Update status from hardware */
    system_error_t err = timer_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Copy status */
    *status = dev->status;
    
    return SYSTEM_SUCCESS;
}


system_error_t timer_calculate_compare_value(timer_t *dev, uint32_t timeout_us, uint32_t *compare_value)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, compare_value);
    
    if (timeout_us == 0) {
        *compare_value = 1; /* Minimum compare value */
        return SYSTEM_SUCCESS;
    }
    
    if (dev->clock_frequency == 0) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Get current prescaler divisor */
    uint32_t prescaler_div = timer_prescale_to_divisor(dev->status.prescale);
    
    /* Calculate required ticks */
    /* timeout_us = compare_value * prescaler_div * 1,000,000 / clock_frequency */
    /* compare_value = timeout_us * clock_frequency / (prescaler_div * 1,000,000) */
    
    uint64_t numerator = (uint64_t)timeout_us * (uint64_t)dev->clock_frequency;
    uint64_t denominator = (uint64_t)prescaler_div * 1000000ULL;
    
    if (denominator == 0) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    uint64_t calculated_value = numerator / denominator;
    
    /* Add 1 to ensure we don't under-count due to integer division */
    calculated_value += 1;
    
    if (calculated_value > TIMER_MAX_VALUE) {
        *compare_value = TIMER_MAX_VALUE;
        return SYSTEM_SUCCESS;
    }
    
    if (calculated_value == 0) {
        *compare_value = 1; /* Minimum compare value */
    } else {
        *compare_value = (uint32_t)calculated_value;
    }
    
    /* Validate the calculated value */
    return validate_compare_value(*compare_value);
}


system_error_t timer_start_timeout(timer_t *dev, uint32_t timeout_us, timer_mode_t mode)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Calculate compare value for timeout */
    uint32_t compare_value;
    system_error_t err = timer_calculate_compare_value(dev, timeout_us, &compare_value);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Disable timer during configuration */
    bool was_running = false;
    err = timer_is_running(dev, &was_running);
    if (IS_ERROR(err)) {
        return err;
    }
    
    if (was_running) {
        err = timer_disable(dev);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    /* Configure timer for timeout */
    err = timer_set_mode(dev, mode);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    err = timer_set_compare(dev, compare_value);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    err = timer_clear_status(dev);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    err = timer_reset(dev);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    /* Enable timer */
    err = timer_enable(dev);
    if (IS_ERROR(err)) {
        goto cleanup;
    }
    
    return SYSTEM_SUCCESS;
    
cleanup:
    /* Try to restore previous state */
    if (was_running) {
        timer_enable(dev); /* Ignore error */
    }
    return err;
}


system_error_t timer_is_timeout(timer_t *dev, bool *timeout_occurred)
{
    return timer_is_match(dev, timeout_occurred);
}


system_error_t timer_delay_us(timer_t *dev, uint32_t delay_us)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    if (delay_us == 0) {
        return SYSTEM_SUCCESS; /* No delay needed */
    }
    
    /* Start one-shot timeout */
    system_error_t err = timer_start_timeout(dev, delay_us, TIMER_MODE_ONESHOT);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Busy wait until timeout */
    bool timeout_occurred = false;
    do {
        err = timer_is_timeout(dev, &timeout_occurred);
        if (IS_ERROR(err)) {
            return err;
        }
    } while (!timeout_occurred);
    
    /* Clear match flag */
    return timer_clear_match(dev);
}


system_error_t timer_delay_ms(timer_t *dev, uint32_t delay_ms)
{
    /* Convert milliseconds to microseconds */
    if (delay_ms > (0xFFFFFFFFu / 1000u)) {
        return SYSTEM_ERROR_INVALID_PARAM; /* Would overflow */
    }
    
    return timer_delay_us(dev, delay_ms * 1000u);
}


system_error_t timer_reset_to_defaults(timer_t *dev)
{
    PERIPHERAL_CHECK_VALID(dev);
    
    /* Disable timer */
    system_error_t err = timer_disable(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Reset to default configuration */
    timer_config_t default_config = {
        .mode = TIMER_MODE_CONTINUOUS,
        .prescale = TIMER_PRESCALE_1,
        .compare_value = TIMER_MAX_VALUE,
        .auto_reload = true
    };
    
    err = timer_configure(dev, &default_config);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Clear status */
    return timer_clear_status(dev);
}


system_error_t timer_validate_config(const timer_config_t *config)
{
    PARAM_CHECK_NOT_NULL(config);
    
    /* Validate prescaler */
    if (config->prescale > TIMER_PRESCALE_1024) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    /* Validate compare value */
    system_error_t err = validate_compare_value(config->compare_value);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* For one-shot mode with auto_reload, warn but don't fail */
    if (config->mode == TIMER_MODE_ONESHOT && config->auto_reload) {
        /* This is unusual but not invalid */
    }
    
    return SYSTEM_SUCCESS;
}


system_error_t timer_is_running(timer_t *dev, bool *is_running)
{
    PERIPHERAL_AND_PARAM_CHECK(dev, is_running);
    
    /* Update status from hardware */
    system_error_t err = timer_update_status(dev);
    if (IS_ERROR(err)) {
        return err;
    }
    
    *is_running = dev->status.is_running;
    
    return SYSTEM_SUCCESS;
}