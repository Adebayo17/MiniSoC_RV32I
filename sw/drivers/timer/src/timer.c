/*
 * @file timer.c
 * @brief Timer Driver Implementation
 */

#include "timer.h"

void timer_init(timer_t *dev, uint32_t base_addr, uint32_t clock_freq)
{
    dev->base_address = base_addr;
    dev->clock_frequency = clock_freq;
    
    /* Disable timer and reset to known state */
    timer_disable(dev);
    timer_reset(dev);
    timer_clear_status(dev);
    
    /* Set default configuration */
    timer_set_prescaler(dev, TIMER_PRESCALE_1);
    timer_set_mode(dev, TIMER_MODE_CONTINUOUS);
    timer_set_compare(dev, 0xFFFFFFFFu); /* Maximum compare value by default */
}


void timer_enable(timer_t *dev)
{
    uint32_t ctrl = READ_REG(dev->base_address + REG_TIMER_CTRL_OFFSET);
    ctrl |= TIMER_CTRL_ENABLE_BIT;
    WRITE_REG(dev->base_address + REG_TIMER_CTRL_OFFSET, ctrl);
}


void timer_disable(timer_t *dev)
{
    uint32_t ctrl = READ_REG(dev->base_address + REG_TIMER_CTRL_OFFSET);
    ctrl &= ~TIMER_CTRL_ENABLE_BIT;
    WRITE_REG(dev->base_address + REG_TIMER_CTRL_OFFSET, ctrl);
}


void timer_reset(timer_t *dev)
{
    uint32_t ctrl = READ_REG(dev->base_address + REG_TIMER_CTRL_OFFSET);
    
    /* Set reset bit */
    ctrl |= TIMER_CTRL_RESET_BIT;
    WRITE_REG(dev->base_address + REG_TIMER_CTRL_OFFSET, ctrl);
    
    /* Clear reset bit (reset is edge-triggered) */
    ctrl &= ~TIMER_CTRL_RESET_BIT;
    WRITE_REG(dev->base_address + REG_TIMER_CTRL_OFFSET, ctrl);
}


void timer_set_mode(timer_t *dev, timer_mode_t mode)
{
    uint32_t ctrl = READ_REG(dev->base_address + REG_TIMER_CTRL_OFFSET);
    
    if (mode == TIMER_MODE_ONESHOT) {
        ctrl |= TIMER_CTRL_ONESHOT_BIT;
    } else {
        ctrl &= ~TIMER_CTRL_ONESHOT_BIT;
    }
    
    WRITE_REG(dev->base_address + REG_TIMER_CTRL_OFFSET, ctrl);
}


void timer_set_prescaler(timer_t *dev, timer_prescale_t prescale)
{
    uint32_t ctrl = READ_REG(dev->base_address + REG_TIMER_CTRL_OFFSET);
    
    /* Clear current prescaler bits */
    ctrl &= ~TIMER_CTRL_PRESCALE_MASK;
    
    /* Set new prescaler value */
    ctrl |= ((prescale & 0x3u) << TIMER_CTRL_PRESCALE_POS);
    
    WRITE_REG(dev->base_address + REG_TIMER_CTRL_OFFSET, ctrl);
}


uint32_t timer_get_count(timer_t *dev)
{
    return READ_REG(dev->base_address + REG_TIMER_COUNT_OFFSET);
}


void timer_set_compare(timer_t *dev, uint32_t compare_value)
{
    WRITE_REG(dev->base_address + REG_TIMER_CMP_OFFSET, compare_value);
}


uint32_t timer_get_compare(timer_t *dev)
{
    return READ_REG(dev->base_address + REG_TIMER_CMP_OFFSET);
}


bool timer_is_match(timer_t *dev)
{
    uint32_t status = READ_REG(dev->base_address + REG_TIMER_STATUS_OFFSET);
    return (status & TIMER_STATUS_MATCH_BIT) != 0;
}


bool timer_is_overflow(timer_t *dev)
{
    uint32_t status = READ_REG(dev->base_address + REG_TIMER_STATUS_OFFSET);
    return (status & TIMER_STATUS_OVERFLOW_BIT) != 0;
}


void timer_clear_match(timer_t *dev)
{
    uint32_t status = READ_REG(dev->base_address + REG_TIMER_STATUS_OFFSET);
    status &= ~TIMER_STATUS_MATCH_BIT;
    WRITE_REG(dev->base_address + REG_TIMER_STATUS_OFFSET, status);
}


void timer_clear_overflow(timer_t *dev)
{
    uint32_t status = READ_REG(dev->base_address + REG_TIMER_STATUS_OFFSET);
    status &= ~TIMER_STATUS_OVERFLOW_BIT;
    WRITE_REG(dev->base_address + REG_TIMER_STATUS_OFFSET, status);
}


void timer_clear_status(timer_t *dev)
{
    WRITE_REG(dev->base_address + REG_TIMER_STATUS_OFFSET, 0x00u);
}


void timer_configure(timer_t *dev, timer_mode_t mode, timer_prescale_t prescale, uint32_t compare_value)
{
    timer_disable(dev);
    timer_set_mode(dev, mode);
    timer_set_prescaler(dev, prescale);
    timer_set_compare(dev, compare_value);
    timer_clear_status(dev);
    timer_reset(dev);
}

uint32_t timer_calculate_compare_value(timer_t *dev, uint32_t timeout_us)
{
    uint32_t ctrl = READ_REG(dev->base_address + REG_TIMER_CTRL_OFFSET);
    uint32_t prescale = (ctrl & TIMER_CTRL_PRESCALE_MASK) >> TIMER_CTRL_PRESCALE_POS;
    uint32_t prescale_value;
    
    /* Get actual prescale divisor */
    switch (prescale) {
        case TIMER_PRESCALE_1:    prescale_value = 1; break;
        case TIMER_PRESCALE_8:    prescale_value = 8; break;
        case TIMER_PRESCALE_64:   prescale_value = 64; break;
        case TIMER_PRESCALE_1024: prescale_value = 1024; break;
        default:                  prescale_value = 1; break;
    }
    
    /* Calculate timer ticks needed for timeout */
    uint64_t ticks = ((uint64_t)timeout_us * dev->clock_frequency) / (1000000UL * prescale_value);
    
    /* Ensure we don't exceed 32-bit maximum */
    if (ticks > 0xFFFFFFFFu) {
        return 0xFFFFFFFFu;
    }
    
    return (uint32_t)ticks;
}

void timer_start_timeout(timer_t *dev, uint32_t timeout_us, timer_mode_t mode)
{
    uint32_t compare_value = timer_calculate_compare_value(dev, timeout_us);
    timer_configure(dev, mode, TIMER_PRESCALE_1, compare_value); /* Use current prescaler */
    timer_enable(dev);
}

bool timer_is_timeout(timer_t *dev)
{
    return timer_is_match(dev);
}

void timer_delay_us(timer_t *dev, uint32_t delay_us)
{
    uint32_t compare_value = timer_calculate_compare_value(dev, delay_us);
    
    /* Configure timer for one-shot mode */
    timer_configure(dev, TIMER_MODE_ONESHOT, TIMER_PRESCALE_1, compare_value);
    timer_clear_status(dev);
    timer_reset(dev);
    timer_enable(dev);
    
    /* Busy wait until timeout */
    while (!timer_is_match(dev)) {
        /* Wait for match */
    }
    
    timer_clear_match(dev);
}

void timer_delay_ms(timer_t *dev, uint32_t delay_ms)
{
    timer_delay_us(dev, delay_ms * 1000u);
}