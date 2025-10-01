/**
 * @file main.c
 * @brief Mini RV32I SoC Firmware Main Application
 */

#include "system.h"
#include "uart.h"
#include "timer.h"
#include "gpio.h"


/* ========================================================================== */
/* Variables Declaration                                                      */
/* ========================================================================== */

/* Global Peripheral Instances */
uart_t  uart0;
gpio_t  gpio0;
timer_t system_timer;


/* ========================================================================== */
/* Utility Functions                                                          */
/* ========================================================================== */

/**
 * @brief Basic String output via UART
 */
void print_string(const char* str) 
{
    while (*str)
    {
        uart_transmit_byte(&uart0, *str);
        str++;
    }
}



/**
 * @brief Initialize all peripherals
 */
void peripherals_init(void) 
{
    /* Initialize UART */
    uart_init(&uart0, UART_BASE_ADDRESS);
    uart_set_baud_rate(&uart0, SYSTEM_CLOCK_FREQ, UART_BAUD_115200);
    uart_enable(&uart0);

    /* Initialize GPIO */
    gpio_init(&gpio0, GPIO_BASE_ADDRESS);
    gpio_set_direction_pin(&gpio0, GPIO_PIN_0, GPIO_DIR_OUTPUT);

    /* Initialize System timer */
    timer_init(&system_timer, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    system_init_with_timer(&system_timer);
}


/**
 * @brief Simple LED Blink Demon
 */
void blink_led_demo(void)
{
    print_string("LED Blink Demo Started\r\n");

    for (int i = 0; i < 10; i++)
    {
        gpio_write_pin(&gpio0, GPIO_PIN_0, true);
        system_delay_ms(500);

        gpio_write_pin(&gpio0, GPIO_PIN_0, false);
        system_delay_ms(500);

        /* Send heartbeat over UART*/
        uart_transmit_byte(&uart0, '.');
    }

    print_string("\r\nLED Blink Demo Completed\r\n");   
}


/* ========================================================================== */
/* Main Function                                                              */
/* ========================================================================== */

/**
 * @brief Main application entry point
 */
int main(void) {
    /* Initialize system and peripherals */
    peripherals_init();
    
    print_string("\r\n");
    print_string("================================\r\n");
    print_string("Mini RV32I SoC Firmware Started\r\n");
    print_string("================================\r\n");
    print_string("System Clock: 50 MHz\r\n");
    print_string("UART Baud: 115200\r\n");
    print_string("Memory: 4KB IMEM + 4KB DMEM\r\n");
    print_string("================================\r\n\r\n");
    
    /* Run demos */
    blink_led_demo();
    
    print_string("\r\nAll demos completed. Entering main loop.\r\n");
    
    /* Main application loop */
    uint32_t counter = 0;
    while (1) {
        /* Blink LED slowly */
        gpio_write_pin(&gpio0, GPIO_PIN_0, (counter % 20) < 10);
        
        /* Periodic status message */
        if ((counter % 100) == 0) {
            print_string("System running... Counter: ");
            /* Simple integer to string conversion */
            char buf[10];
            char *p = buf;
            uint32_t n = counter;
            do {
                *p++ = '0' + (n % 10);
                n /= 10;
            } while (n > 0);
            while (p > buf) {
                uart_transmit_byte(&uart0, *--p);
            }
            print_string("\r\n");
        }
        
        system_delay_ms(100);
        counter++;
    }
    
    return 0; /* Never reached */
}