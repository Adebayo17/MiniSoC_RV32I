/*
 * @file peripheral.h
 * @brief Peripheral functions prototypes for Mini RV32I SoC
*/

#ifndef ERRORS_H
#define ERRORS_H


#include <stdint.h>

/* ========================================================================== */
/* Error Codes                                                                */
/* ========================================================================== */

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
#define HARDWARE_ERROR_INVALID_ADDR     0xDEADBEEF
#define HARDWARE_ERROR_INVALID_SLAVE    0xBADADD01

/* Helper macros */
#define IS_HARDWARE_ERROR(value) \
    ((value) == HARDWARE_ERROR_INVALID_ADDR || \
     (value) == HARDWARE_ERROR_INVALID_SLAVE)


#define HARDWARE_ERROR_TO_SYSTEM_ERROR(hw_error) \
    ((hw_error) == HARDWARE_ERROR_INVALID_ADDR ? SYSTEM_ERROR_INVALID_ADDRESS : \
     (hw_error) == HARDWARE_ERROR_INVALID_SLAVE ? SYSTEM_ERROR_INVALID_SLAVE : \
     SYSTEM_SUCCESS)

/* Quick status checks */
#define IS_ERROR(code) ((code) < 0)
#define IS_SUCCESS(code) ((code) >= 0)


#endif /* ERRORS_H */