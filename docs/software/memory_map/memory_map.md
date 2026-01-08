# Memory Map

## Address Space Overview
| Region    | Base Address  | Size  | Description           | Access        |
|-----------|---------------|-------|-----------------------|---------------|
| IMEM      | 0x0000_0000   | 8KB   | Instruction Memory    | Read-only     |
| DMEM      | 0x1000_0000   | 4KB   | Data Memory           | Read/Write    |
| UART      | 0x2000_0000   | 4KB   | UART Peripheral       | Read/Write    |
| TIMER     | 0x3000_0000   | 4KB   | Timer Peripheral      | Read/Write    |
| GPIO      | 0x4000_0000   | 4KB   | GPIO Peripheral       | Read/Write    |

## Error Address Ranges
Any access outside these ranges returns:
- `0xDEAD_BEEF` for reads
- Ignored for writes (with ACK)

## Peripheral Register Maps
See individual driver documentation for register details.