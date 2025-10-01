#ifndef MINISOC_TEST_H
#define MINISOC_TEST_H

// Memory Map
#define UART_BASE      0x20000000
#define GPIO_BASE      0x40000000
#define TIMER_BASE     0x30000000
#define SIM_CTRL_BASE  0x50000000  // Add this for test control

// Register Offsets
#define UART_TX_DATA   0x00
#define UART_RX_DATA   0x04
#define UART_BAUD_DIV  0x08
#define UART_CTRL      0x0C
#define UART_STATUS    0x10

#define GPIO_DATA      0x00
#define GPIO_DIR       0x04
#define GPIO_SET       0x08
#define GPIO_CLEAR     0x0C
#define GPIO_TOGGLE    0x10

#define TIMER_COUNT    0x00
#define TIMER_CMP      0x04
#define TIMER_CTRL     0x08
#define TIMER_STAT     0x0C

// Test Control
#define TEST_PASS_CODE 0x1234ABCD
#define TEST_FAIL_CODE 0xDEADBEEF

// Stack
#define STACK_BASE     0x10000FFC

#endif