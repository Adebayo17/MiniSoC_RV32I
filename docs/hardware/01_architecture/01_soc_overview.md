# SoC Architecture Overview

## 1. Introduction

The MiniSoC-RV32I is a minimalist System-on-Chip (SoC) built around a custom RISC-V RV32I processor core. This document provides a high-level overview of the system architecture, components, and design philosophy.

### 1.1 Key Specifications

| Feature               | Specification                             |
|-----------------------|-------------------------------------------|
| **CPU**               | 5-stage pipelined RV32I core              |
| **ISA**               | RISC-V RV32I Base Integer Instruction Set |
| **Data Width**        | 32-bit                                    |
| **Address Space**     | 32-bit (4GB)                              |
| **Memory**            | 8KB IMEM + 4KB DMEM                       |
| **Peripherals**       | UART, Timer, GPIO                         |
| **Interconnect**      | Wishbone B4 Pipelined Bus                 |
| **Clock**             | Single clock domain                       |
| **Reset**             | Synchronized multi-stage reset            |

### 1.2 Design Philosophy

- **Educational Focus**: Designed for learning RISC-V and SoC design
- **Modularity**: Clean separation between CPU, memory, and peripherals
- **Simplicity**: RV32I-only, no interrupts/exceptions in initial version
- **Verification-First**: Comprehensive testbench infrastructure

## 2. System Block Diagram

![Mini Soc Block Diagram](../diagrams/soc_architecture.png)

## 3. Component Overview

### 3.1 CPU Core
- **5-stage pipeline**: Fetch, Decode, Execute, Memory, Writeback
- **Hazard handling**: Forwarding unit and hazard detection
- **Branch prediction**: Simple "not-taken" prediction
- **Memory interface**: Separate instruction and data Wishbone masters

### 3.2 Memory System
Memory Hierarchy:

```text
┌─────────────────┐
│ CPU Core        │
├─────────────────┤
│ IMEM (8KB)      │ ◄── Instruction Fetch Port
│                 │ ◄── System Read Port
├─────────────────┤
│ DMEM (4KB)      │ ◄── Data R/W Port
└─────────────────┘
```


**Key Features:**
- **IMEM**: Dual-port (CPU fetch + system bus), read-only during operation
- **DMEM**: Single-port with byte/half-word/word access support
- **Memory Initialization**: Boot-time firmware loading via `mem_init` module

### 3.3 Wishbone Interconnect
- **Protocol**: Wishbone B4 Pipelined
- **Topology**: Single master (CPU) to multiple slaves
- **Latency**: 2-3 cycle pipeline
- **Slaves**: IMEM, DMEM, UART, Timer, GPIO

### 3.4 Peripherals

#### 3.4.1 UART
- **Configuration**: 8N1 (8 data bits, no parity, 1 stop bit)
- **Baud Rate**: Programmable (default: 115200 @ 12MHz)
- **Features**: TX/RX independent enable, error detection

#### 3.4.2 Timer
- **Counter**: 32-bit free-running/one-shot
- **Prescaler**: ÷1, ÷8, ÷64, ÷1024
- **Features**: Compare match, overflow detection

#### 3.4.3 GPIO
- **Pins**: 8 bidirectional GPIOs
- **Features**: Per-pin direction control, atomic set/clear/toggle
- **Protection**: Input synchronizers for metastability prevention



## 4. Memory Map

### 4.1 Address Space Layout

| Region        | Base Address  | Size  | Description           | Access     |
|---------------|---------------|-------|-----------------------|------------|
| **IMEM**      | `0x0000_0000` | 8KB   | Instruction Memory    | Read-Only  |
| **DMEM**      | `0x1000_0000` | 4KB   | Data Memory           | Read/Write |
| **UART**      | `0x2000_0000` | 4KB   | UART Registers        | Read/Write |
| **Timer**     | `0x3000_0000` | 4KB   | Timer Registers       | Read/Write |
| **GPIO**      | `0x4000_0000` | 4KB   | GPIO Registers        | Read/Write |
| **Reserved**  | `0x5000_0000` | 3.5GB | Unused                | -          |

### 4.2 Memory Alignment
- **Word Access**: 32-bit aligned (address[1:0] = 00)
- **Half-word**: 16-bit aligned (address[0] = 0)
- **Byte**: Any address
- **Misaligned Access**: Detected and flagged (but not exception)

## 5. Clock and Reset Architecture

### 5.1 Clock Distribution

```text
      ┌─────────┐
      │  Clock  │
      │  Source │
      └────┬────┘
           │
      ┌────▼────┐
      │  Global │
      │  Clock  │
      └────┬────┘
    ┌──────┴──────┐
    ▼             ▼
┌──────────┐ ┌──────────┐
│ CPU      │ │ Memory   │
│ Domain   │ │ Domain   │
└──────────┘ └──────────┘
    │             │
    ▼             ▼
┌──────────┐ ┌──────────┐
│Peripheral│ │Pad Logic │
│ Domain   │ │ Domain   │
└──────────┘ └──────────┘
```

**Single Clock Domain**: All logic runs from the same clock source.


### 5.2 Reset Sequencing

| Time  | Reset Stage                                           | Modules Affected                  |
|-------|-------------------------------------------------------|-----------------------------------|
| T0    | Power-On                                              | All modules                       |
| T1    | Memory Reset Released `(memory_rst_n = 1)`            | IMEM, DMEM, MEM_INIT              |
| T2    | Peripheral Reset Released `(peripheral_rst_n = 1)`    | UART, TIMER, GPIO, Interconnect   |
| T3    | CPU Reset Released `(cpu_rst_n = 1)`                  | CPU Core                          |
| T4    | System Operational                                    | All modules                       |


## 6. Data Flow Examples

### 6.1 Instruction Fetch Flow

| Cycle | CPU Stage         | Wishbone Transaction      | Interconnect              |
|-------|-------------------|---------------------------|---------------------------|
| 0     | Fetch Stage       | STB=1, ADDR=PC            | Decode Address            |
| 1     | (Pipeline)        | (registered)              | Drive IMEM Slave          |
| 2     | Instruction Ready | ACK=1, DATA=instr         | Response mux              |
| 3     | Decode Stage      | (next fetch starts)       | Next transaction          |


### 6.2 Load Operation Flow

| Cycle | Stage         | CPU Action            | Wishbone Action       |
|-------|---------------|-----------------------|-----------------------|
| 0     | Execute       | Calculate address     | -                     |
| 1     | Memory        | Request to DMEM       | STB=1 to DMEM         |
| 2     | Memory        | Wait for response     | Slave processes       |
| 3     | Writeback     | Data receivied        | ACK=1, DATA=value     |




## 7. Configuration Parameters

### 7.1 Top-Level Parameters

| Parameter         | Default           | Description                           |
|-------------------|-------------------|---------------------------------------|
| `FIRMWARE_FILE`   | `"firmware.mem"`  | Initial firmware file                 |
| `ADDR_WIDTH`      | 32                | Address bus width                     |
| `DATA_WIDTH`      | 32                | Data bus width                        |
| `IMEM_SIZE_KB`    | 8                 | Instruction memory size in KB         |
| `DMEM_SIZE_KB`    | 4                 | Data memory size in KB                |
| `DATA_SIZE_KB`    | 4                 | Peripheral address space size         |
| `BAUD_DIV_RST`    | 104               | Default baud divisor (115200 @12MHz)  |
| `N_GPIO`          | 8                 | Number of GPIO pins                   |


### 7.2 Build-Time Configuration
The system can be configured by modifying parameters in `top_soc.v`:
```verilog
module top_soc #(
    parameter FIRMWARE_FILE = "firmware.mem",  // Change firmware
    parameter IMEM_SIZE_KB  = 8,               // Adjust memory sizes
    parameter DMEM_SIZE_KB  = 4,
    parameter BAUD_DIV_RST  = 104,             // Adjust baud rate
    parameter N_GPIO        = 8                // Change GPIO count
)
```

## 8. Performance Characteristics 
### 8.1 Timing Estimates

| Operation                 | Minimum Cycles    | Typical Cycles    |
|---------------------------|-------------------|-------------------|
| Instruction Fetch         | 2                 | 3                 |
| Register-Register ALU     | 1                 | 1                 |
| Load from DMEM            | 3                 | 4                 |
| Store to DMEM             | 3                 | 4                 |
| Peripheral Read           | 3                 | 4                 |
| Peripheral Write          | 3                 | 4                 |


### 8.2 Throughput
- **Peak IPC**: 1 instruction/cycle (no stalls)
- **Typical IPC**: 0.7-0.9 (accounting for hazards)
- **Memory bandwidth**: 32 bits/cycle theoretical


## 9. Design Limitations
### 9.1 Known Limitations

1. **No Interrupts**: Current design has no interrupt controller
2. **No Exceptions**: Illegal instruction/misaligned access not trapped
3. **Single Master**: Only CPU can initiate bus transactions
4. **Fixed Priority**: Wishbone has simple address-based decoding
5. **No Cache**: All memory accesses go directly to memories 


### 9.2 Scalability Considerations

The modular design allows for:

- Adding more peripherals by extending address decode
- Adding interrupt controller in future
- Replacing CPU with more advanced core
- Adding DMA controller for peripheral transfers


## 10. Verification Status
### 10.1 Verification Methodology

- **Unit Tests**: Each module has standalone testbench
- **Integration Tests**: SoC-level firmware tests
- **Random Testing**: CPU instruction sequence tests
- **Coverage**: Functional coverage for critical paths


### 10.2 Test Coverage Areas

1. ✅ CPU Pipeline (forwarding, hazards, branches)
2. ✅ Memory Subsystem (IMEM, DMEM, initialization)
3. ✅ Wishbone Interconnect (all slave accesses)
4. ✅ Peripherals (UART, Timer, GPIO functionality)
5. ⏳ System Integration (firmware execution)