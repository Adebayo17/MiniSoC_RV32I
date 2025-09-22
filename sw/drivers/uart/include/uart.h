/*
 * @file uart.h
 * @brief UART Driver
*/

#ifndef UART_H
#define UART_H

#include <stdint.h>
#include <stdbool.h>

/* Base Address Definition */
#define UART_BASE_ADDRESS           0x20000000u


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


/* Register Access Macros*/
#define REAG_REG(addr)              (*(volatile uint32_t *)(addr))
#define WRITE_REG(addr, value)      (*(volatile uint32_t *)(addr) = (value))

/* Bit Field Definition 
 *  BIT: If WIDTH=1
 *  POS: Bit Start Position
 *  WIDTH: Number of bits of the field
 *  MASK: Mask to modifiy the field
*/

/* REG_TX_DATA */
#define TX_DATA_POS                 0
#define TX_DATA_WIDTH               8
#define TX_DATA_MASK                ((0xFF) << TX_DATA_POS)

/* REG_RX_DATA */
#define RX_DATA_POS                 0
#define RX_DATA_WIDTH               8
#define RX_DATA_MASK                ((0xFF) << RX_DATA_POS)

/* REG_BAUD_DIV */
#define BAUD_DIV_POS                0
#define BAUD_DIV_WIDTH              16
#define BAUD_DIV_MASK               ((0xFFFF) << BAUD_DIV_POS)

/* REG_CTRL */
#define CTRL_TX_ENABLE_POS          0
#define CTRL_TX_ENABLE_BIT          (1 << CTRL_TX_ENABLE_POS)

#define CTRL_RX_ENABLE_POS          1
#define CTRL_RX_ENABLE_BIT          (1 << CTRL_RX_ENABLE_POS)


/* REG_STATUS */
#define STATUS_TX_EMPTY_POS         0
#define STATUS_TX_EMPTY_BIT         (1 << STATUS_TX_EMPTY_POS)

#define STATUS_TX_BUSY_POS          1
#define STATUS_TX_BUSY_BIT          (1 << STATUS_TX_BUSY_POS)

#define STATUS_RX_READY_POS         2
#define STATUS_RX_READY_BIT         (1 << STATUS_RX_READY_POS)

#define STATUS_RX_OVERRUN_POS       3
#define STATUS_RX_OVERRUN_BIT       (1 << STATUS_RX_OVERRUN_POS)

#define STATUS_RX_FRAME_ERR_POS     4
#define STATUS_RX_FRAME_ERR_BIT     (1 << STATUS_RX_FRAME_ERR_POS)



/*
 * @brief UART Device Structute
*/
typedef struct {
    uint32_t base_addr;
} uart_t;


/* Function Prototypes */

/*
 * @brief Initialize UART driver
 * @param dev : Pointer to UART structure
 * @param base_addr : Base address of the UART peripheral
*/
void uart_init(uart_t *dev, uint32_t base_addr);


/*
 * @brief Set baud rate divisor
 * @param dev : Pointer to UART structure
 * @param divisor : Baud rate divisor value
*/
void uart_set_baud_divisor(uart_t *dev, uint16_t divisor);

/*
 * @brief Get baud rate divisor
 * @param dev : Pointer to UART structure
 * @return : Current Baud rate divisor 
*/
uint16_t uart_get_baud_divisor(uart_t *dev);


/*
 * @brief Enable transmitter
 * @param dev : Pointer to UART structure
*/
void uart_enable_tx(uart_t *dev);

/*
 * @brief Disable transmitter
 * @param dev : Pointer to UART structure
*/
void uart_disable_tx(uart_t *dev);


/*
 * @brief Enable receiver
 * @param dev : Pointer to UART structure
*/
void uart_enable_rx(uart_t *dev);

/*
 * @brief Disable receiver
 * @param dev : Pointer to UART structure
*/
void uart_disable_rx(uart_t *dev);


/*
 * @brief Check if transmitter is ready for new data
 * @param dev : Pointer to UART structure
 * @return : true if transmitter is ready, false otherwise
*/
bool uart_tx_ready(uart_t *dev);

/*
 * @brief Check if transmitter is busy
 * @param dev : Pointer to UART structure
 * @return : true if transmitter is busy, false otherwise
*/
bool uart_tx_busy(uart_t *dev);


/*
 * @brief Check if receive data is available
 * @param dev : Pointer to UART structure
 * @return : true if data is available, false otherwise
*/
bool uart_rx_ready(uart_t *dev);

/*
 * @brief Check if receive overrun error
 * @param dev : Pointer to UART structure
 * @return : true if overrun error occured, false otherwise
*/
bool uart_rx_overrun(uart_t *dev);

/*
 * @brief Check for frame error
 * @param dev : Pointer to UART structure
 * @return : true if frame error occured, false otherwise
*/
bool uart_rx_frame_error(uart_t *dev);


/*
 * @brief Transmit a single byte
 * @param dev : Pointer to UART structure
 * @param data : Data byte to transmit
 * @return : true if data was queued for transmission, false if transmitter is busy
*/
bool uart_transmit_byte(uart_t *dev, uint8_t data);


/*
 * @brief Receive a single byte
 * @param dev : Pointer to UART structure
 * @param data : Pointer to store received Data 
 * @return : true if data was received, false if data is not available
*/
bool uart_receive_byte(uart_t *dev, uint8_t *data);


/*
 * @brief Transmit a string (Blocking)
 * @param dev : Pointer to UART structure
 * @param str : Null-terminated string to transmit
*/
void uart_transmit_string(uart_t *dev, const char *str);


/*
 * @brief Transmit data buffer (Blocking)
 * @param dev : Pointer to UART structure
 * @param data : Pointer to data buffer
 * @param length : Number of bytes to transmit
*/
void uart_transmit_data(uart_t *dev, const uint8_t *str, uint32_t length);


/*
 * @brief Clear status flags
 * @param dev : Pointer to UART structure
 * @note : Reading RX_DATA clears RX_READY flag automatically
*/
void uart_clear_status(uart_t *dev);

#endif /* UART_H */