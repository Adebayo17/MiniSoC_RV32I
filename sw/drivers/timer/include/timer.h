/*
 * @file timer.h
 * @brief TIMER Driver
*/

#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>
#include <stdbool.h>

/* Base Address Definition */
#define TIMER_BASE_ADDRESS          0x30000000u

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

/* Register Access Macros */
#define READ_REG(addr)              (*(volatile uint32_t *)(addr))
#define WRITE_REG(addr, value)      (*(volatile uint32_t *)(addr) = (value))

/* Timer Control Register Bit Definitions */
#define TIMER_CTRL_ENABLE_POS       0
#define TIMER_CTRL_ENABLE_BIT       (1u << TIMER_CTRL_ENABLE_POS)

#define TIMER_CTRL_RESET_POS        1
#define TIMER_CTRL_RESET_BIT        (1u << TIMER_CTRL_RESET_POS)

#define TIMER_CTRL_ONESHOT_POS      2
#define TIMER_CTRL_ONESHOT_BIT      (1u << TIMER_CTRL_ONESHOT_POS)

#define TIMER_CTRL_PRESCALE_POS     3
#define TIMER_CTRL_PRESCALE_WIDTH   2
#define TIMER_CTRL_PRESCALE_MASK    (0x3u << TIMER_CTRL_PRESCALE_POS)

/* Prescaler Values */
typedef enum {
    TIMER_PRESCALE_1    = 0,    /* Clock / 1 */
    TIMER_PRESCALE_8    = 1,    /* Clock / 8 */
    TIMER_PRESCALE_64   = 2,    /* Clock / 64 */
    TIMER_PRESCALE_1024 = 3     /* Clock / 1024 */
} timer_prescale_t;

/* Timer Status Register Bit Definitions */
#define TIMER_STATUS_MATCH_POS        0
#define TIMER_STATUS_MATCH_BIT        (1u << TIMER_STATUS_MATCH_POS)

#define TIMER_STATUS_OVERFLOW_POS     1
#define TIMER_STATUS_OVERFLOW_BIT     (1u << TIMER_STATUS_OVERFLOW_POS)

/* Timer Mode */
typedef enum {
    TIMER_MODE_CONTINUOUS = 0,
    TIMER_MODE_ONESHOT    = 1
} timer_mode_t;

/*
 * @brief Timer Device Structure
 */
typedef struct {
    uint32_t base_address;
    uint32_t clock_frequency;  /* Timer clock frequency in Hz */
} timer_t;

/* Function Prototypes */

/*
 * @brief Initialize timer driver
 * @param dev : Pointer to timer structure
 * @param base_addr : Base address of the timer peripheral
 * @param clock_freq : Timer clock frequency in Hz
 */
void timer_init(timer_t *dev, uint32_t base_addr, uint32_t clock_freq);

/*
 * @brief Enable the timer
 * @param dev : Pointer to timer structure
 */
void timer_enable(timer_t *dev);

/*
 * @brief Disable the timer
 * @param dev : Pointer to timer structure
 */
void timer_disable(timer_t *dev);

/*
 * @brief Reset the timer counter
 * @param dev : Pointer to timer structure
 */
void timer_reset(timer_t *dev);

/*
 * @brief Set timer mode (continuous or one-shot)
 * @param dev : Pointer to timer structure
 * @param mode : Timer mode (TIMER_MODE_CONTINUOUS or TIMER_MODE_ONESHOT)
 */
void timer_set_mode(timer_t *dev, timer_mode_t mode);

/*
 * @brief Set timer prescaler
 * @param dev : Pointer to timer structure
 * @param prescale : Prescaler value
 */
void timer_set_prescaler(timer_t *dev, timer_prescale_t prescale);

/*
 * @brief Get current timer count value
 * @param dev : Pointer to timer structure
 * @return Current timer count
 */
uint32_t timer_get_count(timer_t *dev);

/*
 * @brief Set compare value
 * @param dev : Pointer to timer structure
 * @param compare_value : Compare value for match interrupt
 */
void timer_set_compare(timer_t *dev, uint32_t compare_value);

/*
 * @brief Get current compare value
 * @param dev : Pointer to timer structure
 * @return Current compare value
 */
uint32_t timer_get_compare(timer_t *dev);

/*
 * @brief Check if compare match occurred
 * @param dev : Pointer to timer structure
 * @return true if match occurred, false otherwise
 */
bool timer_is_match(timer_t *dev);

/*
 * @brief Check if timer overflow occurred
 * @param dev : Pointer to timer structure
 * @return true if overflow occurred, false otherwise
 */
bool timer_is_overflow(timer_t *dev);

/*
 * @brief Clear match status flag
 * @param dev : Pointer to timer structure
 */
void timer_clear_match(timer_t *dev);

/*
 * @brief Clear overflow status flag
 * @param dev : Pointer to timer structure
 */
void timer_clear_overflow(timer_t *dev);

/*
 * @brief Clear all status flags
 * @param dev : Pointer to timer structure
 */
void timer_clear_status(timer_t *dev);

/*
 * @brief Configure timer with all parameters
 * @param dev : Pointer to timer structure
 * @param mode : Timer mode
 * @param prescale : Prescaler value
 * @param compare_value : Compare value
 */
void timer_configure(timer_t *dev, timer_mode_t mode, timer_prescale_t prescale, uint32_t compare_value);

/*
 * @brief Calculate compare value for specific timeout
 * @param dev : Pointer to timer structure
 * @param timeout_us : Timeout in microseconds
 * @return Compare value for the timeout
 */
uint32_t timer_calculate_compare_value(timer_t *dev, uint32_t timeout_us);

/*
 * @brief Start timer with specific timeout
 * @param dev : Pointer to timer structure
 * @param timeout_us : Timeout in microseconds
 * @param mode : Timer mode
 */
void timer_start_timeout(timer_t *dev, uint32_t timeout_us, timer_mode_t mode);

/*
 * @brief Check if timeout has occurred
 * @param dev : Pointer to timer structure
 * @return true if timeout occurred, false otherwise
 */
bool timer_is_timeout(timer_t *dev);

/*
 * @brief Busy wait delay in microseconds
 * @param dev : Pointer to timer structure
 * @param delay_us : Delay in microseconds
 */
void timer_delay_us(timer_t *dev, uint32_t delay_us);

/*
 * @brief Busy wait delay in milliseconds
 * @param dev : Pointer to timer structure
 * @param delay_ms : Delay in milliseconds
 */
void timer_delay_ms(timer_t *dev, uint32_t delay_ms);

#endif /* TIMER_H */