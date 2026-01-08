/*
 * @file timer.h
 * @brief TIMER Driver
*/

#ifndef TIMER_H
#define TIMER_H

#include "peripheral.h"    /* peripheral_t structure */


/* ========================================================================== */
/* TIMER Memory Map Definitions                                               */
/* ========================================================================== */

/* Register Address Offsets */
#define REG_TIMER_COUNT_OFFSET      0x00u
#define REG_TIMER_CMP_OFFSET        0x04u
#define REG_TIMER_CTRL_OFFSET       0x08u
#define REG_TIMER_STATUS_OFFSET     0x0Cu


/* Register Address Calculation */
#define REG_TIMER_COUNT_ADDR        (TIMER_BASE_ADDRESS + REG_TIMER_COUNT_OFFSET)
#define REG_TIMER_CMP_ADDR          (TIMER_BASE_ADDRESS + REG_TIMER_CMP_OFFSET)
#define REG_TIMER_CTRL_ADDR         (TIMER_BASE_ADDRESS + REG_TIMER_CTRL_OFFSET)
#define REG_TIMER_STATUS_ADDR       (TIMER_BASE_ADDRESS + REG_TIMER_STATUS_OFFSET)


/* ========================================================================== */
/* Timer REG_TIMER_CTRL Bit Definitions                                       */
/* ========================================================================== */

#define TIMER_CTRL_ENABLE_POS       0
#define TIMER_CTRL_ENABLE_BIT       (1u << TIMER_CTRL_ENABLE_POS)

#define TIMER_CTRL_RESET_POS        1
#define TIMER_CTRL_RESET_BIT        (1u << TIMER_CTRL_RESET_POS)

#define TIMER_CTRL_ONESHOT_POS      2
#define TIMER_CTRL_ONESHOT_BIT      (1u << TIMER_CTRL_ONESHOT_POS)

#define TIMER_CTRL_PRESCALE_POS     3
#define TIMER_CTRL_PRESCALE_WIDTH   2
#define TIMER_CTRL_PRESCALE_MASK    BITMASK(TIMER_CTRL_PRESCALE_WIDTH, TIMER_CTRL_PRESCALE_POS)


/* ========================================================================== */
/* Timer REG_TIMER_STATUS Bit Definitions                                     */
/* ========================================================================== */

#define TIMER_STATUS_MATCH_POS      0
#define TIMER_STATUS_MATCH_BIT      (1u << TIMER_STATUS_MATCH_POS)

#define TIMER_STATUS_OVERFLOW_POS   1
#define TIMER_STATUS_OVERFLOW_BIT   (1u << TIMER_STATUS_OVERFLOW_POS)


/* ========================================================================== */
/* TIMER Structure Definitions                                                */
/* ========================================================================== */


/** 
 * @brief Timer Prescaler Values (register values)
 * These are the values written to the PRESCALE field in CTRL register
 */
typedef enum {
    TIMER_PRESCALE_1    = 0,    /* Clock / 1 */
    TIMER_PRESCALE_8    = 1,    /* Clock / 8 */
    TIMER_PRESCALE_64   = 2,    /* Clock / 64 */
    TIMER_PRESCALE_1024 = 3     /* Clock / 1024 */
} timer_prescale_t;


/** 
 * @brief Actual prescaler divisor values
 * Use these when calculating timeouts
 */
typedef enum {
    TIMER_PRESCALER_DIV_1    = 1,
    TIMER_PRESCALER_DIV_8    = 8, 
    TIMER_PRESCALER_DIV_64   = 64,
    TIMER_PRESCALER_DIV_1024 = 1024
} timer_prescaler_div_t;


/** 
 * @brief Timer Mode 
 */
typedef enum {
    TIMER_MODE_CONTINUOUS = 0,
    TIMER_MODE_ONESHOT    = 1
} timer_mode_t;


/**
 * @brief Timer configuration structure
 */
typedef struct {
    timer_mode_t     mode;
    timer_prescale_t prescale;
    uint32_t         compare_value;
} timer_config_t;


/**
 * @brief Timer Device Structure
 */
struct timer_system {
    peripheral_t base;
    uint32_t     clock_frequency;  /* Timer clock frequency in Hz */
};


// Keep the typedef for convenience
typedef struct timer_system timer_t;


/* ========================================================================== */
/* Utility Functions                                                          */
/* ========================================================================== */

/** 
 * @brief Function that cast timer structure to peripheral structure
 * @param timer Pointer to timer structure
 * @return timer as peripheral 
 */
static inline peripheral_t *timer_to_peripheral(timer_t *timer) {
    return (peripheral_t *)timer;  // Safe cast - base is first member
}


/** 
 * @brief Function that cast peripheral timer structure to timer structure
 * @param timer Pointer to peripheral structure
 * @return peripheral as timer
 */
static inline timer_t *peripheral_to_timer(peripheral_t *periph) {
    return (timer_t *)periph;  // Safe cast if originally was timer_t
}


/**
 * @brief Convert prescaler enum to actual divisor value
 * @param prescale Prescaler register value
 * @return Actual divisor (1, 8, 64, or 1024)
 */
static inline uint32_t timer_prescale_to_divisor(timer_prescale_t prescale) {
    switch (prescale) {
        case TIMER_PRESCALE_1:    return 1;     break;
        case TIMER_PRESCALE_8:    return 8;     break;
        case TIMER_PRESCALE_64:   return 64;    break;
        case TIMER_PRESCALE_1024: return 1024;  break;
        default:                  return 1;     break;
    }
}

/**
 * @brief Convert divisor value to prescaler enum
 * @param divisor Actual divisor (1, 8, 64, or 1024)
 * @return Prescaler register value
 */
static inline timer_prescale_t timer_divisor_to_prescale(uint32_t divisor) {
    switch (divisor) {
        case 1:    return TIMER_PRESCALE_1;
        case 8:    return TIMER_PRESCALE_8;
        case 64:   return TIMER_PRESCALE_64;
        case 1024: return TIMER_PRESCALE_1024;
        default:   return TIMER_PRESCALE_1;
    }
}


/* ========================================================================== */
/* Functions Prototypes                                                       */
/* ========================================================================== */


/**
 * @brief Initialize timer driver
 * @param dev Pointer to timer structure
 * @param base_addr Base address of the timer peripheral
 * @param clock_freq Timer clock frequency in Hz
 */
void timer_init(timer_t *dev, uint32_t base_addr, uint32_t clock_freq);


/**
 * @brief Enable the timer
 * @param dev Pointer to timer structure
 */
void timer_enable(timer_t *dev);


/**
 * @brief Disable the timer
 * @param dev Pointer to timer structure
 */
void timer_disable(timer_t *dev);


/**
 * @brief Reset the timer counter
 * @param dev Pointer to timer structure
 */
void timer_reset(timer_t *dev);


/**
 * @brief Set timer mode (continuous or one-shot)
 * @param dev Pointer to timer structure
 * @param mode Timer mode (TIMER_MODE_CONTINUOUS or TIMER_MODE_ONESHOT)
 */
void timer_set_mode(timer_t *dev, timer_mode_t mode);


/**
 * @brief Set timer prescaler
 * @param dev Pointer to timer structure
 * @param prescale Prescaler value
 */
void timer_set_prescaler(timer_t *dev, timer_prescale_t prescale);


/**
 * @brief Get current timer count value
 * @param dev Pointer to timer structure
 * @return Current timer count
 */
uint32_t timer_get_count(timer_t *dev);


/**
 * @brief Set compare value
 * @param dev Pointer to timer structure
 * @param compare_value Compare value for match interrupt
 */
void timer_set_compare(timer_t *dev, uint32_t compare_value);


/**
 * @brief Get current compare value
 * @param dev Pointer to timer structure
 * @return Current compare value
 */
uint32_t timer_get_compare(timer_t *dev);


/**
 * @brief Check if compare match occurred
 * @param dev Pointer to timer structure
 * @return true if match occurred, false otherwise
 */
bool timer_is_match(timer_t *dev);


/**
 * @brief Check if timer overflow occurred
 * @param dev Pointer to timer structure
 * @return true if overflow occurred, false otherwise
 */
bool timer_is_overflow(timer_t *dev);


/**
 * @brief Clear match status flag
 * @param dev Pointer to timer structure
 */
void timer_clear_match(timer_t *dev);


/**
 * @brief Clear overflow status flag
 * @param dev Pointer to timer structure
 */
void timer_clear_overflow(timer_t *dev);


/**
 * @brief Clear all status flags
 * @param dev Pointer to timer structure
 */
void timer_clear_status(timer_t *dev);


/**
 * @brief Configure timer with all parameters
 * @param dev Pointer to timer structure
 * @param mode Timer mode
 * @param prescale Prescaler value
 * @param compare_value Compare value
 */
void timer_configure(timer_t *dev, timer_mode_t mode, timer_prescale_t prescale, uint32_t compare_value);


/**
 * @brief Calculate compare value for specific timeout
 * @param dev Pointer to timer structure
 * @param timeout_us Timeout in microseconds
 * @return Compare value for the timeout
 */
uint32_t timer_calculate_compare_value(timer_t *dev, uint32_t timeout_us);


/**
 * @brief Start timer with specific timeout
 * @param dev Pointer to timer structure
 * @param timeout_us Timeout in microseconds
 * @param mode Timer mode
 */
void timer_start_timeout(timer_t *dev, uint32_t timeout_us, timer_mode_t mode);


/**
 * @brief Check if timeout has occurred
 * @param dev Pointer to timer structure
 * @return true if timeout occurred, false otherwise
 */
bool timer_is_timeout(timer_t *dev);


/**
 * @brief Busy wait delay in microseconds
 * @param dev Pointer to timer structure
 * @param delay_us Delay in microseconds
 */
void timer_delay_us(timer_t *dev, uint32_t delay_us);


/**
 * @brief Busy wait delay in milliseconds
 * @param dev Pointer to timer structure
 * @param delay_ms Delay in milliseconds
 */
void timer_delay_ms(timer_t *dev, uint32_t delay_ms);


/**
 * @brief Configure timer using timer_config_t
 * @param dev Pointer to timer structure
 * @param config Pointer to Config structure
 */
void timer_set_config(timer_t *dev, const timer_config_t *config);


/**
 * @brief Get timer current configuration using timer_config_t
 * @param dev Pointer to timer structure
 * @param config Pointer to Config structure
 */
void timer_get_config(timer_t *dev, timer_config_t *config);


#endif /* TIMER_H */