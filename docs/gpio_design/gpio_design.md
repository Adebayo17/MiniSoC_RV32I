# GPIO Module Design

## Overview
The GPIO (General Purpose Input/Output) module provides a flexible interface for digital I/O operations in the MiniSoC-RV32I system. It supports configurable pin directions, atomic bit operations, and proper synchronization for reliable operation.

## Module Structure
```text
src/peripheral/gpio/
├── gpio.v              # Main GPIO module
├── gpio_wrapper.v      # Wishbone bus wrapper
```

## Key Features
- **8-bit GPIO interface** with individual pin control
- **Configurable direction** (input/output per pin)
- **Atomic operations** (SET, CLEAR, TOGGLE)
- **Wishbone bus interface** for memory-mapped access
- **Input synchronization** for metastability protection
- **Mixed I/O support** simultaneous input and output operations

## Design Implementation

### Core Architecture
The GPIO module uses three main internal components:

- Output Register (`out_reg`): Stores values for output pins
- Direction Register (`dir_reg`): Controls pin direction
- Input Synchronizers: Prevent metastability on input pins

### Data Register Behavior
The visible data_reg is a derived signal that combines both input and output states:
```verilog
assign data_reg = (dir_reg & out_reg) | (~dir_reg & gpio_in_sync);
```

This means:

- **Output pins:** Show the value from `out_reg`
- **Input pins:** Show the synchronized input value from `gpio_in_sync`


### Input Synchronization
Each GPIO input has a dual-flop synchronizer to prevent metastability:

```verilog
genvar i;
generate
    for (i = 0; i < N_GPIO; i = i + 1) begin : gpio_sync
        reg [1:0] sync_reg;
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)
                sync_reg <= 2'b00;
            else
                sync_reg <= {sync_reg[0], gpio_in[i]};
        end
        assign gpio_in_sync[i] = sync_reg[1];
    end
endgenerate
```

### Output Control
The physical output signals are driven based on the direction register:

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gpio_out <= {N_GPIO{1'b0}};
        gpio_oe  <= {N_GPIO{1'b0}};
    end else begin
        gpio_out <= out_reg;  // Drive output values
        gpio_oe  <= dir_reg;  // Control output enable
    end
end
```

## Wishbone Interface

### Register Map

| Address       | Register    | Width | Access | Description             |
|---------------|-------------|-------|--------|-------------------------|
| `BASE + 0x00` | GPIO_DATA   | 8     | R/W    | Data Register           |
| `BASE + 0x04` | GPIO_DIR    | 8     | R/W    | Direction Register      |
| `BASE + 0x08` | GPIO_SET    | 8     | Write  | Set Bits Register       |
| `BASE + 0x0C` | GPIO_CLEAR  | 8     | Write  | Clear Bits Register     |
| `BASE + 0x10` | GPIO_TOGGLE | 8     | Write  | Toggle Register         |

### Register Details

**GPIO_DATA Register (0x000)**
- **Read:** Returns current pin states
    - **Output pins:** driven values
    - **Input pins:** synchronized input values

- **Write:** Sets output values for pins configured as outputs

**GPIO_DIR Register (0x004)**
- **Bit mapping:** `1` = Output, `0` = Input
- **Default:** `0x00` (all inputs after reset)
- Controls the direction of each GPIO pin

**GPIO_SET Register (0x008) - Write-only**
- Writing `1` to any bit sets the corresponding output pin
- Writing `0` has no effect
- **Atomic operation:** `data_reg = data_reg | written_value`

**GPIO_CLEAR Register (0x00C) - Write-only**
- Writing `1` to any bit clears the corresponding output pin
- Writing `0` has no effect
- **Atomic operation:** `data_reg = data_reg & ~written_value`

**GPIO_TOGGLE Register (0x010) - Write-only**
- Writing `1` to any bit toggles the corresponding output pin
- Writing `0` has no effect
- **Atomic operation:** `data_reg = data_reg ^ written_value`

## Usage Examples

### Basic Configuration
```c
// Set pin 0 as output, others as inputs
*(volatile uint32_t*)(GPIO_BASE + 0x004) = 0x00000001;

// Set pin 0 high
*(volatile uint32_t*)(GPIO_BASE + 0x000) = 0x00000001;
```


### Atomic Operation
```c
// Set bit 2 (atomic)
*(volatile uint32_t*)(GPIO_BASE + 0x008) = 0x00000004;

// Clear bit 2 (atomic)
*(volatile uint32_t*)(GPIO_BASE + 0x00C) = 0x00000004;

// Toggle bit 2 (atomic)
*(volatile uint32_t*)(GPIO_BASE + 0x010) = 0x00000004;
```


### Mixed I/O
```c
// Set pins 0-3 as outputs, 4-7 as inputs
*(volatile uint32_t*)(GPIO_BASE + 0x004) = 0x0000000F;

// Set output values
*(volatile uint32_t*)(GPIO_BASE + 0x000) = 0x00000005;

// Read all pins (outputs + inputs)
uint8_t pin_states = *(volatile uint32_t*)(GPIO_BASE + 0x000);
```


## Reset Behavior
- `out_reg`: Cleared to `0x00` (all outputs low)
- `dir_reg`: Cleared to `0x00` (all pins as inputs)
- `gpio_out`: Driven low
- `gpio_oe`: All pins as inputs (high impedance)


## Performance Characteristics
- **Clock Domain:** All logic synchronous to clk
- **Input Latency:** 2 clock cycles (synchronization)
- **Output Latency:** 1 clock cycle
- **Wishbone Access:** 2-3 clock cycles per transaction

## Error Handling
- **Invalid addresses:** Return zero on read, ignore on write
- **Byte selects:** Only byte 0 is used for 8-bit operations
- **Metastability:** Protected by input synchronizers

## Test Coverage
The module includes comprehensive testing for:

- Reset initialization
- Direction control
- Output functionality
- Input synchronization
- Atomic operations
- Mixed I/O modes
- Wishbone interface compliance


