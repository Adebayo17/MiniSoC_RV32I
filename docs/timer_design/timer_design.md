# TIMER Module Design

## Overview
The Timer module provides precise timing functionality for the MiniSoC-RV32I system. It features a configurable counter with compare match detection, multiple operating modes, and programmable prescaling for flexible timing operations.

## Module Structure
```text
src/peripheral/timer/
├── timer.v              # Main TIMER module
├── timer_wrapper.v      # Wishbone bus wrapper
```

## Key Features
- **32-bit counter** with free-running and one-shot modes
- **Programmable prescaler** (1, 8, 64, 1024 division)
- **Compare match detection** with status flag
- **Overflow detection** at configurable value
- **Software reset** capability
- **Wishbone bus interface** for memory-mapped access
- **Status register** with event flags


## Design Implementation

### Core Architecture
The timer module consists of three main components:

- **Prescaler:** Divides the system clock
- **32-bit Counter:** Main timing element
- **Control Logic:** Manages modes and status

### Prescaler Logic
```verilog
wire [1:0] prescale_sel = ctrl_reg[CTRL_PRESCALE1:CTRL_PRESCALE0];
wire [31:0] prescale_max = (prescale_sel == PRESCALE_1)    ? 32'd1 :
                           (prescale_sel == PRESCALE_8)    ? 32'd8 :
                           (prescale_sel == PRESCALE_64)   ? 32'd64 :
                           (prescale_sel == PRESCALE_1024) ? 32'd1024 : 32'd1;
```

The prescaler generates single-clock pulses (`prescaler_tick`) at the divided frequency.

### Counter Operation Modes

**Free-Running Mode (default)**
- Counter increments continuously
- Wraps around at OVERFLOW_VALUE (0x1000 for testbench)
- Sets overflow flag on wrap-around

**One-Shot Mode**
- Counter stops after reaching compare value
- Match flag is set
- Requires software restart to continue


### Status management
Status flags are set by hardware events and cleared by software:

```verilog
// Set flags on events
if (match_flag)    status_reg[STATUS_MATCH]    <= 1'b1;
if (overflow_flag) status_reg[STATUS_OVERFLOW] <= 1'b1;

// Clear flags on status register write
if (status_read_match)    status_reg[STATUS_MATCH]    <= 1'b0;
if (status_read_overflow) status_reg[STATUS_OVERFLOW] <= 1'b0;
```

## Wishbone Interface

### Register Map
| Address       | Register      | Width | Access | Description             |
|---------------|---------------|-------|--------|-------------------------|
| `BASE + 0x00` | TIMER_COUNT   | 32    | R      | Counter Value           |
| `BASE + 0x04` | TIMER_CMP     | 32    | R/W    | Compare Value           |
| `BASE + 0x08` | TIMER_CTRL    | 5     | R/W    | Control Register        |
| `BASE + 0x0C` | TIMER_STATUS  | 2     | R/W    | Status Register         |


### Register Details

**TIMER_COUNT Register (0x000) - Read-only**
- Returns the current value of the 32-bit counter
- Continuously increments when timer is enabled
- Can be reset via control register or system reset

**TIMER_CMP Register (0x004) - Read/Write**
- Compare value for match detection
- When counter reaches this value, match flag is set
- Can be modified during timer operation

**TIMER_CTRL Register (0x008) - Read/Write**
| Bit   | Name       | Description                    |
|-------|------------|--------------------------------|
| 0     | ENABLE     | Timer enabled (1=enable)       |
| 1     | RESET      | Reset counter (auto-clears)    |
| 2     | ONESHOT    | One-shot Mode (1=one-shot)     |
| 4-3   | PRESCALE   | Clock prescaler selection      |

**Prescaler Values:**
- `00`: Clock / 1
- `01`: Clock / 8
- `10`: Clock / 64
- `11`: Clock / 1024

**TIMER_STATUS Register (0x00C) - Read/Write**
| Bit   | Name       | Description                  |
|-------|------------|------------------------------|
| 0     | MATCH      | Compare match occured        |
| 1     | OVERFLOW   | Counter overflow occured     |
**Note:** Writing `1` to any bit clears the status register
 

## Usage Examples

### Basic Timer Initialization
```c
// Initialize timer: free-running, prescale=1, enabled
*(volatile uint32_t*)(TIMER_BASE + 0x08) = 0x00000001;

// Set compare value for specific timeout
*(volatile uint32_t*)(TIMER_BASE + 0x04) = 1000000; // 10ms @100MHz

// Wait for match
while (!(*(volatile uint32_t*)(TIMER_BASE + 0x0C) & 0x1));

// Clear match flag
*(volatile uint32_t*)(TIMER_BASE + 0x0C) = 0x1;
```

### One-Shot Mode Operation
```c
// Configure one-shot mode
*(volatile uint32_t*)(TIMER_BASE + 0x08) = 0x00000005; // Enable + one-shot
*(volatile uint32_t*)(TIMER_BASE + 0x04) = 500000;     // 5ms delay

// Timer will stop automatically after match
```

### Software Reset
```c
// Reset counter without disabling timer
*(volatile uint32_t*)(TIMER_BASE + 0x08) = 0x00000003; // Enable + reset
// Reset bit auto-clears after one cycle
```

## Reset Behavior
- `count_reg`: Reset to `0`
- `cmp_reg`: Reset to `0`
- `ctrl_reg`: Reset to `0` (disabled, free-running, prescale=1)
- `status_reg`: Reset to `0` (flags cleared)
- **Prescaler:** Reset and stopped

## Performance Characteristics
- **Maximum Frequency:** System clock frequency
- **Minimum Frequency:** System clock / 1,048,576 (with prescaler)
- **Resolution:** 1 prescaled clock cycle
- **Latency:** 2-3 clock cycles for register access


## Error Handling
- **Invalid addresses:** Return 0 on read, ignore on write
- **Byte selects:** Supported for all byte lanes
- **Mode conflicts:** Resolved by priority (reset > enable)

## Test Coverage
The testbench thoroughly tests all the key functionality of the timer module:

- **Test 1: Reset Values**
    - Verifies all registers are properly initialized after reset
    - Checks COUNT, CMP, CTRL, and STATUS registers

- **Test 2: Free-Running Counter**
    - Tests basic timer enable/disable functionality
    - Verifies counter increments correctly
    - Confirms timer stops when disabled

- **Test 3: Compare Match**
    - Tests compare match detection
    - Verifies status flag setting
    - Tests flag clearing mechanism

- **Test 4: One-Shot Mode**
    - Tests one-shot operation mode
    - Verifies counter stops after match
    - Confirms status flag behavior

- **Test 5: Prescaler Functionality**
    - Tests different clock division settings
    - Verifies counter speed matches prescaler setting

- **Test 6: Status Register Operations**
    - Tests overflow detection
    - Verifies flag clearing works correctly
    - Tests multiple flag handling
