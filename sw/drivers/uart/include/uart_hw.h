/**
 * @file    uart_hw.h
 * @brief   Hardware definitions for the UART peripheral.
 * @details Conforms to the Barr Group Embedded C Coding Standard.
 * Describes the register structure and hardware bit masks.
 */

#ifndef UART_HW_H
#define UART_HW_H

#include <stdint.h>

/* ========================================================================== */
/* UART Register Map Structure                                                */
/* ========================================================================== */

/**
 * @struct uart_regs_t
 * @brief Structure representing the UART register map.
 * @note Should correspond to the actual hardware layout of the UART peripheral.
 */
typedef struct 
{
    volatile uint32_t TX_DATA;    /*!< 0x00:  Transmit Data Register        */
    volatile uint32_t RX_DATA;    /*!< 0x04:  Receive Data Register         */
    volatile uint32_t BAUD_DIV;   /*!< 0x08:  Baud Rate Divider Register    */
    volatile uint32_t CTRL;       /*!< 0x0C:  Control Register              */
    volatile uint32_t STATUS;     /*!< 0x10:  Status Register               */
} uart_regs_t;


/* ========================================================================== */
/* UART REG_CTRL Bit Definitions                                              */
/* ========================================================================== */

#define UART_CTRL_TX_ENABLE_POS     (0U)
#define UART_CTRL_TX_ENABLE_BIT     (1UL << UART_CTRL_TX_ENABLE_POS)

#define UART_CTRL_RX_ENABLE_POS     (1U)
#define UART_CTRL_RX_ENABLE_BIT     (1UL << UART_CTRL_RX_ENABLE_POS)

#define UART_CTRL_ENABLE_MASK       (UART_CTRL_TX_ENABLE_BIT | UART_CTRL_RX_ENABLE_BIT)

/* ========================================================================== */
/* UART REG_STATUS Bit Definitions                                            */
/* ========================================================================== */

#define UART_STATUS_TX_EMPTY_POS    (0U)
#define UART_STATUS_TX_EMPTY_BIT    (1UL << UART_STATUS_TX_EMPTY_POS)

#define UART_STATUS_TX_BUSY_POS     (1U)
#define UART_STATUS_TX_BUSY_BIT     (1UL << UART_STATUS_TX_BUSY_POS)

#define UART_STATUS_RX_READY_POS    (2U)
#define UART_STATUS_RX_READY_BIT    (1UL << UART_STATUS_RX_READY_POS)

#define UART_STATUS_RX_OVERRUN_POS  (3U)
#define UART_STATUS_RX_OVERRUN_BIT  (1UL << UART_STATUS_RX_OVERRUN_POS)

#define UART_STATUS_FRAME_ERR_POS   (4U)
#define UART_STATUS_FRAME_ERR_BIT   (1UL << UART_STATUS_FRAME_ERR_POS)

#define UART_STATUS_ERROR_MASK      (UART_STATUS_RX_OVERRUN_BIT | UART_STATUS_FRAME_ERR_BIT)
#define UART_STATUS_READY_MASK      (UART_STATUS_TX_EMPTY_BIT | UART_STATUS_RX_READY_BIT)


#endif /* UART_HW_H */