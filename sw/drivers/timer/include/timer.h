/*
 * @file    timer.h
 * @brief   TIMER Driver Interface.
 * @details Conforms to the Barr Group Embedded C Coding Standard.
*/

#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>
#include <stdbool.h>
#include "peripheral.h"       /* peripheral_t structure */
#include "errors.h"           /* system_error_t */



/* ========================================================================== */
/* TIMER Type Definitions                                                     */
/* ========================================================================== */


/** 
 * @brief Timer Prescaler Values (register values)
 * These are the values written to the PRESCALE field in CTRL register
 */
typedef enum 
{
    TIMER_PRESCALE_1    = 0,    /* Clock / 1 */
    TIMER_PRESCALE_8    = 1,    /* Clock / 8 */
    TIMER_PRESCALE_64   = 2,    /* Clock / 64 */
    TIMER_PRESCALE_1024 = 3     /* Clock / 1024 */
} timer_prescale_t;


/** 
 * @brief Actual prescaler divisor values
 * Use these when calculating timeouts
 */
typedef enum 
{
    TIMER_PRESCALER_DIV_1    = 1,
    TIMER_PRESCALER_DIV_8    = 8, 
    TIMER_PRESCALER_DIV_64   = 64,
    TIMER_PRESCALER_DIV_1024 = 1024
} timer_prescaler_div_t;


/** 
 * @brief Timer Mode 
 */
typedef enum 
{
    TIMER_MODE_CONTINUOUS = 0,
    TIMER_MODE_ONESHOT    = 1
} timer_mode_t;


/* ========================================================================== */
/* TIMER Software Structures                                                  */
/* ========================================================================== */

/**
 * @struct  timer_status_t
 * @brief   Timer Status structure
 */
typedef struct 
{
    bool                match_occurred;         /* Compare match occurred */
    bool                overflow_occurred;      /* Timer overflow occurred */
    bool                is_running;             /* Timer is currently enabled */
    bool                is_oneshot;             /* Timer is in one-shot mode */
    timer_prescale_t    prescale;               /* Current prescaler setting */
    uint32_t            count_value;            /* Current count value */
    uint32_t            compare_value;          /* Current compare value */
} timer_status_t;


/**
 * @struct  timer_config_t
 * @brief   Timer configuration structure
 */
typedef struct 
{
    timer_mode_t     mode;            /* Continuous or one-shot */
    timer_prescale_t prescale;        /* Clock prescaler */
    uint32_t         compare_value;   /* Compare match value */
} timer_config_t;


/**
 * @brief   Timer Device Structure
 * @note    The Main Handle
 */
struct timer_system 
{
    peripheral_t     base;                  /*!< Base peripheral structure */
    uint32_t         clock_frequency;       /*!< Timer clock frequency in Hz (100MHz = 100000000) */
    timer_config_t   config;                /*!< Current configuration */
    timer_status_t   status;                /*!< Current status */
};



// Keep the typedef for convenience
typedef struct timer_system timer_t;


/* ========================================================================== */
/* Utility Functions                                                          */
/* ========================================================================== */

/** 
 * @brief   Cast TIMER Handle to base peripheral structure.
 * @param   [in] timer Pointer to timer structure.
 * @return  Safe cast to peripheral_t pointer.
 */
static inline peripheral_t *timer_to_peripheral(timer_t *timer) 
{
    return (peripheral_t *)timer;  // Safe cast - base is first member
}


/** 
 * @brief   Cast base peripheral structure to TIMER Handle.
 * @param   [in] periph Pointer to peripheral structure.
 * @return  Safe cast to timer_t pointer.
 */
static inline timer_t *peripheral_to_timer(peripheral_t *periph) 
{
    return (timer_t *)periph;  // Safe cast if originally was timer_t
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
 * @brief   Initialize timer driver
 * @param   [in] dev Pointer to timer structure
 * @param   [in] base_addr Base address of the timer peripheral
 * @param   [in] clock_freq Timer clock frequency in Hz
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_init(timer_t *dev, uint32_t base_addr, uint32_t clock_freq);


/**
 * @brief   Deinitialize timer driver
 * @param   [in] dev Pointer to timer structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_deinit(timer_t *dev);


/**
 * @brief   Reset the timer counter
 * @param   [in] dev Pointer to timer structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_reset(timer_t *dev);


/**
 * @brief   Configure timer with all parameters
 * @param   [in] dev Pointer to timer structure
 * @param   [in] config Pointer to configuration structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_configure(timer_t *dev, const timer_config_t *config);


/**
 * @brief   Get current timer configuration
 * @param   [in] dev Pointer to timer structure
 * @param   [out] config Pointer to store configuration
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_get_config(timer_t *dev, timer_config_t *config);


/**
 * @brief   Enable the timer
 * @param   [in] dev Pointer to timer structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_enable(timer_t *dev);


/**
 * @brief   Disable the timer
 * @param   [in] dev Pointer to timer structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_disable(timer_t *dev);


/**
 * @brief   Set timer mode (continuous or one-shot)
 * @param   [in] dev Pointer to timer structure
 * @param   [in] mode Timer mode (TIMER_MODE_CONTINUOUS or TIMER_MODE_ONESHOT)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_set_mode(timer_t *dev, timer_mode_t mode);


/**
 * @brief   Set timer prescaler
 * @param   [in] dev Pointer to timer structure
 * @param   [in] prescale Prescaler value
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_set_prescaler(timer_t *dev, timer_prescale_t prescale);


/**
 * @brief   Get current timer count value
 * @param   [in] dev Pointer to timer structure
 * @param   [out] count_value Pointer to store count value
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_get_count(timer_t *dev, uint32_t *count_value);


/**
 * @brief   Set compare value
 * @param   [in] dev Pointer to timer structure
 * @param   [in] compare_value Compare value for match interrupt
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_set_compare(timer_t *dev, uint32_t compare_value);


/**
 * @brief   Get current compare value
 * @param   [in] dev Pointer to timer structure
 * @param   [out] compare_value Pointer to store compare value
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_get_compare(timer_t *dev, uint32_t *compare_value);


/**
 * @brief   Get timer status
 * @param   [in] dev Pointer to timer structure
 * @param   [out] status Pointer to store status information
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_get_status(timer_t *dev, timer_status_t *status_out);


/**
 * @brief   Check if compare match occurred
 * @param   [in] dev Pointer to timer structure
 * @param   [out] match_occurred Pointer to store result
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_is_match(timer_t *dev, bool *match_occurred);


/**
 * @brief   Check if timer overflow occurred
 * @param   [in] dev Pointer to timer structure
 * @param   [in] overflow_occurred Pointer to store result
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_is_overflow(timer_t *dev, bool *overflow_occurred);


/**
 * @brief   Check if timer is currently running
 * @param   [in] dev Pointer to timer structure
 * @param   [out] is_running Pointer to store result
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_is_running(timer_t *dev, bool *is_running);


/* W1C (Write-1-to-Clear) operations */

/**
 * @brief   Clear match status flag
 * @param   [in] dev Pointer to timer structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_clear_match(timer_t *dev);


/**
 * @brief   Clear overflow status flag
 * @param   [in] dev Pointer to timer structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_clear_overflow(timer_t *dev);


/**
 * @brief   Clear all status flags
 * @param   [in] dev Pointer to timer structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_clear_status(timer_t *dev);


/* High-level timing functions */


/**
 * @brief   Calculate compare value for specific timeout
 * @param   [in] dev Pointer to timer structure
 * @param   [in] timeout_us Timeout in microseconds
 * @param   [out] compare_value Pointer to store calculated compare value
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_calculate_compare_value(timer_t *dev, uint32_t timeout_us, uint32_t *compare_value);


/**
 * @brief   Busy wait delay in microseconds
 * @param   [in] dev Pointer to timer structure
 * @param   [in] delay_us Delay in microseconds
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_delay_us(timer_t *dev, uint32_t delay_us);


/**
 * @brief   Busy wait delay in milliseconds
 * @param   [in] dev Pointer to timer structure
 * @param   [in] delay_ms Delay in milliseconds
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_delay_ms(timer_t *dev, uint32_t delay_ms);


/**
 * @brief   Start timer with specific timeout
 * @param   [in] dev Pointer to timer structure
 * @param   [in] timeout_us Timeout in microseconds
 * @param   [in] mode Timer mode
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_start_timeout(timer_t *dev, uint32_t timeout_us, timer_mode_t mode);


/**
 * @brief   Check if timeout has occurred
 * @param   [in] dev Pointer to timer structure
 * @param   [out] timeout_occurred Pointer to store result
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t timer_is_timeout(timer_t *dev, bool *timeout_occurred);


#endif /* TIMER_H */