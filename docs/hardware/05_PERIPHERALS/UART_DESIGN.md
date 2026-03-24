# 05.1 UART Peripheral Design

## 1. Overview

The UART (Universal Asynchronous Receiver-Transmitter) module provides serial communication capabilities for the MiniSoC-RV32I. It implements a standard asynchronous serial interface configured for **8N1** operation (8 data bits, No parity, 1 stop bit).

As a slave on the Wishbone interconnect, this module exposes control, status, and data registers to the CPU. It handles the parallel-to-serial conversion for transmission and serial-to-parallel conversion for reception, operating entirely in polling mode (no hardware interrupts).

### 1.1 Module Structure

The UART hardware is decoupled into several submodules for clarity and maintainability:

```text
src/peripheral/uart/
├── uart_wrapper.v  # Wishbone B4 bus adapter (Not detailed here)
├── uart.v          # Main top-level module & Register File
├── uart_tx.v       # Transmitter FSM
├── uart_rx.v       # Receiver FSM & Synchronizers
└── uart_baudgen.v  # Baud rate tick generator
```

---

## 2. Hardware Architecture

### 2.1 Block Diagram

```text
┌──────────────────────────────────────────────────────────┐
│                    UART Module                           │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────┐       ┌─────────────────┐               │
│  │             │       │    Register     │               │
│  │  Wishbone   │◄─────►│      File       │               │
│  │  Interface  │       │  • TX_DATA      │               │
│  │             │       │  • RX_DATA      │               │
│  └─────────────┘       │  • BAUD_DIV     │               │
│                        │  • CTRL         │               │
│                        │  • STATUS       │               │
│                        └────────┬────────┘               │
│                                 │                        │
│         ┌───────────────────┼───────────────────┐        │
│         │                   │                   │        │
│  ┌─────▼─────┐       ┌──────▼─────┐       ┌─────▼─────┐  │
│  │           │       │    Baud    │       │           │  │
│  │  UART TX  │       │ Generator  │       │  UART RX  │  │
│  │           │       │            │       │           │  │
│  └─────┬─────┘       └────────────┘       └──────┬────┘  │
│        │                                         │       │
│        ▼                                         ▼       │
│  uart_tx (output)                        uart_rx (input) │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## 3. Submodule Design Details

### 3.1 Baud Rate Generator (`uart_baudgen.v`)

To synchronize with standard serial terminals (e.g., PuTTY, TeraTerm), the UART must sample and transmit bits at a specific frequency (Baud Rate).

Instead of generating a physical clock (which would create complex clock domain crossings in the FPGA), the generator produces a single-cycle baud_tick enable signal.

- **Calculation**: `BAUD_DIV = System_Clock_Frequency / Desired_Baud_Rate`
- **Default**: At a 12 MHz system clock, a divisor of `104` yields ~115200 baud.

### 3.2 Receiver & Metastability Protection (`uart_rx.v`)

The `uart_rx` pad is driven by an external, asynchronous device (like a PC). Feeding this signal directly into the SoC's synchronous state machines would cause **metastability**, potentially corrupting the receiver logic.

To prevent this, the RX path implements a **Double-Flop Synchronizer**:

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        uart_rx_sync <= 1'b1;
        uart_rx_prev <= 1'b1;
    end else begin
        uart_rx_sync <= uart_rx;       // Stage 1: Captures async input (potentially metastable)
        uart_rx_prev <= uart_rx_sync;  // Stage 2: Stable synchronous signal
    end
end
```

**RX FSM Operation**:

1. **Start Bit Detection**: A falling edge (`uart_rx_prev == 1 && uart_rx_sync == 0`) kicks off the FSM.

2. **Oversampling**: The FSM counts baud ticks to sample the data exactly in the middle of the bit period, maximizing noise tolerance.

3. **Shift Register**: Reconstructs the byte by shifting in LSB first: `rx_shift_reg <= {uart_rx_sync, rx_shift_reg[7:1]};`

### 3.3 Transmitter (`uart_tx.v`)

The transmitter uses a 4-state FSM (`IDLE`, `START`, `DATA`, `STOP`).

- It asserts `tx_busy` when a transmission is underway, and `tx_ready` when it is safe to write to the `TX_DATA` register.

- Data is shifted out LSB first, framed by a logical `0` (Start Bit) and a logical `1` (Stop Bit).

---

## 4. Hardware/software Interface (Register Map)

The UART exposes 5 registers mapped to 32-bit Wishbone addresses.

| Offset    | Register Name | Access        | Description                                                                               |
|-----------|---------------|---------------|-------------------------------------------------------------------------------------------|
| `0x00`    | `TX_DATA`     | Write-Only    | Triggers transmission. Hardware captures bits [7:0].                                      |
| `0x04`    | `RX_DATA`     | Read-Only     | Received byte. **Side effect: Reading this register automatically clears `RX_READY`.**    |
| `0x08`    | `BAUD_DIV`    | Read/Write    | 16-bit baud rate divisor.                                                                 |
| `0x0C`    | `CTRL`        | Read/Write    | Bit 0: `TX_ENABLE`, Bit 1: `RX_ENABLE`.                                                   |
| `0x10`    | `STATUS`      | Read/W1C      | See bit definitions below.                                                                |

### 4.1 Hardware Side-Effects and W1C Logic

To prevent race conditions between the CPU (Software) and the UART FSMs (Hardware), the `STATUS` register implements specific hardware patterns:

**Side-Effect: Read-to-Clear**

When the CPU reads the `RX_DATA` register, the hardware automatically clears the `RX_READY` status bit. This saves an extra Wishbone transaction in the software polling loop.

```verilog
if (rx_ready && !status_reg[STATUS_RX_READY]) begin
    status_reg[STATUS_RX_READY] <= 1'b1;     // HW FSM sets the flag
end else if (rx_data_read) begin
    status_reg[STATUS_RX_READY] <= 1'b0;     // HW clears flag when SW reads data
end
```

**Write-1-to-Clear (W1C)**

For error flags (`RX_OVERRUN` and `RX_FRAME_ERR`), standard Read/Write logic is dangerous. If software writes a `0` to clear a flag just as the hardware detects a new error and tries to write a `1`, the error is lost.

Instead, the hardware uses **Write-1-to-Clear** logic. The software must write a `1` to the specific bit position it wishes to clear. Writing a `0` has no effect.


```verilog
if (rx_overrun) begin
    status_reg[STATUS_RX_OVERRUN] <= 1'b1; // HW sets the flag
end else if (status_write && wbs_data_write[STATUS_RX_OVERRUN]) begin
    status_reg[STATUS_RX_OVERRUN] <= 1'b0; // SW writes 1 to clear
end

```

---

## 5. Error Detection

The receiver hardware natively detects two types of serial communication faults:

1. **Frame Error (`RX_FRAME_ERR`)**: Asserted if the FSM reaches the end of a byte but the expected Stop Bit is missing (reads as a `0`). Usually indicates a baud rate mismatch between the SoC and the external device.

2. **Overrun Error (`RX_OVERRUN`)**: Asserted if the FSM finishes receiving a new byte while the `RX_READY` flag is still high. This means the CPU was too slow to read the previous byte from `RX_DATA`, and data was permanently lost.

*For details on configuring and polling these registers via C software, refer to the Driver API in `docs/software/06_DRIVERS/02_UART_DRIVER.md`.*




