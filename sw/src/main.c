/**
 * @file main.c
 * @brief Mini RV32I SoC Firmware Main Application
 */


/* System Headers */
#include "../include/system.h"
#include "../include/math.h"

/* Peripheral Headers */
#include "../drivers/uart/include/uart.h"
#include "../drivers/gpio/include/gpio.h"
#include "../drivers/timer/include/timer.h"


/* ========================================================================== */
/* Global Peripheral Instances                                                */
/* ========================================================================== */

static uart_t  uart0;
static gpio_t  gpio0;
static timer_t system_timer;


/* ========================================================================== */
/* Utility Functions with Error Handling                                      */
/* ========================================================================== */

/**
 * @brief Safe string output via UART
 * @param str Null-terminated string to transmit
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t print_string_safe(const char* str)
{
    if (str == NULL) {
        return SYSTEM_ERROR_INVALID_PARAM;
    }
    
    system_error_t err;
    
    for (size_t i = 0; str[i] != '\0'; i++) {
        err = uart_transmit_byte(&uart0, str[i], 100); /* 100ms timeout */
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    return SYSTEM_SUCCESS;
}


/**
 * @brief Safe integer to string conversion and output
 * @param value Integer value to print
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t print_integer_safe(uint32_t value)
{
    char buf[12]; /* Enough for 32-bit decimal + null */
    char *p = buf + sizeof(buf) - 1;
    
    *p = '\0';
    
    if (value == 0) {
        *(--p) = '0';
    } else {
        while (value > 0) {
            *(--p) = '0' + (value % 10);
            value /= 10;
        }
    }
    
    return print_string_safe(p);
}

/**
 * @brief Initialize all peripherals with comprehensive error handling
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t peripherals_init_safe(void)
{
    system_error_t err;
    
    /* Initialize UART */
    err = uart_init(&uart0, UART_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        return err;
    }
    
    /* Configure UART */
    uart_config_t uart_config = {
        .baudrate = UART_BAUD_115200,
        .enable_tx = true,
        .enable_rx = true
    };
    
    err = uart_configure(&uart0, &uart_config);
    if (IS_ERROR(err)) {
        uart_deinit(&uart0);
        return err;
    }
    
    /* Initialize GPIO */
    err = gpio_init(&gpio0, GPIO_BASE_ADDRESS);
    if (IS_ERROR(err)) {
        uart_deinit(&uart0);
        return err;
    }
    
    /* Configure GPIO pin 0 as output */
    gpio_pin_config_t led_config = {
        .pin = GPIO_PIN_0,
        .direction = GPIO_DIR_OUTPUT,
        .initial_value = false
    };
    
    err = gpio_configure_pin(&gpio0, &led_config);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio0);
        uart_deinit(&uart0);
        return err;
    }
    
    /* Initialize System timer */
    err = timer_init(&system_timer, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    if (IS_ERROR(err)) {
        gpio_deinit(&gpio0);
        uart_deinit(&uart0);
        return err;
    }
    
    /* Initialize system with timer support */
    err = system_init_with_timer_safe(&system_timer);
    if (IS_ERROR(err)) {
        timer_deinit(&system_timer);
        gpio_deinit(&gpio0);
        uart_deinit(&uart0);
        return err;
    }
    
    return SYSTEM_SUCCESS;
}


/**
 * @brief Simple LED Blink Demo with error handling
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t blink_led_demo_safe(void)
{
    system_error_t err;
    
    err = print_string_safe("LED Blink Demo Started\r\n");
    if (IS_ERROR(err)) {
        return err;
    }
    
    for (int i = 0; i < 10; i++) {
        /* Turn LED on */
        err = gpio_write_pin(&gpio0, GPIO_PIN_0, true);
        if (IS_ERROR(err)) {
            return err;
        }
        
        err = system_delay_ms_safe(500);
        if (IS_ERROR(err)) {
            return err;
        }
        
        /* Turn LED off */
        err = gpio_write_pin(&gpio0, GPIO_PIN_0, false);
        if (IS_ERROR(err)) {
            return err;
        }
        
        err = system_delay_ms_safe(500);
        if (IS_ERROR(err)) {
            return err;
        }
        
        /* Send heartbeat over UART */
        err = uart_transmit_byte(&uart0, '.', 100);
        if (IS_ERROR(err)) {
            return err;
        }
    }
    
    err = print_string_safe("\r\nLED Blink Demo Completed\r\n");
    
    return err;
}


/**
 * @brief System information display
 * @return SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t display_system_info_safe(void)
{
    system_error_t err;
    
    err = print_string_safe("\r\n");
    if (IS_ERROR(err)) return err;
    
    err = print_string_safe("================================\r\n");
    if (IS_ERROR(err)) return err;
    
    err = print_string_safe("Mini RV32I SoC Firmware Started\r\n");
    if (IS_ERROR(err)) return err;
    
    err = print_string_safe("================================\r\n");
    if (IS_ERROR(err)) return err;
    
    err = print_string_safe("System Clock: ");
    if (IS_ERROR(err)) return err;
    
    err = print_integer_safe(SYSTEM_CLOCK_FREQ);
    if (IS_ERROR(err)) return err;
    
    err = print_string_safe(" Hz\r\n");
    if (IS_ERROR(err)) return err;
    
    err = print_string_safe("UART Baud: ");
    if (IS_ERROR(err)) return err;
    
    err = print_integer_safe(UART_BAUD_RATE);
    if (IS_ERROR(err)) return err;
    
    err = print_string_safe(" bps\r\n");
    if (IS_ERROR(err)) return err;
    
    err = print_string_safe("Memory: 8KB IMEM + 4KB DMEM\r\n");
    if (IS_ERROR(err)) return err;
    
    err = print_string_safe("================================\r\n\r\n");
    
    return err;
}


/**
 * @brief Error handler for critical failures
 * @param err Error code that occurred
 */
static void handle_critical_error(system_error_t err)
{
    /* Attempt to report error via UART if possible */
    (void)print_string_safe("\r\nCRITICAL ERROR: ");
    
    /* Simple error code display */
    if (err == SYSTEM_ERROR_INVALID_ADDRESS) {
        (void)print_string_safe("Invalid Address");
    } else if (err == SYSTEM_ERROR_MEMORY_ACCESS) {
        (void)print_string_safe("Memory Access Error");
    } else if (err == SYSTEM_ERROR_HARDWARE) {
        (void)print_string_safe("Hardware Error");
    } else {
        (void)print_string_safe("Unknown Error");
    }
    
    (void)print_string_safe("\r\n");
    
    /* Blink LED rapidly to indicate error */
    while (1) {
        (void)gpio_write_pin(&gpio0, GPIO_PIN_0, true);
        for (volatile int i = 0; i < 100000; i++); /* Busy wait */
        (void)gpio_write_pin(&gpio0, GPIO_PIN_0, false);
        for (volatile int i = 0; i < 100000; i++); /* Busy wait */
    }
}


/* ========================================================================== */
/* Main Function                                                              */
/* ========================================================================== */

/**
 * @brief Main application entry point
 */
int main(void) {

    system_error_t err;
    
    /* Initialize system (legacy, no error checking) */
    system_init();
    

    /* Initialize peripherals with error handling */
    err = peripherals_init_safe();
    if (IS_ERROR(err)) {
        handle_critical_error(err);
    }
    

    /* Display system information */
    err = display_system_info_safe();
    if (IS_ERROR(err)) {
        /* Non-critical error, continue anyway */
    }
    

    /* Run LED blink demo */
    err = blink_led_demo_safe();
    if (IS_ERROR(err)) {
        /* Demo failed, but continue to main loop */
        (void)print_string_safe("\r\nDemo failed, continuing to main loop\r\n");
    }
    

    (void)print_string_safe("\r\nAll demos completed. Entering main loop.\r\n");
    

    /* Main application loop */
    uint32_t counter = 0;
    while (1) {
        /* Blink LED slowly (2Hz) */
        bool led_state = (counter % 20) < 10;
        err = gpio_write_pin(&gpio0, GPIO_PIN_0, led_state);
        if (IS_ERROR(err)) {
            /* LED write failed, but continue */
        }
        
        /* Periodic status message every 10 seconds */
        if ((counter % 100) == 0) {
            err = print_string_safe("System running... Counter: ");
            if (!IS_ERROR(err)) {
                err = print_integer_safe(counter);
                if (!IS_ERROR(err)) {
                    err = print_string_safe("\r\n");
                }
            }
            /* Ignore UART errors in main loop */
        }
        
        /* 100ms delay */
        err = system_delay_ms_safe(100);
        if (IS_ERROR(err)) {
            /* Delay failed, use busy wait as fallback */
            for (volatile uint32_t i = 0; i < 500000; i++);
        }
        
        counter++;
    }
    
    /* Never reached */
    return 0;

}




