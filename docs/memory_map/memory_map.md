# Memory Map - MiniSoC-RV32I

This document defines the memory layout of the MiniSoC-RV32I system. All addresses are 32-bit and word-aligned unless otherwire noted.

---

## Memory Regions

|Name           |Base Address   |Size   |Access |Description                     |
|---------------|---------------|-------|-------|--------------------------------|
| **IMEM**      | `0x0000_0000` | 4 KB  | R     | Instruction memory (read-only) |
| **DMEM**      | `0x1000_0000` | 4 KB  | R/W   | Data Memory                    |
| **UART**      | `0x2000_0000` | 4 KB  | R/W   | UART base register address     |
| **TIMER**     | `0x3000_0000` | 4 KB  | R/W   | TIMER base register address    |
| **GPIO**      | `0x4000_0000` | 4 KB  | R/W   | GPIO base register address     |


---

## Peripheral Register Descriptions

### UART Peripheral (0x2000_0000)

#### Register Map

| Offset | Name         | Width | Access | Description                    |
|--------|-------------|-------|--------|---------------------------------|
| `0x00` | TX_DATA     | 8     | W      | Transmit Data Register          |
| `0x04` | RX_DATA     | 8     | R      | Receive Data Register           |
| `0x08` | BAUD_DIV    | 16    | R/W    | Baud Rate Divisor Register      |
| `0x0C` | CTRL        | 8     | R/W    | Control Register                |
| `0x10` | STATUS      | 8     | R      | Status Register                 |

#### TX_DATA Register (0x00)
- **Write-only**: Writing to this register initiates transmission
- **Data**: 8-bit data to transmit

#### RX_DATA Register (0x04)  
- **Read-only**: Contains received data
- **Reading clears** the RX_READY status flag

#### BAUD_DIV Register (0x08)
- **Baud divisor**: `baud_rate = clock_frequency / (divisor + 1)`
- **Default**: 104 (for 115200 baud @ 12MHz)

#### CTRL Register (0x0C)
| Bit | Name         | Description                                      |
|-----|-------------|---------------------------------------------------|
| 0   | TX_ENABLE    | Transmitter enable (1 = enabled)                 |
| 1   | RX_ENABLE    | Receiver enable (1 = enabled)                    |
| 2   | TX_INT_EN    | Transmit interrupt enable (not implemented)      |
| 3   | RX_INT_EN    | Receive interrupt enable (not implemented)       |
| 7:4 | RESERVED     | Reserved for future use                          |

#### STATUS Register (0x10)
| Bit | Name           | Description                                |
|-----|---------------|---------------------------------------------|
| 0   | TX_EMPTY       | Transmitter ready for new data (1 = ready) |
| 1   | TX_BUSY        | Transmission in progress (1 = busy)        |
| 2   | RX_READY       | Receive data available (1 = ready)         |
| 3   | RX_OVERRUN     | Receive overrun error (1 = error)          |
| 4   | RX_FRAME_ERR   | Frame error (stop bit missing)             |
| 7:5 | RESERVED       | Reserved for future use                    |

---

### TIMER Peripheral (0x3000_0000)

#### Register Map

| Offset | Name         | Width | Access | Description                     |
|--------|-------------|-------|--------|---------------------------------|
| `0x00` | TIMER_COUNT | 32    | R      | Current timer value             |
| `0x04` | TIMER_CMP   | 32    | R/W    | Compare value                   |
| `0x08` | TIMER_CTRL  | 4     | R/W    | Control register                |
| `0x0C` | TIMER_STAT  | 2     | R/W    | Status register                 |

#### TIMER_CTRL Register (0x08)
| Bit | Name        | Description                     |
|-----|-------------|---------------------------------|
| 0   | ENABLE      | Timer enable (1 = enabled)      |
| 1   | RESET       | Reset Counter Reg (1 = reset)   |
| 2   | ONESHOT     | One-shot mode (1 = one-shot)    |
| 3-4 | PRESCALE    | Clock prescaler selection       |

#### Prescaler Values:
- `00`: Clock / 1
- `01`: Clock / 8  
- `10`: Clock / 64
- `11`: Clock / 1024

#### TIMER_STAT Register (0x0C)
| Bit | Name        | Description                     |
|-----|------------|----------------------------------|
| 0   | MATCH       | Compare match occurred          |
| 1   | OVERFLOW    | Counter overflow occurred       |


### GPIO Peripheral (0x4000_0000)  

#### Register Map

| Offset | Name       | Width | Access | Description                     |
|--------|-----------|-------|--------|---------------------------------|
| `0x00` | GPIO_DATA  | 8     | R/W    | Data Register                   |
| `0x04` | GPIO_DIR   | 8     | R/W    | Direction Register              |
| `0x08` | GPIO_SET   | 8     | W      | Set Bits Register               |
| `0x0C` | GPIO_CLEAR | 8     | W      | Clear Bits Register             |
| `0x10` | GPIO_TOGGLE| 8     | W      | Toggle Bits Register            |

#### GPIO_DATA Register (0x00)
- **Read**: Returns current pin states (both input and output)
- **Write**: Sets output pin values (for pins configured as outputs)

#### GPIO_DIR Register (0x04)
- **Bit values**: `1` = Output, `0` = Input
- **Default**: `0x00` (all inputs)

#### GPIO_SET Register (0x08) - Write-only
- Writing `1` to any bit sets the corresponding output pin
- Writing `0` has no effect

#### GPIO_CLEAR Register (0x0C) - Write-only  
- Writing `1` to any bit clears the corresponding output pin
- Writing `0` has no effect

#### GPIO_TOGGLE Register (0x10) - Write-only
- Writing `1` to any bit toggles the corresponding output pin
- Writing `0` has no effect

