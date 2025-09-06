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
*To be defined*

### GPIO Peripheral (0x4000_0000)  
*To be defined*

