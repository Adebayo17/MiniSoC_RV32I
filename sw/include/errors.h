/*
 * @file peripheral.h
 * @brief Peripheral functions prototypes for Mini RV32I SoC
*/

#ifndef ERROR_H
#define ERROR_H


/* ========================================================================== */
/* Error Codes                                                                */
/* ========================================================================== */

typedef enum {
    SYSTEM_SUCCESS = 0,
    SYSTEM_ERROR_INVALID_PARAM = -1,
    SYSTEM_ERROR_TIMEOUT = -2,
    SYSTEM_ERROR_BUSY = -3,
    SYSTEM_ERROR_NOT_READY = -4,
    SYSTEM_ERROR_HARDWARE = -5,
    SYSTEM_ERROR_MEMORY_ACCESS = -6,
    SYSTEM_ERROR_INVALID_ADDRESS = -7
} system_error_t;


#endif /* ERROR_H */