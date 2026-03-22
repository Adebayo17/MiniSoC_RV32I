/**
 * @file    main.c
 * @brief   Mini RV32I SoC Firmware Main Application.
 * @details Conforms to Barr Group Embedded C Coding Standard.
 */


/* System Headers */
#include "../include/system.h"
#include "../include/math.h"

/* Peripheral Headers */
#include "../drivers/uart/include/uart.h"
#include "../drivers/gpio/include/gpio.h"
#include "../drivers/timer/include/timer.h"


/* ========================================================================== */
/* Global Variables                                                           */
/* ========================================================================== */

/**
 * Witness variable to force the creation of a .data section
 * Volatile to prevent the compiler from optimizing it out.
 */
volatile uint32_t verification_canary = 0xCAFEBABE;


/**
 * Global Peripheral Instances
 */
static uart_t  uart0;
static gpio_t  gpio0;
static timer_t system_timer;


/* ========================================================================== */
/* Utility Functions (UART Output)                                            */
/* ========================================================================== */

/**
 * @brief   Safe string output via UART
 * @param   [in] str Null-terminated string to transmit
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t app_print_string(const char* str)
{
    system_error_t status = SYSTEM_SUCCESS;
    
    if (str == NULL) 
    {
        status = SYSTEM_ERROR_INVALID_PARAM;
    }
    else
    {
        uint32_t i = 0U;
        while (str[i] != '\0')
        {
            status = uart_transmit_byte(&uart0, (uint8_t)str[i], 100U); /* 100ms timeout */
            if (is_error(status))
            {
                break;
            }
            i++;
        }
    }
    
    return status;
}


/**
 * @brief   Safe integer to string conversion and output (Base 10).
 * @param   [in] value Integer value to print.
 * @return  SYSTEM_SUCCESS on success, error code on failure.
 */
static system_error_t app_print_integer(uint32_t value)
{
    char buf[12]; /* Enough for 32-bit decimal + null terminator */
    char *p = buf + sizeof(buf) - 1;
    uint32_t temp_val = value;
    
    *p = '\0';
    
    if (temp_val == 0U) 
    {
        p--;
        *p = '0';
    } 
    else 
    {
        while (temp_val > 0U) 
        {
            p--;
            *p = (char)('0' + (temp_val % 10U));
            temp_val /= 10U;
        }
    }
    
    return app_print_string(p);
}


/* ========================================================================== */
/* Initialization and Error Handling                                          */
/* ========================================================================== */

/**
 * @brief   Error handler for critical failures.
 * @param   [in] err Error code that occurred.
 */
static void handle_critical_error(system_error_t err)
{
    /* Attempt to report error via UART if possible (ignore return value here) */
    (void)app_print_string("\r\nCRITICAL ERROR: ");
    
    /* Simple error code display */
    if (err == SYSTEM_ERROR_INVALID_ADDRESS) 
    {
        (void)app_print_string("Invalid Address");
    }
     else if (err == SYSTEM_ERROR_MEMORY_ACCESS) 
    {
        (void)app_print_string("Memory Access Error");
    } 
    else if (err == SYSTEM_ERROR_HARDWARE) 
    {
        (void)app_print_string("Hardware Error");
    } 
    else 
    {
        (void)app_print_string("Unknown Code ");
        (void)app_print_integer((uint32_t)(-err));
    }
    
    (void)app_print_string("\r\nHALTING SYSTEM.\r\n");
    
    /* Blink LED rapidly to indicate error */
    while (1) 
    {
        (void)gpio_write_pin(&gpio0, GPIO_PIN_0, true);
        for (volatile uint32_t i = 0U; i < 100000U; i++) { /* Busy wait */ }

        (void)gpio_write_pin(&gpio0, GPIO_PIN_0, false);
        for (volatile uint32_t i = 0U; i < 100000U; i++) { /* Busy wait */ }
    }
}


/**
 * @brief   Initialize all peripherals with comprehensive error handling
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t peripherals_init(void)
{
    system_error_t status = SYSTEM_SUCCESS;
    uart_config_t uart_cfg;
    gpio_pin_config_t led_cfg;
    
    /* 1. Initialize and configure UART */
    status = uart_init(&uart0, UART_BASE_ADDRESS);
    if (is_success(status)) 
    {
        uart_cfg.baudrate  = UART_BAUD_RATE;
        uart_cfg.enable_tx = true;
        uart_cfg.enable_rx = true;
        status = uart_configure(&uart0, &uart_cfg);
    }
    
    /* 2. Initialize and configure GPIO */
    if (is_success(status)) 
    {
        status = gpio_init(&gpio0, GPIO_BASE_ADDRESS);
    }
    if (is_success(status)) 
    {
        led_cfg.pin           = GPIO_PIN_0;
        led_cfg.direction     = GPIO_DIR_OUTPUT;
        led_cfg.initial_value = false;
        status = gpio_configure_pin(&gpio0, &led_cfg);
    }
    
    /* 3. Initialize Timer and bind it to System Timebase */
    if (is_success(status)) 
    {
        status = timer_init(&system_timer, TIMER_BASE_ADDRESS, SYSTEM_CLOCK_FREQ);
    }
    if (is_success(status)) 
    {
        status = system_init_with_timer_safe(&system_timer);
    }
    
    return status;
}


/* ========================================================================== */
/* Application Demonstrations                                                 */
/* ========================================================================== */

/**
 * @brief   System information display
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t display_system_info(void)
{
    system_error_t status = SYSTEM_SUCCESS;
    
    if (is_success(status)) status = app_print_string("\r\n================================\r\n");
    if (is_success(status)) status = app_print_string("Mini RV32I SoC Firmware Started\r\n");
    if (is_success(status)) status = app_print_string("================================\r\n");
    
    if (is_success(status)) status = app_print_string("System Clock: ");
    if (is_success(status)) status = app_print_integer(SYSTEM_CLOCK_FREQ);
    if (is_success(status)) status = app_print_string(" Hz\r\n");
    
    if (is_success(status)) status = app_print_string("UART Baud:    ");
    if (is_success(status)) status = app_print_integer(UART_BAUD_RATE);
    if (is_success(status)) status = app_print_string(" bps\r\n");
    
    if (is_success(status)) status = app_print_string("Memory:       32KB IMEM + 16KB DMEM\r\n");
    if (is_success(status)) status = app_print_string("================================\r\n\r\n");
    
    return status;
}


/**
 * @brief   Simple LED Blink Demo with error handling
 * @return  SYSTEM_SUCCESS on success, error code on failure
 */
static system_error_t blink_led_demo(void)
{
    system_error_t status = app_print_string("LED Blink Demo Started\r\n");
    uint32_t i;

    for (i = 0U; (i < 10U) && is_success(status); i++)
    {
        status = gpio_write_pin(&gpio0, GPIO_PIN_0, true);
        if (is_success(status)) status = system_delay_ms_safe(200U);

        if (is_success(status)) status = gpio_write_pin(&gpio0, GPIO_PIN_0, false);
        if (is_success(status)) status = system_delay_ms_safe(200U);

        /* Send Heartbeat over UART */
        if (is_success(status)) status = uart_transmit_byte(&uart0, (uint8_t)'.', 100U);
    }

    if (is_success(status))
    {
        status = app_print_string("\r\nLED Blink Demo Completed\r\n");
    }

    return status;
}


/* ========================================================================== */
/* Main Function                                                              */
/* ========================================================================== */

/**
 * @brief Main application entry point.
 */
int main(void) 
{
    system_error_t status = SYSTEM_SUCCESS;
    uint32_t counter = 0U;

    /* 1. Memory Integrity Check */
    if (verification_canary != 0xCAFEBABE)
    {
        /* RAM is corrupted (buffer overflow or bad startup). Reboot immediately. */
        system_reset();
    }


    /* 2. System and Hardware Initialization */
    system_init();

    status = peripherals_init();
    if (is_error(status))
    {
        handle_critical_error(status); /* Never returns */
    }


    /* 3. Boot sequence */
    status = display_system_info();

    status = blink_led_demo();
    if (is_error(status))
    {
        (void)app_print_string("\r\nDemo interrupted. Entering fallback loop.\r\n");
    }
    else
    {
        (void)app_print_string("\r\nEntering main loop...\r\n");
    }


    /* 4.Main application Loop (Superloop) */
    while (1) 
    {
        /* Blink LED (50% duty cycle on a 20-tick period) */
        bool led_state = (counter % 20U) < 10U;
        (void)gpio_write_pin(&gpio0, GPIO_PIN_0, led_state);
        
        /* Periodic status message every 10 loops */
        if ((counter % 10U) == 0U) 
        {
            status = app_print_string("System running... Heartbeat: ");
            if (is_success(status)) status = app_print_integer(counter);
            if (is_success(status)) status = app_print_string("\r\n");
        }
        
        /* 100ms hardware delay */
        status = system_delay_ms_safe(100U);
        
        if (is_error(status)) 
        {
            /* Delay failed (e.g., Timer crashed), use bare-metal busy wait as fallback */
            for (volatile uint32_t i = 0U; i < 500000U; i++) { }
        }
        
        counter++;
    }
    
    /* Never reached */
    return 0;
}




