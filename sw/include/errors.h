/**
 * @file    errors.h
 * @brief   System Error Codes for the MiniSoC_RV32I project.
 * @details Conforms to Barr Group Embedded C Coding Standard.
 * Defines standard return types and inline helper functions
 * for error handling.
 */

#ifndef ERRORS_H
#define ERRORS_H


#include <stdint.h>

/* ========================================================================== */
/* Error Codes                                                                */
/* ========================================================================== */


/**
 * @enum  system_error_t
 * @brief Enumeration of all system-wide return codes.
 * @note  Negative values represent errors, 0 represents success.
 */
typedef enum {
    SYSTEM_SUCCESS                  = 0,

    /* Software errors */
    SYSTEM_ERROR_INVALID_PARAM      = -1,
    SYSTEM_ERROR_TIMEOUT            = -2,
    SYSTEM_ERROR_BUSY               = -3,
    SYSTEM_ERROR_NOT_READY          = -4,

    /* Hardware errors */
    SYSTEM_ERROR_HARDWARE           = -5,
    SYSTEM_ERROR_MEMORY_ACCESS      = -6,
    SYSTEM_ERROR_INVALID_ADDRESS    = -7, 
    SYSTEM_ERROR_INVALID_SLAVE      = -8,

    /* Peripheral-specific errors */
    SYSTEM_ERROR_UART_OVERRUN       = -20,
    SYSTEM_ERROR_UART_FRAME         = -21,
    SYSTEM_ERROR_TIMER_OVERFLOW     = -30,
    SYSTEM_ERROR_GPIO_INVALID_PIN   = -40
} system_error_t;


/* Hardware error pattern definitions */
#define HARDWARE_ERROR_INVALID_ADDR     (0xDEADBEEFUL)
#define HARDWARE_ERROR_INVALID_SLAVE    (0xBADADD01UL)


/* ========================================================================== */
/* Helper Functions                                                           */
/* ========================================================================== */
/* Note: Barr Group standard highly prefers 'static inline' functions over    */
/* parameterized macros for better type safety and to prevent side-effects.   */

/**
 * @brief  Checks if a hardware code corresponds to an error.
 * @param  [in] value The 32-bit hardware status code to check.
 * @return true if the code is a hardware error, false otherwise.
 */
static inline bool is_hardware_error(uint32_t value)
{
    return ((value == HARDWARE_ERROR_INVALID_ADDR) || 
            (value == HARDWARE_ERROR_INVALID_SLAVE));
}

/**
 * @brief  Converts a hardware error code to a system error enum.
 * @param  [in] hw_error The hardware error code.
 * @return The corresponding system_error_t value.
 */
static inline system_error_t hardware_error_to_system_error(uint32_t hw_error)
{
    system_error_t sys_err;

    if (hw_error == HARDWARE_ERROR_INVALID_ADDR)
    {
        sys_err = SYSTEM_ERROR_INVALID_ADDRESS;
    }
    else if (hw_error == HARDWARE_ERROR_INVALID_SLAVE)
    {
        sys_err = SYSTEM_ERROR_INVALID_SLAVE;
    }
    else
    {
        sys_err = SYSTEM_SUCCESS;
    }

    return sys_err;
}

/**
 * @brief  Checks if a system code represents an error.
 * @param  [in] code The system error code of type system_error_t.
 * @return true if it is an error (code < 0), false otherwise.
 */
static inline bool is_error(system_error_t code)
{
    return (code < SYSTEM_SUCCESS);
}

/**
 * @brief  Checks if a system code represents a success.
 * @param  [in] code The system error code of type system_error_t.
 * @return true if it is a success (code >= 0), false otherwise.
 */
static inline bool is_success(system_error_t code)
{
    return (code >= SYSTEM_SUCCESS);
}



#endif /* ERRORS_H */