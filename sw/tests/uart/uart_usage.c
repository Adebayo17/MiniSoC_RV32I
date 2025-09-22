#include "uart.h"
#include <stdint.h>

int main(void) 
{
    uart_t uart0;

    /* Initialize UART */
    uart_init(&uart0, UART_BASE_ADDRESS);

    /* Enable transmitter and receiver */
    uart_enable_tx(&uart0);
    uart_enable_rx(&uart0);

    /* Transmit a string */
    uart_transmit_string(&uart0, "Hello, RISC-V!\r\n");

    /* Transmit Individual Bytes */
    uart_transmit_byte(&uart0, 'A');
    uart_transmit_byte(&uart0, 'B');
    uart_transmit_byte(&uart0, 'C');

    /* Receive Data (non-blocking) */
    uint8_t received_data;
    if (uart_receive_byte(&uart0, &received_data)) {
        /* Process received data */
    }

    /* Checks for erros */
    if (uart_rx_overrun(&uart0)) {
        uart_clear_status(&uart0);
    }

    return 0;
}