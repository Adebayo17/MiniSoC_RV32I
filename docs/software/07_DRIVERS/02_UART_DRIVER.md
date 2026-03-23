# UART Driver API

## Introduction

The UART (Universal Asynchronous Receiver-Transmitter) driver provides serial communication capabilities for the Mini RV32I SoC.

Since the SoC does not support hardware interrupts (IRQs), the UART driver operates entirely in **polling mode**. To prevent the CPU from hanging indefinitely if a peripheral fails or a cable is disconnected, all blocking transmission and reception functions implement a **safe timeout mechanism**.

---

## Hardware / Software Separation
Following the project's architecture guidelines, the UART driver is split into two distinct layers:

1. **Hardware Layer (`uart_hw.h`)**: Defines the physical memory map. It contains the register offsets (`REG_UART_TX_DATA`, `REG_UART_CTRL`), bit masks, and hardware access macros. Application code should never include this file directly.

2. **Software Layer (`uart.h` / `uart.c`)**: Provides the Object-Oriented C API. It defines the `uart_t` handle, configuration structures, and the public functions used by the application.

---

## The Driver Handle (uart_t)
To interact with the UART, you must instantiate a `uart_t` object. This structure caches the peripheral's configuration and status in DMEM, reducing unnecessary and slow Read-Modify-Write (RMW) operations on the Wishbone bus.

```c
typedef struct {
    peripheral_t    base;     /* Inherited base class (Validation & Base Address) */
    uart_config_t   config;   /* Software cache of the CTRL and BAUD registers */
    uart_status_t   status;   /* Software cache of the STATUS register */
} uart_t;
```

---

## Initialization & Configuration
Before transmitting or receiving data, the UART must be initialized with its physical base address (`0x20000000U`) and configured with a baud rate.

The standard frame format is fixed in hardware to **8N1** (8 data bits, No parity, 1 stop bit).

### Example: Basic Setup
```c
#include "system.h"
#include "errors.h"
#include "uart.h"

system_error_t setup_uart(uart_t *uart_dev) {
    system_error_t status = SYSTEM_SUCCESS;

    /* 1. Initialize the handle with the hardware base address */
    status = uart_init(uart_dev, UART_BASE_ADDRESS);

    /* 2. Configure baud rate and enable TX/RX */
    if (is_success(status)) {
        uart_config_t config;
        config.baudrate  = UART_BAUD_115200;
        config.enable_tx = true;
        config.enable_rx = true;
        
        status = uart_configure(uart_dev, &config);
    }

    return status;
}
```

---

## Data Transmission (TX)
The driver provides functions to transmit single bytes, buffers, or null-terminated strings. All TX functions require a `timeout_us` parameter.

The driver internally polls the `TX_EMPTY` or `TX_READY` bit in the UART Status register. If the hardware does not become ready before the timeout expires, the function safely aborts and returns `SYSTEM_ERROR_TIMEOUT`.

### Transmitting Data
```c
/* Transmit a single character with a 1000us (1ms) timeout */
status = uart_transmit_byte(&uart_dev, (uint8_t)'A', 1000U);

/* Transmit a standard C string */
status = uart_transmit_string(&uart_dev, "System Booting...\r\n", 5000U);

/* Transmit a raw data buffer */
uint8_t payload[] = {0x01, 0x02, 0x03};
status = uart_transmit_data(&uart_dev, payload, 3U, 2000U);
```

---

## Data Reception (RX)
Reception is also polling-based. The driver checks the `RX_READY` bit. If no data arrives within the timeout window, it returns `SYSTEM_ERROR_TIMEOUT`.

### Receiving Data
```c
uint8_t rx_byte = 0U;

/* Wait up to 10ms for an incoming character */
status = uart_receive_byte(&uart_dev, &rx_byte, 10000U);

if (is_success(status)) {
    /* Process the received byte */
} else if (status == SYSTEM_ERROR_TIMEOUT) {
    /* No data arrived, normal polling behavior, continue... */
}
```

---

## Status and Error Flags
The UART hardware can detect line errors. These can be read using the status API.

```c
uart_status_t current_status;
status = uart_get_status(&uart_dev, &current_status);

if (is_success(status)) {
    if (current_status.rx_overrun) {
        /* The CPU was too slow to read RX_DATA, bytes were lost */
    }
    if (current_status.rx_frame_error) {
        /* Stop bit not detected, possible baud rate mismatch */
    }
}

/* Clear hardware error flags (Write-1-to-Clear) */
status = uart_clear_status(&uart_dev);
```

---

## Complete Usage Example: Echo Server
This example demonstrates a safe, non-blocking echo server that receives a character and immediately transmits it back.

```c
#include "system.h"
#include "errors.h"
#include "uart.h"

int main(void) {
    system_error_t status = SYSTEM_SUCCESS;
    uart_t uart0;
    
    system_init();
    
    status = uart_init(&uart0, UART_BASE_ADDRESS);
    
    if (is_success(status)) {
        uart_config_t config;
        config.baudrate  = UART_BAUD_115200;
        config.enable_tx = true;
        config.enable_rx = true;
        status = uart_configure(&uart0, &config);
    }
    
    if (is_success(status)) {
        status = uart_transmit_string(&uart0, "Echo Server Ready.\r\n", 5000U);
    }
    
    if (is_error(status)) {
        while(1) { /* Initialization failed, halt CPU */ }
    }
    
    /* Main Superloop */
    while (1) {
        uint8_t incoming_char = 0U;
        
        /* Poll RX with a small 100us timeout */
        status = uart_receive_byte(&uart0, &incoming_char, 100U);
        
        if (is_success(status)) {
            /* Character received, echo it back immediately */
            (void)uart_transmit_byte(&uart0, incoming_char, 1000U);
            
            /* Echo newline nicely */
            if (incoming_char == (uint8_t)'\r') {
                (void)uart_transmit_byte(&uart0, (uint8_t)'\n', 1000U);
            }
        }
        
        /* If status is SYSTEM_ERROR_TIMEOUT, we simply ignore it and loop again */
    }
    
    return 0;
}
```