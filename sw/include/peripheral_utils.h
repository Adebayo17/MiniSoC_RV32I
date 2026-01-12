/*
 * @file peripheral_utils.h
 * @brief Peripheral utility macros and functions
*/

#ifndef PERIPHERAL_UTILS_H
#define PERIPHERAL_UTILS_H

#include "errors.h"


/* ========================================================================== */
/* Peripheral Helper Macros                                                   */
/* ========================================================================== */

/**
 * @brief Check if peripheral operation succeeded and handle error
 * @param expr Expression that returns system_error_t
 * @param error_label Label to jump to on error
 */
#define PERIPHERAL_CHECK(expr, error_label) do { \
    system_error_t __err = (expr); \
    if (IS_ERROR(__err)) { \
        goto error_label; \
    } \
} while (0)


/**
 * @brief Check if peripheral operation succeeded and return on error
 * @param expr Expression that returns system_error_t
 */
#define PERIPHERAL_RETURN_ON_ERROR(expr) do { \
    system_error_t __err = (expr); \
    if (IS_ERROR(__err)) { \
        return __err; \
    } \
} while (0)


/**
 * @brief Check if peripheral is valid (not NULL and initialized)
 * @param dev Pointer to peripheral structure
 */
#define PERIPHERAL_CHECK_VALID(dev) do { \
    if ((dev) == NULL) { \
        return SYSTEM_ERROR_INVALID_PARAM; \
    } \
    if (!(dev)->base.initialized) { \
        return SYSTEM_ERROR_NOT_READY; \
    } \
} while (0)


/**
 * @brief Check if pointer parameter is valid
 * @param ptr Pointer to check
 */
#define PARAM_CHECK_NOT_NULL(ptr) do { \
    if ((ptr) == NULL) { \
        return SYSTEM_ERROR_INVALID_PARAM; \
    } \
} while (0)


/**
 * @brief Check both peripheral and parameter
 */
#define PERIPHERAL_AND_PARAM_CHECK(dev, param) do { \
    PERIPHERAL_CHECK_VALID(dev); \
    PARAM_CHECK_NOT_NULL(param); \
} while (0)


/**
 * @brief Initialize peripheral with cleanup on error
 * @param init_func Initialization function
 * @param cleanup_func Cleanup function
 */
#define PERIPHERAL_INIT_WITH_CLEANUP(init_func, cleanup_func) do { \
    system_error_t __err = (init_func); \
    if (IS_ERROR(__err)) { \
        (cleanup_func); \
        return __err; \
    } \
} while (0)

/* ========================================================================== */
/* Common Validation Functions                                                */
/* ========================================================================== */

/**
 * @brief Validate memory address range
 * @param addr Starting address
 * @param size Size of memory region
 * @param is_write true for write access, false for read
 * @return SYSTEM_SUCCESS if valid, error code otherwise
 */
static inline system_error_t validate_memory_range(uint32_t addr, uint32_t size, bool is_write)
{
    for (uint32_t i = 0; i < size; i++) {
        system_error_t err = system_validate_address(addr + i, is_write);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    return SYSTEM_SUCCESS;
}

/**
 * @brief Validate buffer parameters
 * @param buffer Pointer to buffer
 * @param size Buffer size
 * @return SYSTEM_SUCCESS if valid, error code otherwise
 */
static inline system_error_t validate_buffer(const void *buffer, uint32_t size)
{
    if (buffer == NULL && size > 0) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    if (size == 0) {
        return SYSTEM_SUCCESS; /* Empty buffer is valid */
    }
    
    /* Validate buffer memory range */
    return validate_memory_range((uint32_t)buffer, size, false);
}

#endif /* PERIPHERAL_UTILS_H */