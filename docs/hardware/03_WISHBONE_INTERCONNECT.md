# 03. Wishbone Interconnect Architecture

## 1. Overview

The Wishbone B4 interconnect provides the communication backbone for the MiniSoC-RV32I system. It acts as a central router, connecting the single CPU master (Data/Peripheral port) to multiple memory and peripheral slaves.

This document details the pipelined architecture, address decoding logic, hardware error handling, and timing of the interconnect fabric.

### 1.1 Interconnect Summary

| Feature                   | Specification                                                 |
| :---                      | :---                                                          |
| **Protocol**              | Wishbone B4 (Pipelined Mode)                                  |
| **Topology**              | Single Master to Multiple Slaves (1-to-5)                     |
| **Pipeline Depth**        | 2 Regsiter Stages (3-cycle total round-trip latency)          |
| **Data/Address Width**    | 32-bit                                                        |
| **Slaves Supported**      | IMEM (Read-Only), DMEM, UART, TIMER, GPIO                     |
| **Hardware Exceptions**   | Intercepts invalid addresses (`0xDEAD_BEEF`, `0xBADADD01`)    |


### 1.2 System Context

```text
┌─────────────────────────────────────────────────────┐
│             System Interconnect Overview            │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────┐     ┌──────────────────────────┐   │
│  │             │     │  Wishbone Interconnect   │   │
│  │  CPU Core   │     │      (This Module)       │   │
│  │             │     │  ┌──────┬──────┬──────┐  │   │
│  │ ┌─────────┐ │     │  │      │      │      │  │   │
│  │ │Fetch IF │─┼─────►  │      │      │      │  │   │
│  │ └─────────┘ │     │  │ IMEM │ DMEM │ PERIP│  │   │
│  │             │     │  │      │      │ HERY │  │   │
│  │ ┌─────────┐ │     │  └──────┴──────┴──────┘  │   │
│  │ │Data MEM │─┼─────►  │      │      │      │  │   │
│  │ └─────────┘ │     │  │      │      │      │  │   │
│  └─────────────┘     │  └──────┴──────┴──────┘  │   │
│                      │           │      │       │   │
│                      │           ▼      ▼       │   │
│                      │      ┌────────┐ ┌───────┐│   │
│                      │      │ Instr  │ │ Data  ││   │
│                      │      │ Memory │ │Memory ││   │
│                      │      └────────┘ └───────┘│   │
│                      │           │      │       │   │
│                      │      ┌─────┬─────┬────┐  │   │
│                      │      │UART │TIMER│GPIO│  │   │
│                      │      └─────┴─────┴────┐  │   │
│                      └──────────────────────────┘   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 2. Pipeline Architecture

To achieve high clock frequencies, the interconnect does not route signals combinationally from the master to the slaves and back. Instead, it uses a **registered pipeline architecture** that breaks the critical path into manageable stages.

![Wishbone Pipeline Architectue](diagrams/wishbone_pipeline.png)

### 2.1 Stage 1: Combinational Decode & Input Register

When the CPU asserts a request (`wbm_cpu_cyc = 1` and `wbm_cpu_stb = 1`), the interconnect combinationally decodes the target address (`wbm_cpu_addr`).

At the next positive clock edge, the interconnect registers the master's signals and the decode results:

- `sel_slave_reg`: Identifies which slave (0 to 4) is targeted.
- `address_valid_reg`: Flag indicating if the address falls within a mapped region.
- `request_active_reg`: Flag indicating a valid Wishbone cycle is underway.


### 2.2 Stage 2: Combinational Slave Drive

Based entirely on the registered outputs of Stage 1, the interconnect asserts the `CYC` and `STB` signals for the specific targeted slave. All other slaves see `CYC=0` and `STB=0`.

*Note: Because the inputs are registered in Stage 1, the slaves see the request exactly 1 cycle after the CPU issued it.*


### 2.3 Stage 3: Response Multiplexing & Output Register

The targeted slave processes the request and responds with its `ACK` and `DATA_READ` signals. The interconnect multiplexes these responses based on `sel_slave_reg`.

At the next positive clock edge, the interconnect registers the slave's response and drives it back to the CPU (`wbm_cpu_ack` and `wbm_cpu_data_read`).

---

## 3. Transaction Latency & Timing

Because of the internal pipeline registers, the interconnect imposes a fixed routing latency.

### 3.1 Single Transaction Timeline

| Clock Cycle   | Actor             | Action                                                        |
| :---          | :---              | :---                                                          |
| **T0**        | **CPU**           | Asserts `CYC`, `STB`, `ADDR`, and `WE`.                       |
| **T0**        | **Interconnect**  | Registers request. Drives selected Slave.                     |
| **T0**        | **Slave**         | (Assuming 1-cycle slave like DMEM). Asserts `ACK` and `DATA`. |
| **T0**        | **Interconnect**  | Registers Slave response. Drives `wbm_cpu_ack`.               |
| **T0**        | **CPU**           | Reads `ACK` and `DATA`. Completes transaction.                |

**Total Round-Trip Latency**: 3 clock cycles. This perfectly explains why the CPU's `mem_stage` must stall the pipeline for at least 3 cycles during any memory instruction (``LW` / SW`).


### 3.2 Timing Diagram (Basic Read)

```waavedrom
{ "signal": [
  { "name": "clk",           "wave": "p..........." },
  { "name": "cyc_m / stb_m", "wave": "010........." },
  { "name": "addr_m",        "wave": "x=x.........", "data": ["A0"] },
  {"node": "..a", "step": 1},
  { "name": "stb_r (Stage1)","wave": "0.10........" },
  { "name": "addr_r (Stage1)","wave": "x.=x........", "data": ["A0"] },
  {"node": "...b", "step": 1},
  { "name": "ack_s (Slave)", "wave": "0..10......." },
  { "name": "data_s (Slave)","wave": "x..=x.......", "data": ["D0"] },
  {"node": "....c", "step": 1},
  { "name": "ack_m (Stage3)", "wave": "0...10......" },
  { "name": "data_m (Stage3)","wave": "x...=x......", "data": ["D0"] }
],
  "head": { "text": "Pipelined Reading: Propagation of the stages m -> r -> s" },
  "foot": { "text": "a: Stage 1 Register, b: Slave Access, c: Stage 3 Register" }
}
```

---

## 4. Memory Map & Address Decoding

The interconnect is highly configurable via Verilog parameters (`IMEM_SIZE_KB`, `DMEM_SIZE_KB`, `PERIPH_SIZE_KB`). The physical boundaries are calculated dynamically during synthesis.

**Default Memory Map**


| Slave         | Internal ID           | Base Address  | Default Size  | Access Mode    |
|---------------|---------------------- |---------------|---------------|----------------|
| **IMEM**      | `SLAVE_IMEM ` (`0`)   | `0x0000_0000` | 8 KB          | Read-only      |
| **DMEM**      | `SLAVE_DMEM ` (`1`)   | `0x1000_0000` | 4 KB          | Read/Write     |
| **UART**      | `SLAVE_UART ` (`2`)   | `0x2000_0000` | 4 KB          | Read/Write     |
| **TIMER**     | `SLAVE_TIMER ` (`3`)  | `0x3000_0000` | 4 KB          | Read/Write     |
| **GPIO**      | `SLAVE_GPIO ` (`4`)   | `0x4000_0000` | 4 KB          | Read/Write     |

---

## 5. Hardware Exception Handling

One of the most robust features of this interconnect is its ability to protect the system from software faults (e.g., rogue pointers) by intercepting invalid bus transactions and forcing a safe response

### 5.1 Invalid Address (Out of Bounds)

If the CPU requests an address that does not belong to any defined memory region (e.g., `0x5000_0000`), the interconnect prevents the bus from hanging.

- **Action**: Asserts `wbm_cpu_ack` immediately in Stage 3.
- **Returning Data**: `32'hDEAD_BEEF`.
- **Software Link**: The HAL (`sw/include/errors.h`) identifies this exact number and translates it to `SYSTEM_ERROR_INVALID_ADDRESS`.


### 5.2 Internal Decode Failure

If an address is flagged as valid, but the sel_slave_reg contains an invalid ID (SLAVE_NONE).

- **Action**: Asserts `wbm_cpu_ack` immediately.
- **Returned Data**: `32'hBADADD01`.
- **Software Link**: Translated by the HAL to `SYSTEM_ERROR_INVALID_SLAVE`.


### 5.3 IMEM Write Protection

The Instruction Memory (IMEM) is designed to act as ROM during standard operation. To prevent rogue pointers from overwriting the firmware, the interconnect actively strips the Write Enable (`WE`) signal when targeting the IMEM.

```verilog
SLAVE_IMEM: begin
    wbs_imem_cyc        = 1'b1;
    wbs_imem_stb        = 1'b1;
    wbs_imem_we         = 1'b0; // HARDWARE FORCED TO 0 (Read-Only)
    wbs_imem_addr       = wbm_cpu_addr_reg;
    wbs_imem_data_write = wbm_cpu_data_write_reg;
    wbs_imem_sel        = wbm_cpu_sel_reg;
end
```

---

## 6. Debug and Monitoring Features

The `wishbone_interconnect.v` file includes several simulation-only features wrapped in `synthesis translate_off` pragmas. These blocks consume zero FPGA/ASIC resources but provide crucial warnings during RTL simulation.

### 6.1 Combinatorial Loop Detection

Wishbone buses are susceptible to combinatorial loops if a slave asserts `ACK` combinationally based on STB, and the master drops `STB` combinationally based on `ACK`. The interconnect monitors the `wbm_cpu_stb` and `wbm_cpu_ack` signals. If they oscillate together for more than 10 consecutive ticks within the same clock cycle, it triggers a `$display` warning in the simulation console.

### 6.2 Access and Error Counters

The interconnect silently counts total valid transactions (`access_count`) and failed transactions (`error_count`). It automatically prints a warning to the console (`[INTERCONNECT] Error: Invalid address...`) whenever a `0xDEAD_BEEF` exception is generated, aiding firmware developers in tracking down segmentation faults in the bare-metal C code.