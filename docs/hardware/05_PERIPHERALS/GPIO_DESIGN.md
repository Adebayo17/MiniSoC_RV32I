# 05.2 GPIO Module Design

## 1. Overview

The GPIO (General Purpose Input/Output) module provides a flexible interface for digital I/O operations in the MiniSoC-RV32I system. It supports configurable pin directions, hardware-accelerated atomic bit operations, and strict input synchronization to prevent metastability.

As a slave on the Wishbone interconnect, it exposes a minimal yet highly optimized register map to the CPU, allowing independent control of up to 8 physical external pins.

### 1.1 Module Structure

```text
src/peripheral/gpio/
├── gpio_wrapper.v  # Wishbone B4 bus adapter
└── gpio.v          # Main GPIO core (Registers, Synchronizers, and I/O logic)
```

---

## 2. Hardware Architecture 

### 2.1 Block Diagram 


```text
┌───────────────────────────────────────────────────────────┐
│                    GPIO Module                            │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─────────────┐    ┌─────────────────┐                   │
│  │             │    │   Register      │                   │
│  │  Wishbone   │◄──►│     File        │                   │
│  │ Interface   │    │ • DATA (R/W)    │                   │
│  │             │    │ • DIR (R/W)     │                   │
│  └─────────────┘    │ • SET (Write)   │                   │
│                     │ • CLEAR (Write) │                   │
│                     │ • TOGGLE (Write)│                   │
│                     └────────┬────────┘                   │
│                              │                            │
│          ┌───────────────────┼───────────────────┐        │
│          │                   │                   │        │
│    ┌─────▼─────┐      ┌──────▼─────┐      ┌──────▼─────┐  │
│    │  Output   │      │ Direction  │      │   Input    │  │
│    │  Register │      │ Register   │      │ Synchron-  │  │
│    │ (out_reg) │      │ (dir_reg)  │      │  izer x8   │  │
│    └─────┬─────┘      └─────┬──────┘      └──────┬─────┘  │
│          │                  │                    ▲        │
│          ▼                  ▼                    │        │
│  ┌─────────────────────────────────────────────────────┐  │
│  │                   I/O Pad Resolution                │  │
│  └────────┬──────────────────┬────────────▲────────────┘  │
│           │ gpio_out         │ gpio_oe    │ gpio_in       │
│           ▼                  ▼            │               │
└───────────┼──────────────────┼────────────┼───────────────┘
            │                  │            │
         To Physical Tri-State Pads (`io_pad`)
```

---

## 3. Submodule Design Details

### 3.1 Input Synchronization (Metastability Protection)

External GPIO pins are driven by external hardware (buttons, sensors, other chips) which are completely asynchronous to the SoC's internal `clk`. Routing these signals directly into the SoC's combinational logic would violate setup/hold times and cause **metastability**.

To protect the system, every single input pin passes through a **Double-Flop Synchronizer**:

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

*Latency impact: Physical inputs take exactly 2 clock cycles to propagate to the `DATA` register.*

### 3.2 Output and Direction Control

The physical tri-state buffers at the top level of the SoC require two signals per pin: the data to drive (`gpio_out`), and the output enable signal (`gpio_oe`).
The GPIO core manages these synchronously:

```verilog
always @(posedge clk or negedge rst_n) begin
    // ...
    gpio_out <= out_reg;  // Drive output values
    gpio_oe  <= dir_reg;  // 1 = Output, 0 = Input (High-Z)
end
```

### 3.3 Hardware-Accelerated Atomic Operations

A common software bug in embedded systems occurs during **Read-Modify-Write (RMW)** operations. If software wants to set pin 0 to HIGH, it typically does `DATA = DATA | 0x01`. If an interrupt occurs between the Read and the Write, and the interrupt handler modifies pin 1, the main code will accidentally overwrite the handler's changes when it resumes.

To prevent this, the RTL provides dedicated hardware registers (`SET`, `CLEAR`, `TOGGLE`). Writing a `1` to any bit in these registers performs the operation atomically in a single clock cycle. Writing a `0` has no effect.

```verilog
// Inside the Write logic
if (sel_set)    out_reg <= out_reg | wbs_data_write[7:0];
if (sel_clear)  out_reg <= out_reg & ~wbs_data_write[7:0];
if (sel_toggle) out_reg <= out_reg ^ wbs_data_write[7:0];
```

---

## 4. Hardware/Software Interface (Register Map)

The GPIO module exposes 5 registers mapped to 32-bit Wishbone addresses. Because it is an 8-bit GPIO port, only the lowest 8 bits `[7:0]` of the 32-bit Wishbone data bus are utilized.

| Offset | Register Name    | Access        | Description                                           |
|--------|------------------|---------------|-------------------------------------------------------|
| `0x00` | `DATA`           | Read/Write    | Mixed-state data Register                             |
| `0x04` | `DIR`            | Read/Write    | `1` = Output, `0` = Input. Default is `0x00`.         |
| `0x08` | `SET`            | Write-Only    | Hardware atomic SET. `1` = Set output bit to High.    |
| `0x0C` | `CLEAR`          | Write-Only    | Hardware atomic CLEAR. `1` = Clear output bit to Low. |
| `0x10` | `TOGGLE`         | Write-Only    | Hardware atomic TOGGLE. `1` = Invert output bit.      |


### 4.1 The DATA Register Dual-Behavior

The `DATA` register is a derived signal. When the CPU reads it, the hardware returns a combination of the synchronized physical inputs and the internal output register, depending on the direction of each pin.

```verilog
assign data_reg = (dir_reg & out_reg) | (~dir_reg & gpio_in_sync);
```

- **For pins configured as Output (`DIR=1`)**: Returns the last value written to `out_reg`.
- **For pins configured as Input (`DIR=0`)**: Returns the synchronized state of the external physical pin `gpio_in_sync`.

### 4.2 Hardware/Software Co-Design Note

Because the `SET`, `CLEAR`, and `TOGGLE` registers are strictly Write-Only (reading them returns `0x00`), the C Driver (`sw/drivers/gpio/src/gpio.c`) implements a Software Shadow Cache.

The `gpio_t` structure maintains `status.output_values` in RAM. When the software calls `gpio_set_pin()`, it writes to the hardware `SET` register, and simultaneously updates its RAM cache. This allows the software to instantly know the state of all output pins without performing a slower, potentially ambiguous Read-Modify-Write on the Wishbone bus.

---

## 5. Performance Characteristics
- **Clock Domain:** All logic is fully synchronous to the main system `clk`.
- **Input Latency:**  2 clock cycles (due to the anti-metastability synchronizers).
- **Output Latency:**  1 clock cycle (registered output to the physical pad).
- **Register State:** Safe default. `out_reg` = `0x00` (Low), `dir_reg` = `0x00` (Inputs / High-Impedance).
