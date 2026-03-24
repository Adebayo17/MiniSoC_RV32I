# 05.3 Timer Peripheral Design

## 1. Overview

The Timer module provides precise hardware timing capabilities for the MiniSoC-RV32I system. It features a 32-bit synchronous counter, a programmable clock prescaler, and a digital comparator to trigger events at specific intervals.

As a slave on the Wishbone interconnect, it exposes control and status registers to the CPU. In the current SoC architecture, this hardware module is highly privileged: it is exclusively bound to the software's `system.c` layer to act as the **System Timebase**, providing the foundational tick for `system_delay_us()` and `system_get_time_us()`.

### 1.1 Module Structure
```text
src/peripheral/timer/
├── timer_wrapper.v  # Wishbone B4 bus adapter
└── timer.v          # Main Timer core (Registers, Prescaler, Counter, Comparator)
```

---

## 2. Hardware Architecture

### 2.1 Block Diagram

```text
┌─────────────────────────────────────────────────────────────┐
│                       Timer Core Module                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────────┐                     │
│  │             │    │  Wishbone Regs  │                     │
│  │  Wishbone   │◄──►│                 │                     │
│  │  Interface  │    │ • COUNT (RO)    │                     │
│  │             │    │ • CMP (R/W)     │                     │
│  └──────┬──────┘    │ • CTRL (R/W)    │                     │
│         │           │ • STATUS (W1C)  │                     │
│         │           └────────┬────────┘                     │
│         │                    │                              │
│         │       ┌────────────┼─────────────┐                │
│         │       │            │             │                │
│   ┌─────▼───────▼─┐   ┌──────▼──────┐   ┌──▼────────────┐   │
│   │   System clk  ├──►│  Prescaler  ├──►│    32-bit     │   │
│   │               │   │ (/1 to /1024)   │    Counter    │   │
│   └───────────────┘   └─────────────┘   └──┬─────────┬──┘   │
│                                            │         │      │
│                                            │  ┌──────▼────┐ │
│                                            │  │ Overflow  │ │
│                                            │  │ Detection │ │
│                                            │  └──────┬────┘ │
│                                            ▼         │      │
│                       ┌─────────────────────────┐    │      │
│                       │   Digital Comparator    │    │      │
│                       │    (COUNT == CMP ?)     │    │      │
│                       └────────────┬────────────┘    │      │
│                                    │                 │      │
│                                    ▼                 ▼      │
│                        Hardware Status Flags (MATCH, OVF)   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Submodule Design Details

### 3.1 Prescaler and Base Frequency

The timer does not necessarily increment on every system clock cycle. The hardware includes a prescaler logic block that divides the incoming system clock by generating a periodic `prescaler_tick` enable signal.

Configured via the `CTRL` register, the supported division ratios are:

- `/1`: 1 tick per system clock cycle (Highest resolution, used for microsecond delays).
- `/8`
- `/64`
- `/1024`: 1 tick every 1024 clock cycles (Used for very long timeout periods).


### 3.2 Operating Modes

The timer hardware supports two distinct counting modes, controlled by the `ONESHOT` bit in the `CTRL` register:

1. **Continuous Mode (Free-Running)**:
    - The counter increments until it reaches the maximum 32-bit value (`0xFFFFFFFF`).
    - Upon reaching the maximum, it automatically wraps around to `0` and sets the `OVERFLOW` hardware flag.
    - If `COUNT` matches the `CMP` register during the cycle, the `MATCH` flag is set, but the counter keeps running.

2. **One-Shot Mode**:
    - The counter increments until it precisely matches the `CMP` register.
    - Upon matching, the `MATCH` flag is set, and the hardware **automatically clears the `ENABLE` bit** in the `CTRL` register.
    - The counter stops and freezes its value. It requires software intervention (a Reset pulse and re-enabling) to run again.


### 3.3 Hardware Auto-Clearing Reset Pulse

To reset the timer safely without requiring software to perform a complex Read-Modify-Write sequence, the `CTRL` register implements an **auto-clearing reset bit**.

When software writes a `1` to the `RESET` bit (bit 1 of `CTRL`), the hardware forces the internal counter to `0x00000000` and immediately clears the `RESET` bit back to `0` on the very next clock cycle. This creates a clean, 1-cycle internal synchronous reset pulse.

---

## 4. Hardware/Software Interface (Register Map)

The Timer module exposes 4 registers mapped to 32-bit Wishbone addresses.

| Offset | Register Name| Access                | Description                                   |
|--------|--------------|-----------------------|-----------------------------------------------|
| `0x00` | `COUNT`      | Read-Only             | Current 32-bit counter value.                 |
| `0x04` | `CMP`        | Read/Write            | 32-bit Compare value target.                  |
| `0x08` | `CTRL`       | Read/Write            | Configuration (Enable, Reset, Mode, Prescale).|
| `0x0C` | `STATUS`     | Read/Write-1-to-Clear | Match and Overflow event flags.               |

### 4.1 CTRL Register Bitfield

| Bit     | Name         | Description                                                      |
|---------|--------------|------------------------------------------------------------------|
| `0`     | `ENABLE`     | `1` = Timer running, `0` = Timer stopped/frozen.                 |
| `1`     | `RESET`      | `1` = Triggers hardware reset of `COUNT`. Auto-clears to `0`.    |
| `2`     | `ONESHOT`    | `1` = One-Shot mode, `0` = Continuous mode.                      |
| `4:3`   | `PRESCALE`   | `00` = /1, `01` = /8, `10` = /64, `11` = /1024.                  |

### 4.2 Write-1-to-Clear (W1C) Status Logic

Just like the UART, the Timer uses **Write-1-to-Clear** logic for its `STATUS` register.

- Bit `0`: `MATCH`
- Bit `1`: `OVERFLOW`

If software detects a match, it must explicitly write `0x00000001` to the `STATUS` register to clear the flag. Writing `0` has no effect. This absolutely prevents software from accidentally clearing a newly-occurred Overflow flag while trying to clear the Match flag.

### 4.3 Hardware/Software Co-Design Note (System Timebase)

In this specific SoC architecture, the `timer.v` module acts as the "heartbeat" of the software environment. As seen in `sw/src/system.c`, the initialization routine `system_init_with_timer_safe()` strictly forces the timer hardware into Continuous Mode with a **Prescaler of 1** and a **Compare value of 0xFFFFFFFF**.

By allowing the 32-bit hardware counter to free-run at the exact system clock frequency (e.g., 100 MHz), the software can read the `COUNT` register at any time to calculate absolute elapsed time, enabling robust, overflow-safe implementations of `system_delay_us()` and `system_get_time_us()`.

*Note: Consequently, the One-Shot hardware mode and the Compare logic are fully functional in RTL but are generally left unused by the default firmware HAL to preserve the integrity of the global timebase.*

---

## 5. Performance Characteristics
- **Clock Domain**: Fully synchronous to the system `clk`.
- **Resolution**: 1 system clock period (e.g., 10 ns at 100 MHz when prescaler is `/1`).
- **Maximum Duration**: Before overflow, a 32-bit counter at 100 MHz can track up to `~42.9` seconds.
- **Wishbone Read Latency**: Reading the `COUNT` register "on-the-fly" while the timer is running incurs exactly the standard 2-3 cycles pipeline latency, returning a perfectly deterministic snapshot of the counter at the moment the Wishbone `STB` signal arrived.