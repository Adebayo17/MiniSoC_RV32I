/*
 * @file    timer.c
 * @brief   Timer Driver Implementation.
 * @details Conforms to the Barr Group Embedded C Coding Standard.
 */

#include "../include/timer.h"
#include "timer_hw.h"
#include "../../../include/math.h"
#include <stddef.h>


/* ========================================================================== */
/* Private Helper Functions                                                   */
/* ========================================================================== */

/**
 * @brief   Gets the hardware structure (registers) based on the TIMER handle.
 * @param   [in] dev Pointer to TIMER structure.
 * @return  Pointer to TIMER hardware registers, or NULL if invalid handle.
 */
static inline timer_regs_t* timer_get_hw_regs(const timer_t *dev)
{
    return (timer_regs_t *)(dev->base.base_address);
}


/**
 * @brief   Convert prescaler enum to actual divisor value
 * @param   [in] prescale Prescaler register value
 * @return  Actual divisor (1, 8, 64, or 1024)
 */
static inline uint32_t timer_prescale_to_divisor(timer_prescale_t prescale) {
    uint32_t divisor = 1U;
    switch (prescale) 
    {
        case TIMER_PRESCALE_1:    divisor = 1U;    break;
        case TIMER_PRESCALE_8:    divisor = 8U;    break;
        case TIMER_PRESCALE_64:   divisor = 64U;   break;
        case TIMER_PRESCALE_1024: divisor = 1024U; break;
        default:                  divisor = 1U;    break;
    }
    return divisor;
}


/* ========================================================================== */
/* Initialization                                                             */
/* ========================================================================== */

system_error_t timer_init(timer_t *dev, uint32_t base_addr, uint32_t clock_freq)
{
    system_error_t status = SYSTEM_SUCCESS;

    if ((dev == NULL) || (clock_freq == 0U))
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_init(timer_to_peripheral(dev), base_addr);

        if (is_success(status))
        {
            dev->clock_frequency = clock_freq;
            
            /* Hardware Reset */
            timer_regs_t *hw = timer_get_hw_regs(dev);
            hw->CTRL = TIMER_CTRL_RESET_BIT;
            
            /* Clear Status (Write-1-to-Clear) */
            hw->STATUS = (TIMER_STATUS_MATCH_BIT | TIMER_STATUS_OVERFLOW_BIT);

            /* Software context initialization */
            dev->config.mode          = TIMER_MODE_CONTINUOUS;
            dev->config.prescale      = TIMER_PRESCALE_1;
            dev->config.compare_value = TIMER_MAX_VALUE;

            dev->status.match_occurred    = false;
            dev->status.overflow_occurred = false;
            dev->status.is_running        = false;
            dev->status.is_oneshot        = false;
            dev->status.prescale          = TIMER_PRESCALE_1;
            dev->status.count_value       = 0U;
            dev->status.compare_value     = TIMER_MAX_VALUE;
        }
    }

    return status;
}


system_error_t timer_deinit(timer_t *dev)
{
    system_error_t status = peripheral_check_valid(timer_to_peripheral(dev));

    if (is_success(status))
    {
        timer_regs_t *hw = timer_get_hw_regs(dev);
        hw->CTRL = 0U; /* Timer stop */
        
        status = peripheral_deinit(timer_to_peripheral(dev));
    }

    return status;
}


system_error_t timer_reset(timer_t *dev)
{
    system_error_t status = peripheral_check_valid(timer_to_peripheral(dev));

    if (is_success(status))
    {
        timer_regs_t *hw = timer_get_hw_regs(dev);
        
        /* Auto-clearing reset pulse in Verilog */
        hw->CTRL |= TIMER_CTRL_RESET_BIT;
        
        /* W1C sur les flags d'erreur */
        hw->STATUS = (TIMER_STATUS_MATCH_BIT | TIMER_STATUS_OVERFLOW_BIT);

        dev->status.match_occurred    = false;
        dev->status.overflow_occurred = false;
        dev->status.count_value       = 0U;
    }

    return status;
}


/* ========================================================================== */
/* Configuration & Control                                                    */
/* ========================================================================== */

system_error_t timer_configure(timer_t *dev, const timer_config_t *config)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (config == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(timer_to_peripheral(dev));

        if (is_success(status))
        {
            /* Stopping Timer before configuration*/
            (void)timer_disable(dev);

            timer_regs_t *hw = timer_get_hw_regs(dev);

            uint32_t ctrl_val = 0U;
            
            if (config->mode == TIMER_MODE_ONESHOT)
            {
                ctrl_val |= TIMER_CTRL_ONESHOT_BIT;
                dev->status.is_oneshot = true;
            }
            else
            {
                dev->status.is_oneshot = false;
            }

            ctrl_val |= ((uint32_t)config->prescale << TIMER_CTRL_PRESCALE_POS);
            
            hw->CMP  = config->compare_value;
            hw->CTRL = ctrl_val; /* Timer is still disabled */

            /* Update Cache */
            dev->config                 = *config;
            dev->status.prescale        = config->prescale;
            dev->status.compare_value   = config->compare_value;
        }
    }

    return status;
}


system_error_t timer_get_config(timer_t *dev, timer_config_t *config)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (config == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(timer_to_peripheral(dev));

        if (is_success(status))
        {
            *config = dev->config;
        }
    }

    return status;
}


system_error_t timer_enable(timer_t *dev)
{
    system_error_t status = peripheral_check_valid(timer_to_peripheral(dev));

    if (is_success(status))
    {
        timer_regs_t *hw = timer_get_hw_regs(dev);
        hw->CTRL |= TIMER_CTRL_ENABLE_BIT;
        dev->status.is_running = true;
    }

    return status;
}


system_error_t timer_disable(timer_t *dev)
{
    system_error_t status = peripheral_check_valid(timer_to_peripheral(dev));

    if (is_success(status))
    {
        timer_regs_t *hw = timer_get_hw_regs(dev);
        hw->CTRL &= ~TIMER_CTRL_ENABLE_BIT;
        dev->status.is_running = false;
    }

    return status;
}


system_error_t timer_set_mode(timer_t *dev, timer_mode_t mode)
{
    system_error_t status = peripheral_check_valid(timer_to_peripheral(dev));

    if (is_success(status))
    {
        timer_regs_t *hw = timer_get_hw_regs(dev);

        if (mode == TIMER_MODE_ONESHOT)
        {
            hw->CTRL |= TIMER_CTRL_ONESHOT_BIT;
            dev->status.is_oneshot = true;
        }
        else
        {
            hw->CTRL &= ~TIMER_CTRL_ONESHOT_BIT;
            dev->status.is_oneshot = false;
        }

        dev->config.mode = mode;
    }

    return status;
}


system_error_t timer_set_prescaler(timer_t *dev, timer_prescale_t prescale)
{
    system_error_t status = peripheral_check_valid(timer_to_peripheral(dev));

    if (is_success(status))
    {
        timer_regs_t *hw = timer_get_hw_regs(dev);
        
        /* Read-Modify-Write (RMW) sur le registre CTRL pour ne pas écraser ENABLE/ONESHOT */
        uint32_t ctrl_val = hw->CTRL;
        ctrl_val &= ~TIMER_CTRL_PRESCALE_MASK;
        ctrl_val |= ((uint32_t)prescale << TIMER_CTRL_PRESCALE_POS);
        hw->CTRL = ctrl_val;

        dev->config.prescale = prescale;
        dev->status.prescale = prescale;
    }

    return status;
}


system_error_t timer_set_compare(timer_t *dev, uint32_t compare_value)
{
    system_error_t status = peripheral_check_valid(timer_to_peripheral(dev));

    if (is_success(status))
    {
        timer_regs_t *hw = timer_get_hw_regs(dev);
        hw->CMP = compare_value;

        dev->config.compare_value = compare_value;
        dev->status.compare_value = compare_value;
    }

    return status;
}


system_error_t timer_get_compare(timer_t *dev, uint32_t *compare_value)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (compare_value == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(timer_to_peripheral(dev));

        if (is_success(status))
        {
            timer_regs_t *hw = timer_get_hw_regs(dev);
            
            *compare_value = hw->CMP;
            dev->status.compare_value = *compare_value; /* Rafraichissement cache */
        }
    }

    return status;
}


/* ========================================================================== */
/* Runtime Queries (Getters)                                                  */
/* ========================================================================== */

system_error_t timer_get_count(timer_t *dev, uint32_t *count_value)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (count_value == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(timer_to_peripheral(dev));

        if (is_success(status))
        {
            timer_regs_t *hw = timer_get_hw_regs(dev);
            *count_value = hw->COUNT;
            dev->status.count_value = *count_value; /* Update cache */
        }
    }

    return status;
}


system_error_t timer_is_match(timer_t *dev, bool *match_occurred)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (match_occurred == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(timer_to_peripheral(dev));

        if (is_success(status))
        {
            timer_regs_t *hw = timer_get_hw_regs(dev);
            *match_occurred = ((hw->STATUS & TIMER_STATUS_MATCH_BIT) != 0U);
            dev->status.match_occurred = *match_occurred;
        }
    }

    return status;
}


system_error_t timer_is_overflow(timer_t *dev, bool *overflow_occurred)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (overflow_occurred == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(timer_to_peripheral(dev));

        if (is_success(status))
        {
            timer_regs_t *hw = timer_get_hw_regs(dev);
            *overflow_occurred = ((hw->STATUS & TIMER_STATUS_OVERFLOW_BIT) != 0U);
            dev->status.overflow_occurred = *overflow_occurred;
        }
    }

    return status;
}


system_error_t timer_is_running(timer_t *dev, bool *is_running)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (is_running == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(timer_to_peripheral(dev));

        if (is_success(status))
        {
            timer_regs_t *hw = timer_get_hw_regs(dev);
            *is_running = ((hw->CTRL & TIMER_CTRL_ENABLE_BIT) != 0U);
            dev->status.is_running = *is_running;
        }
    }

    return status;
}


/* ========================================================================== */
/* Status Clearing (Write-1-To-Clear)                                         */
/* ========================================================================== */

system_error_t timer_clear_match(timer_t *dev)
{
    system_error_t status = peripheral_check_valid(timer_to_peripheral(dev));

    if (is_success(status))
    {
        timer_regs_t *hw = timer_get_hw_regs(dev);
        hw->STATUS = TIMER_STATUS_MATCH_BIT;
        dev->status.match_occurred = false;
    }

    return status;
}


system_error_t timer_clear_overflow(timer_t *dev)
{
    system_error_t status = peripheral_check_valid(timer_to_peripheral(dev));

    if (is_success(status))
    {
        timer_regs_t *hw = timer_get_hw_regs(dev);
        hw->STATUS = TIMER_STATUS_OVERFLOW_BIT;
        dev->status.overflow_occurred = false;
    }

    return status;
}


system_error_t timer_clear_status(timer_t *dev)
{
    system_error_t status = peripheral_check_valid(timer_to_peripheral(dev));

    if (is_success(status))
    {
        timer_regs_t *hw = timer_get_hw_regs(dev);
        /* Clear all flags */
        hw->STATUS = (TIMER_STATUS_MATCH_BIT | TIMER_STATUS_OVERFLOW_BIT);
        dev->status.match_occurred = false;
        dev->status.overflow_occurred = false;
    }

    return status;
}


system_error_t timer_get_status(timer_t *dev, timer_status_t *status_out)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (status_out == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(timer_to_peripheral(dev));

        if (is_success(status))
        {
            timer_regs_t *hw = timer_get_hw_regs(dev);
            
            /* Global refresh of variables from the hardware */
            uint32_t hw_status = hw->STATUS;
            uint32_t hw_ctrl   = hw->CTRL;

            dev->status.count_value       = hw->COUNT;
            dev->status.compare_value     = hw->CMP;
            dev->status.match_occurred    = ((hw_status & TIMER_STATUS_MATCH_BIT) != 0U);
            dev->status.overflow_occurred = ((hw_status & TIMER_STATUS_OVERFLOW_BIT) != 0U);
            dev->status.is_running        = ((hw_ctrl & TIMER_CTRL_ENABLE_BIT) != 0U);
            dev->status.is_oneshot        = ((hw_ctrl & TIMER_CTRL_ONESHOT_BIT) != 0U);

            /* Assign the refresh status to the output */
            *status_out = dev->status;
        }
    }

    return status;
}


/* ========================================================================== */
/* High-Level Timing (Delays)                                                 */
/* ========================================================================== */

system_error_t timer_calculate_compare_value(timer_t *dev, uint32_t timeout_us, uint32_t *compare_value)
{
    system_error_t status = SYSTEM_SUCCESS;

    if (compare_value == NULL)
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        status = peripheral_check_valid(timer_to_peripheral(dev));

        if (is_success(status))
        {
            uint32_t divisor = timer_prescale_to_divisor(dev->config.prescale);
            
            /* Actual timer frequency = clk / divisor */
            uint32_t timer_freq = system_udiv32(dev->clock_frequency, divisor);
            
            /* Ticks per microsecond */
            uint32_t ticks_per_us = system_udiv32(timer_freq, 1000000U);
            
            if (ticks_per_us == 0U)
            {
                /* If the frequency is < 1 MHz, a rule of three must be used (beware of exceeding 32 bits). */
                uint64_t ticks64 = ((uint64_t)timeout_us * (uint64_t)timer_freq) / 1000000ULL;
                *compare_value = (uint32_t)ticks64;
            }
            else
            {
                *compare_value = system_umul32(timeout_us, ticks_per_us);
            }

            /* Minimal Hardware Security */
            if (*compare_value < TIMER_MIN_COMPARE_VALUE)
            {
                *compare_value = TIMER_MIN_COMPARE_VALUE;
            }
        }
    }

    return status;
}


system_error_t timer_start_timeout(timer_t *dev, uint32_t timeout_us, timer_mode_t mode)
{
    system_error_t status = SYSTEM_SUCCESS;
    uint32_t target_ticks = 0U;

    status = timer_calculate_compare_value(dev, timeout_us, &target_ticks);

    if (is_success(status))
    {
        timer_config_t config = dev->config;
        config.mode = mode;
        config.compare_value = target_ticks;

        status = timer_configure(dev, &config);
        if (is_success(status))
        {
            status = timer_reset(dev);
            if (is_success(status))
            {
                status = timer_enable(dev);
            }
        }
    }

    return status;
}


system_error_t timer_is_timeout(timer_t *dev, bool *timeout_occurred)
{
    /* In the current Hardware architecture, a Timeout corresponds to the MATCH flag */
    return timer_is_match(dev, timeout_occurred);
}


system_error_t timer_delay_us(timer_t *dev, uint32_t delay_us)
{
    system_error_t status = SYSTEM_SUCCESS;
    uint32_t target_ticks = 0U;

    status = timer_calculate_compare_value(dev, delay_us, &target_ticks);

    if (is_success(status))
    {
        timer_config_t config = dev->config;
        config.mode = TIMER_MODE_ONESHOT;
        config.compare_value = target_ticks;

        status = timer_configure(dev, &config);
        if (is_success(status))
        {
            status = timer_reset(dev);
            status = timer_enable(dev);

            if (is_success(status))
            {
                bool is_match = false;
                
                /* Blocking Loop: we wait to the MATCH flag to rise */
                while (!is_match)
                {
                    (void)timer_is_match(dev, &is_match);
                }

                (void)timer_disable(dev);
                (void)timer_clear_match(dev);
            }
        }
    }

    return status;
}


system_error_t timer_delay_ms(timer_t *dev, uint32_t delay_ms)
{
    /* We directly use timer_delay_us */
    return timer_delay_us(dev, system_umul32(delay_ms, 1000U));
}


