# 01. System-On-Chip Architecture Overview

## 1. Introduction

The MiniSoC-RV32I is a minimalist System-on-Chip (SoC) built around a custom RISC-V RV32I processor core. This document provides a high-level overview of the system architecture, hardware components, and design philosophy.

### 1.1 Key Specification

| Feature               | Specification                             |
|-----------------------|-------------------------------------------|
| **CPU**               | 5-stage pipelined RV32I core              |
| **ISA**               | RISC-V RV32I Base Integer Instruction Set |
| **Data Width**        | 32-bit                                    |
| **Address Space**     | 32-bit (4GB)                              |
| **Memory**            | 32KB IMEM + 16KB DMEM                     |
| **Peripherals**       | UART, 32-bit Timer, 8-pin GPIO            |
| **Interconnect**      | Wishbone B4 Pipelined Bus                 |
| **Clocking**          | Single clock domain                       |
| **Reset**             | Synchronized multi-stage reset Tree       |


### 1.2 Design Philosophy

- **Educational & Verification Focus**: Designed for learning digital design, RISC-V architecture and functional verification.
- **Strict Modularity**: Clean RTL boundaries between CPU, interconnect, memory, and peripherals.
- **Simplicity**: RV32I-only. No M-extension, no CSRs, no interrupts/exceptions in the initial version.
- **FPGA/ASIC Ready**: Uses generic Verilog constructs, explicit synchronization, and physical I/O pads for real-world synthesis.

---

## 2. System Block Diagram

![Mini Soc Block Diagram](diagrams/soc_architecture.png)

---

## 3. Component Overview

### 3.1 CPU Core
- **5-stage pipeline**: Fetch, Decode, Execute, Memory, Writeback
- **Hazard handling**: Forwarding unit for data hazards and stall/flush mechanisms for control hazards.
- **Branch prediction**: Static "not-taken" prediction.
- **Memory interface**: Separate Instruction (Fetch) and Data (Memory) Wishbone master ports (Harvard architecture behavior over a Von Neumann bus space).

### 3.2 Memory System
Memory Hierarchy:

```text
┌─────────────────┐
│ CPU Core        │
├─────────────────┤
│ IMEM (32KB)     │ ◄── Instruction Fetch Port (wbs_imem_if)
│                 │ ◄── System Read Port (wbs_imem_ro)
├─────────────────┤
│ DMEM (16KB)     │ ◄── Data R/W Port (wbs_dmem)
└─────────────────┘
```

**Key RTL Features:**
- **IMEM Dual-Porting**: One port dedicated to CPU fetches, another mapped to the system bus allowing the C application to read constants (`.rodata`).
- **Memory Initialization**: Boot-time firmware loading via the dedicated `mem_init` hardware module (reads `firmware.mem`).

### 3.3 Wishbone Interconnect
- **Protocol**: Wishbone B4 (Pipelined).
- **Topology**: Single master (CPU Datz port) to multiple slaves (DMEM, UART, Timer, GPIO, IMEM_RO).
- **Latency**: 1-2 routine latency.

---

## 4. Clock and Reset Architecture

### 4.1 Clock Distribution

**Single Clock Domain**: All logic runs from the exact same clock source (`clk`). There are no asynchronous clock crossings inside the SoC.

### 4.2 Advanced Reset Architectures (Stages Reset)

In FPGA/ASIC design, de-asserting the reset line asynchronously can cause metastability. To prevent this, the `top_soc.v` module implements a **Synchronized Staged Reset Tree**.

The external `rst_n` signal is passed through a dual-flip-flop synchronizer (`rst_n_sync2`). The system then wakes up in three distinct stages:

| Stage | Reset Signal          | Wake-up Condition                         | Modules Affected                  |
|-------|-----------------------|-------------------------------------------|-----------------------------------|
| T0    | External              | Physical Pin                              | All domains                       |
| T1    | `memory_rst_n`        | `rst_n_sync2 == 1`                        | IMEM, DMEM, MEM_INIT              |
| T2    | `peripheral_rst_n`    | `memory_rst_n == 1` & `init_done == 1`    | UART, TIMER, GPIO, Interconnect   |
| T3    | `cpu_rst_n`           | Simultaneous with T2                      | CPU Core                          |

*Note: The CPU is held in reset until `mem_init` asserts `init_done` (meaning the firmware is fully loaded into IMEM).*

---

## 5. Physical I/O a,d Pad Controllers

To interact with the physical world, the top module instantiates bidirectional I/O Pads (`io_pad`). This allows a single physical wire to act as both an input and an output, managed by Verilog `inout` primitives and tristate buffers (`1'bz`).

### I/O Pad Logic Example (GPIO)

The internal GPIO core generates three signals per pin. The `io_pad` resolves them to the physical pin:

```verilog
io_pad gpio_pad_0 (
    .pad_in  (gpio_out[0]),  // Data from GPIO core to drive the pad
    .pad_out (gpio_in[0]),   // Data from pad to GPIO core
    .pad_oe  (gpio_oe[0]),   // Direction control (1 = Output)
    .pad_io  (gpio0_io)      // Physical bidirectional pin (inout)
);

```

--- 

## 6. Data Flow Examples

### 6.1 Instruction Fetch Flow

| Cycle | CPU Stage         | Wishbone Transaction          | Interconnect / Memory             |
|-------|-------------------|-------------------------------|-----------------------------------|
| 0     | Fetch Stage       | `STB=1`, `CYC=1`, `ADDR=PC`   | IMEM wrapper registers request    |
| 1     | (Pipeline)        | (Waiting for ACK)             | SRAM returns data                 |
| 2     | Instruction Ready | `ACK=1`, `DATA=instr`         | CPU latches instruction           |
| 3     | Decode Stage      | (next fetch starts)           | -                                 |


### 6.2 Load Operation Flow (DMEM)

| Cycle | Stage         | CPU Action            | Wishbone Action           |
|-------|---------------|-----------------------|---------------------------|
| 0     | Execute       | Calculate address     | -                         |
| 1     | Memory        | Request to DMEM       | `STB=1`, `CYC=1`, `WE=0`  |
| 2     | Memory        | Wait for response     | Slave processes           |
| 3     | Writeback     | Data receivied        | `ACK=1`, `DATA=value`     |

---

## 7. Configuration Parameters
The top_soc.v module exposes several parameters to make the SoC highly configurablr before synthesis or simulation.

| Parameter         | Default           | Description                           |
|-------------------|-------------------|---------------------------------------|
| `FIRMWARE_FILE`   | `"firmware.mem"`  | Initial firmware file                 |
| `ADDR_WIDTH`      | 32                | Address bus width                     |
| `DATA_WIDTH`      | 32                | Data bus width                        |
| `IMEM_SIZE_KB`    | 32                | Instruction memory size in KB         |
| `DMEM_SIZE_KB`    | 16                | Data memory size in KB                |
| `DATA_SIZE_KB`    | 4                 | Peripheral address space size         |
| `BAUD_DIV_RST`    | 104               | Default baud divisor (115200 @12MHz)  |
| `N_GPIO`          | 8                 | Number of GPIO pins                   |

---

## 8. Performances & Limitations

### 8.1 Throuput & Timing
- **Peak IPC**: 1 instruction/cycle (ideal conditions, no stalls).
- **Typical IPC**: 0.7-0.9 (accounting for branch flushes and load-use hazards).
- **Memory bandwidth**: 32 bits/cycle theoretical peak on the wishbone bus.

### 8.2 Known Architectural Limitations
1. **No Interrupts/Exceptions**: The current design relies purely on polling. Illegal instructions or misaligned accesses do not trigger hardware traps (though the Wishbone bus will return a `0xDEADBEEF` error pattern).
2. **Single Master**: Only the CPU can initiate bus transactions (No DMA controller).
3. **No Cache**: All memory accesses go directly to the SRAM blocks. (Latencies are low enough that caching is not required for the current target frequencies).

---

## 9. Verification Status
The hardware has been rigorously tested using a bottom-up methodology:

1. ✅ CPU Pipeline: Forwarding, hazards, and branches verified via unit testbenches.
2. ✅ Memory Subsystem: IMEM, DMEM, and boot-time initialization verified.
3. ✅ Wishbone Interconnect: Address decoding and all slave accesses verified.
4. ✅ Peripherals: UART (Baudgen, TX/RX FSMs), Timer, and GPIO atomic operations 1. verified.
5. ✅ System Integration: Full firmware execution simulated successfully (`integration_test.c`).