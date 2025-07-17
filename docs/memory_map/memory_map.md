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

### UART (0x2000_0000)

### TIMER (0x3000_0000)

### GPIO (0x4000_0000)