/*
 * @file uart.h
 * @brief UART Driver
*/

#ifndef UART_H
#define UART_H

#include "../../../include/peripheral.h"       /* peripheral_t structure */
#include "../../../include/errors.h"           /* system_error_t */


/* ========================================================================== */
/* UART Memory Map Definitions                                                */
/* ========================================================================== */

/* Register Address Offsets */
#define REG_TX_DATA_OFFSET          0x00u
#define REG_RX_DATA_OFFSET          0x04u
#define REG_BAUD_DIV_OFFSET         0x08u
#define REG_CTRL_OFFSET             0x0Cu
#define REG_STATUS_OFFSET           0x10u


/* Register Address Calculation */
#define REG_TX_DATA_ADDR            (UART_BASE_ADDRESS + REG_TX_DATA_OFFSET  )
#define REG_RX_DATA_ADDR            (UART_BASE_ADDRESS + REG_RX_DATA_OFFSET  )
#define REG_BAUD_DIV_ADDR           (UART_BASE_ADDRESS + REG_BAUD_DIV_OFFSET )
#define REG_CTRL_ADDR               (UART_BASE_ADDRESS + REG_CTRL_OFFSET     )
#define REG_STATUS_ADDR             (UART_BASE_ADDRESS + REG_STATUS_OFFSET   )


/* ========================================================================== */
/* UART REG_TX_DATA Bit Definitions                                           */
/* ========================================================================== */

#define TX_DATA_POS                 0
#define TX_DATA_WIDTH               8
#define TX_DATA_MASK                BITMASK(TX_DATA_WIDTH, TX_DATA_POS)


/* ========================================================================== */
/* UART REG_RX_DATA Bit Definitions                                           */
/* ========================================================================== */

#define RX_DATA_POS                 0
#define RX_DATA_WIDTH               8
#define RX_DATA_MASK                BITMASK(RX_DATA_WIDTH, RX_DATA_POS)

/* ========================================================================== */
/* UART REG_BAUD_DIV Bit Definitions                                          */
/* ========================================================================== */

#define BAUD_DIV_POS                0
#define BAUD_DIV_WIDTH              16
#define BAUD_DIV_MASK               BITMASK(BAUD_DIV_WIDTH, BAUD_DIV_POS)


/* ========================================================================== */
/* UART REG_CTRL Bit Definitions                                              */
/* ========================================================================== */

#define CTRL_TX_ENABLE_POS          0
#define CTRL_TX_ENABLE_BIT          (1U << CTRL_TX_ENABLE_POS)

#define CTRL_RX_ENABLE_POS          1
#define CTRL_RX_ENABLE_BIT          (1U << CTRL_RX_ENABLE_POS)

#define CTRL_RESERVED_MASK          0xFFFFFFFCu                 /* Bits 31:2 reserved */

#define CTRL_ENABLE_MASK            (CTRL_TX_ENABLE_BIT | CTRL_RX_ENABLE_BIT)


/* ========================================================================== */
/* UART REG_STATUS Bit Definitions                                            */
/* ========================================================================== */

#define STATUS_TX_EMPTY_POS         0
#define STATUS_TX_EMPTY_BIT         (1U << STATUS_TX_EMPTY_POS)

#define STATUS_TX_BUSY_POS          1
#define STATUS_TX_BUSY_BIT          (1U << STATUS_TX_BUSY_POS)

#define STATUS_RX_READY_POS         2
#define STATUS_RX_READY_BIT         (1U << STATUS_RX_READY_POS)

#define STATUS_RX_OVERRUN_POS       3
#define STATUS_RX_OVERRUN_BIT       (1U << STATUS_RX_OVERRUN_POS)

#define STATUS_RX_FRAME_ERR_POS     4
#define STATUS_RX_FRAME_ERR_BIT     (1U << STATUS_RX_FRAME_ERR_POS)

#define STATUS_RESERVED_MASK        0xFFFFFFE0                  /* Bits 31:5 reserved */

#define STATUS_ERROR_MASK           (STATUS_RX_OVERRUN_BIT | STATUS_RX_FRAME_ERR_BIT)
#define STATUS_READY_MASK           (STATUS_TX_EMPTY_BIT | STATUS_RX_READY_BIT)


/* ========================================================================== */
/* UART Structure Definitions                                                 */
/* ========================================================================== */

#define UART_BAUD_9600              9600
#define UART_BAUD_19200             19200
#define UART_BAUD_38400             38400
#define UART_BAUD_57600             57600
#define UART_BAUD_115200            115200


/**
 * @brief UART Status structure
 */
typedef struct
{
    bool tx_ready;          /* Transmitter ready for new data */
    bool tx_busy;           /* Transmitter busy sending */
    bool rx_ready;          /* Receiver has data available */
    bool rx_overrun;        /* Receiver overrun error occurred */
    bool rx_frame_error;    /* Receiver frame error occurred */
} uart_status_t; 


/**
 * @brief UART Configuration structure
 */
typedef struct 
{
    uint32_t    baudrate;       /* Desired baud rate */
    bool        enable_tx;      /* Enable transmitter */
    bool        enable_rx;      /* Enable receiver */
} uart_config_t;


/**
 * @brief UART Device Structure
 */
typedef struct 
{
    peripheral_t    base;       /* Base peripheral structure */
    uart_config_t   config;     /* Current configuration */
    uart_status_t   status;     /* Current status */
} uart_t;



/* ========================================================================== */
/* Utility Functions                                                          */
/* ========================================================================== */

/** 
 * @brief Function that cast uart structure to peripheral structure
 * @param uart Pointer to uart structure
 * @return uart as peripheral 
 */
static inline peripheral_t *uart_to_peripheral(uart_t *uart) {
    return (peripheral_t *)uart;  // Safe cast - base is first member
}


/** 
 * @brief Function that cast peripheral uart structure to uart structure
 * @param uart Pointer to peripheral structure
 * @return peripheral as uart
 */
static inline uart_t *peripheral_to_uart(peripheral_t *periph) {
    return (uart_t *)periph;  // Safe cast if originally was uart_t
}


/* ========================================================================== */
/* Functions Prototypes                                                       */
/* ========================================================================== */

/* With error checking */

/**
 * @brief Initialize UART driver
 * @param dev Pointer to UART structure
 * @param base_addr Base address of the UART peripheral
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_init(uart_t *dev, uint32_t base_addr);

/**
 * @brief Deinitialize UART driver
 * @param dev Pointer to UART structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_deinit(uart_t *dev);

/**
 * @brief Configure UART with specified parameters
 * @param dev Pointer to UART structure
 * @param config Pointer to configuration structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_configure(uart_t *dev, const uart_config_t *config);

/**
 * @brief Get current UART configuration
 * @param dev Pointer to UART structure
 * @param config Pointer to store configuration
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_get_config(uart_t *dev, uart_config_t *config);

/**
 * @brief Set baud rate
 * @param dev Pointer to UART structure
 * @param clk_freq UART clock frequency
 * @param baudrate Baud rate value
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_set_baud_rate(uart_t *dev, uint32_t clk_freq, uint32_t baudrate);

/**
 * @brief Get current baud rate
 * @param dev Pointer to UART structure
 * @param clk_freq UART clock frequency
 * @param baudrate Pointer to store baud rate
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_get_baud_rate(uart_t *dev, uint32_t clk_freq, uint32_t *baudrate);

/**
 * @brief Enable transmitter
 * @param dev Pointer to UART structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_enable_tx(uart_t *dev);

/**
 * @brief Disable transmitter
 * @param dev Pointer to UART structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_disable_tx(uart_t *dev);

/**
 * @brief Enable receiver
 * @param dev Pointer to UART structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_enable_rx(uart_t *dev);

/**
 * @brief Disable receiver
 * @param dev Pointer to UART structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_disable_rx(uart_t *dev);

/**
 * @brief Enable both transmitter and receiver
 * @param dev Pointer to UART structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_enable(uart_t *dev);

/**
 * @brief Disable both transmitter and receiver
 * @param dev Pointer to UART structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_disable(uart_t *dev);

/**
 * @brief Get UART status
 * @param dev Pointer to UART structure
 * @param status Pointer to store status information
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_get_status(uart_t *dev, uart_status_t *status);

/**
 * @brief Check if transmitter is ready for new data
 * @param dev Pointer to UART structure
 * @param is_ready Pointer to store result
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_is_tx_ready(uart_t *dev, bool *is_ready);

/**
 * @brief Check if transmitter is busy
 * @param dev Pointer to UART structure
 * @param is_busy Pointer to store result
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_is_tx_busy(uart_t *dev, bool *is_busy);

/**
 * @brief Check if receive data is available
 * @param dev Pointer to UART structure
 * @param is_ready Pointer to store result
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_is_rx_ready(uart_t *dev, bool *is_ready);

/**
 * @brief Transmit a single byte with timeout
 * @param dev Pointer to UART structure
 * @param data Data byte to transmit
 * @param timeout_ms Timeout in milliseconds (0 for no timeout)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_transmit_byte(uart_t *dev, uint8_t data, uint32_t timeout_ms);

/**
 * @brief Receive a single byte with timeout
 * @param dev Pointer to UART structure
 * @param data Pointer to store received data
 * @param timeout_ms Timeout in milliseconds (0 for no timeout)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_receive_byte(uart_t *dev, uint8_t *data, uint32_t timeout_ms);

/**
 * @brief Transmit a string (Blocking)
 * @param dev Pointer to UART structure
 * @param str Null-terminated string to transmit
 * @param timeout_ms Timeout in milliseconds per character (0 for no timeout)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_transmit_string(uart_t *dev, const char *str, uint32_t timeout_ms);

/**
 * @brief Transmit data buffer (Blocking)
 * @param dev Pointer to UART structure
 * @param data Pointer to data buffer
 * @param length Number of bytes to transmit
 * @param timeout_ms Timeout in milliseconds per byte (0 for no timeout)
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_transmit_data(uart_t *dev, const uint8_t *data, uint32_t length, uint32_t timeout_ms);

/**
 * @brief Clear status flags
 * @param dev Pointer to UART structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_clear_status(uart_t *dev);

/**
 * @brief Reset UART to default state
 * @param dev Pointer to UART structure
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
system_error_t uart_reset(uart_t *dev);


#endif /* UART_H */