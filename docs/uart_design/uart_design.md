# UART Module Design

## Overview
The UART (Universal Asynchronous Receiver/Transmitter) module provides serial communication capabilities for the MiniSoC-RV32I. It implements a standard UART interface with configurable baud rate, 8 data bits, 1 stop bit, and no parity.

## Module Structure

```text
src/peripheral/uart/
├── uart.v # Main top-level module
├── uart_tx.v # Transmitter submodule
├── uart_rx.v # Receiver submodule
├── uart_wrapper.v # Wishbone bus wrapper
```


## Key Features
- **Baud Rate**: Configurable from 110 to 115200+ baud
- **Data Format**: 8 data bits, 1 stop bit, no parity
- **Flow Control**: None (simple point-to-point)
- **Error Detection**: Overrun and frame error detection
- **Memory Mapped**: Wishbone bus interface

## Transmitter Design (uart_tx.v)

### Operation
The transmitter uses a state machine with four states:
1. **IDLE**: Waiting for data, output high (idle state)
2. **START**: Send start bit (low) for one baud period
3. **DATA**: Send 8 data bits (LSB first)
4. **STOP**: Send stop bit (high) for one baud period

### Key Characteristics
- **LSB First**: Transmits least significant bit first (UART standard)
- **Blocking**: Only one transmission at a time
- **Status Flags**: Provides TX_EMPTY and TX_BUSY status

## Receiver Design (uart_rx.v)

### Metastability Protection: uart_rx_prev and uart_rx_sync

The receiver includes **double synchronization flip-flops** to prevent metastability:

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        uart_rx_sync <= 1'b1;
        uart_rx_prev <= 1'b1;
    end else begin
        uart_rx_prev <= uart_rx_sync;  // Previous synchronized value
        uart_rx_sync <= uart_rx;       // Synchronize async input
    end
end
```

**Why This is Necessary:**
1. **Metastability:** When an asynchronous signal (like UART_RX) is sampled by a clock, it can cause the flip-flop to enter a metastable state (neither 0 nor 1)

2. **Double Synchronization:** Using two flip-flops in series:
    - First flip-flop (`uart_rx_sync`): Captures the async signal, may be metastable
    - Second flip-flop (`uart_rx_prev`): Samples the (now stable) output of the first
    - This reduces the probability of metastability to very low levels

3. **Edge Detection:** The synchronized signals enable reliable edge detection
    ```verilog
    wire rx_falling_edge = uart_rx_prev && !uart_rx_sync;
    ```

### Receiver Operation
1. **Start Bit Detection:** Falling edge detection on synchronized RX signal

2. **Data Sampling:** Samples at middle of each bit period for stability

3. **Stop Bit Verification:** Checks for valid stop bit (high)

4. **Error Detection:** Frame errors and overrun detection

### Bit Order Handling
- **Receives LSB first** (UART standard)

- **Shifts in MSB** first to reconstruct original byte:
    ```verilog
    rx_shift_reg <= {uart_rx_sync, rx_shift_reg[7:1]};
    ```
    This ensures the first received bit (LSB) becomes the LSB of the reconstructed byte.

## Baud Rate Generation

### Implementation
```verilog
// Baud rate generator
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_counter <= 16'b0;
        baud_tick <= 1'b0;
    end else begin
        baud_tick <= 1'b0;
        if (baud_counter == 16'b0) begin
            baud_counter <= baud_div_reg;
            baud_tick <= 1'b1;
        end else begin
            baud_counter <= baud_counter - 1;
        end
    end
end
```

### Calculation
- **Baud divisor** = `clock_frequency / desired_baud_rate`
- **Example:** 12MHz clock, 115200 baud &rarr; 12_000_000 / 115200 &asymp; 104

## Wishbone Interface

### Register Map

| Address       | Register    | Width | Access | Description             |
|---------------|-------------|-------|--------|-------------------------|
| `BASE + 0x00` | TX_DATA     | 8     | Write  | Transmit Data           |
| `BASE + 0x04` | RX_DATA     | 8     | Read   | Receive Data            |
| `BASE + 0x08` | BAUD_DIV    | 16    | R/W    | Baud Rate Divisor       |
| `BASE + 0x0C` | CTRL        | 8     | R/W    | Control Register        |
| `BASE + 0x10` | STATUS      | 8     | Read   | Status Register         |

### Operation
- **Transmit:** Write to TX_DATA register starts transmission

- **Receive:** Read RX_DATA register to get received data and clear RX_READY flag

- **Configuration:** Set BAUD_DIV and CTRL registers for desired operation


## Error Handling
### Frame Errors
Detected when stop bit is not high (missing stop bit)

### Overrun Errors
Occurs when new data is received before previous data is read from RX_DATA register


## Performance Characteristics
- **Maximum Baud Rate:** ~1/16 of system clock frequency

- **Latency:** 10-12 bit periods per byte (start + 8 data + stop)

- **Throughput:** ~90% of theoretical maximum (accounting for stop bits)