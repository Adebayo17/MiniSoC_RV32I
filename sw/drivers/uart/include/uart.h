/*
 * @file    uart.h
 * @brief   UART Driver Interface.
 * @details Conforms to the Barr Group Embedded C Coding Standard.
 * Public API definitions for UART driver, including configuration, status retrieval, and data transmission functions.
*/

#ifndef UART_H
#define UART_H

#include <stdint.h>
#include <stdbool.h>
#include "peripheral.h"       /* peripheral_t structure */
#include "errors.h"           /* system_error_t */


/* ========================================================================== */
/* Standard Baud Rates                                                        */
/* ========================================================================== */

#define UART_BAUD_9600              (9600UL)
#define UART_BAUD_19200             (19200UL)
#define UART_BAUD_38400             (38400UL)
#define UART_BAUD_57600             (57600UL)
#define UART_BAUD_115200            (115200UL)


/* ========================================================================== */
/* UART Software Structures                                                   */
/* ========================================================================== */

/**
 * @struct uart_status_t
 * @brief  UART Status structure.
 */
typedef struct
{
    bool tx_ready;          /*!< Transmitter ready for new data */
    bool tx_busy;           /*!< Transmitter busy sending */
    bool rx_ready;          /*!< Receiver has data available */
    bool rx_overrun;        /*!< Receiver overrun error occurred */
    bool rx_frame_error;    /*!< Receiver frame error occurred */
} uart_status_t; 


/**
 * @struct uart_config_t
 * @brief  UART Configuration structure
 */
typedef struct 
{
    uint32_t    baudrate;       /*!< Desired baud rate */
    bool        enable_tx;      /*!< Enable transmitter */
    bool        enable_rx;      /*!< Enable receiver */
} uart_config_t;


/**
 * @struct uart_t
 * @brief  UART Device Handle structure.
 * @note   'base' must be the first member to allow safe casting to peripheral_t.
 */
typedef struct 
{
    peripheral_t    base;       /*!< Base peripheral structure */
    uart_config_t   config;     /*!< Current software configuration */
    uart_status_t   status;     /*!< Current software status */
} uart_t;


/* ========================================================================== */
/* Utility Casting Functions                                                  */
/* ========================================================================== */

/** 
 * @brief   Cast UART Handle to base peripheral structure.
 * @param   [in] uart Pointer to uart structure.
 * @return  Safe cast to peripheral_t pointer.
 */
static inline peripheral_t *uart_to_peripheral(uart_t *uart) 
{
    /* Safe cast - base is first member */
    return (peripheral_t *)uart;
}


/** 
 * @brief   Cast base peripheral structure to UART Handle.
 * @param   [in] periph Pointer to peripheral structure.
 * @return  Safe cast to uart_t pointer.
 */
static inline uart_t *peripheral_to_uart(peripheral_t *periph) 
{
    /* Safe cast if originally was uart_t */
    return (uart_t *)periph;
}


/* ========================================================================== */
/* Public API Prototypes                                                      */
/* ========================================================================== */

/* With error checking */

/**
 * @brief   Initialize UART driver
 * @param   [in] dev Pointer to UART structure
 * @param   [in] base_addr Base address of the UART peripheral
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_init(uart_t *dev, uint32_t base_addr);

/**
 * @brief   Deinitialize UART driver
 * @param   [in] dev Pointer to UART structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_deinit(uart_t *dev);

/**
 * @brief   Configure UART with specified parameters
 * @param   [in] dev Pointer to UART structure
 * @param   [in] config Pointer to configuration structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_configure(uart_t *dev, const uart_config_t *config);

/**
 * @brief   Get current UART configuration.
 * @param   [in] dev Pointer to UART structure.
 * @param   [out] config Pointer to store configuration.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t uart_get_config(uart_t *dev, uart_config_t *config);

/**
 * @brief   Set baud rate.
 * @param   [in] dev Pointer to UART structure.
 * @param   [in] clk_freq UART clock frequency.
 * @param   [in] baudrate Baud rate value.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
system_error_t uart_set_baud_rate(uart_t *dev, uint32_t clk_freq, uint32_t baudrate);

/**
 * @brief   Get current baud rate
 * @param   [in] dev Pointer to UART structure
 * @param   [in] clk_freq UART clock frequency
 * @param   [out] baudrate Pointer to store baud rate
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_get_baud_rate(uart_t *dev, uint32_t clk_freq, uint32_t *baudrate);

/**
 * @brief   Enable transmitter
 * @param   [in] dev Pointer to UART structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_enable_tx(uart_t *dev);

/**
 * @brief   Disable transmitter
 * @param   [in] dev Pointer to UART structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_disable_tx(uart_t *dev);

/**
 * @brief   Enable receiver
 * @param   [in] dev Pointer to UART structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_enable_rx(uart_t *dev);

/**
 * @brief   Disable receiver
 * @param   [in] dev Pointer to UART structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_disable_rx(uart_t *dev);

/**
 * @brief   Enable both transmitter and receiver
 * @param   [in] dev Pointer to UART structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_enable(uart_t *dev);

/**
 * @brief   Disable both transmitter and receiver
 * @param   [in] dev Pointer to UART structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_disable(uart_t *dev);

/**
 * @brief   Get UART status
 * @param   [in] dev Pointer to UART structure
 * @param   [out] status_out Pointer to store status information
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_get_status(uart_t *dev, uart_status_t *status_out);

/**
 * @brief   Check if transmitter is ready for new data
 * @param   [in] dev Pointer to UART structure
 * @param   [out] is_ready Pointer to store result
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_is_tx_ready(uart_t *dev, bool *is_ready);

/**
 * @brief   Check if transmitter is busy
 * @param   [in] dev Pointer to UART structure
 * @param   [out] is_busy Pointer to store result
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_is_tx_busy(uart_t *dev, bool *is_busy);

/**
 * @brief   Check if receive data is available
 * @param   [in] dev Pointer to UART structure
 * @param   [out] is_ready Pointer to store result
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_is_rx_ready(uart_t *dev, bool *is_ready);

/**
 * @brief   Transmit a single byte with timeout
 * @param   [in] dev Pointer to UART structure
 * @param   [in] data Data byte to transmit
 * @param   [in] timeout_us Timeout in microseconds (0 for no timeout)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_transmit_byte(uart_t *dev, uint8_t data, uint32_t timeout_us);

/**
 * @brief   Receive a single byte with timeout
 * @param   [in] dev Pointer to UART structure
 * @param   [out] data Pointer to store received data
 * @param   [in] timeout_us Timeout in microseconds (0 for no timeout)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_receive_byte(uart_t *dev, uint8_t *data, uint32_t timeout_us);

/**
 * @brief   Transmit a string (Blocking)
 * @param   [in] dev Pointer to UART structure
 * @param   [in] str Null-terminated string to transmit
 * @param   [in] timeout_us Timeout in microseconds per character (0 for no timeout)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_transmit_string(uart_t *dev, const char *str, uint32_t timeout_us);

/**
 * @brief   Transmit data buffer (Blocking)
 * @param   [in] dev Pointer to UART structure
 * @param   [in] data Pointer to data buffer
 * @param   [in] length Number of bytes to transmit
 * @param   [in] timeout_us Timeout in microseconds per byte (0 for no timeout)
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_transmit_data(uart_t *dev, const uint8_t *data, uint32_t length, uint32_t timeout_us);

/**
 * @brief   Clear status flags
 * @param   [in] dev Pointer to UART structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_clear_status(uart_t *dev);

/**
 * @brief   Reset UART to default state
 * @param   [in] dev Pointer to UART structure
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_reset(uart_t *dev);


#endif /* UART_H */