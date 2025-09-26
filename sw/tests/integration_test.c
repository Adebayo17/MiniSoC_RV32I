/**
 * @file integration_test.c
 * @brief Comprehensive peripheral integration test
 */

#include "system.h"
#include "uart.h"
#include "gpio.h"
#include "timer.h"

void run_integration_test(void) {
    uart_t uart;
    gpio_t gpio;
    timer_t timer;
    
    /* Initialize all peripherals */
    uart_init(&uart, UART_BASE_ADDRESS);
    gpio_init(&gpio, GPIO_BASE_ADDRESS);
    timer_init(&timer, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);

    /* Initialize system timer with timer */
    // system_init_with_timer(&timer);
    
    /* Test GPIO */
    for (uint8_t pin = 0; pin < 8; pin++) {
        gpio_set_direction_pin(&gpio, pin, GPIO_DIR_OUTPUT);
        gpio_write_pin(&gpio, pin, true);
        system_delay_ms(50);
        gpio_write_pin(&gpio, pin, false);
    }
    
    /* Test UART */
    const char* test_msg = "UART Test Message\r\n";
    const char* p = test_msg;
    while (*p) {
        uart_transmit_byte(&uart, *p++);
    }
    
    /* Test Timer */
    uint32_t start = timer_get_count(&timer);
    system_delay_ms(1000);
    uint32_t end = timer_get_count(&timer);
    uint32_t elapsed = end - start;
    
    /* Report results via UART */
    const char* result_msg = "Integration Test Completed\r\n";
    p = result_msg;
    while (*p) {
        uart_transmit_byte(&uart, *p++);
    }
}