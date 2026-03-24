# 06. Timing Analysis & Verification

## 1. Overview

To ensure the functional correctness and architectural efficiency of the MiniSoC-RV32I, the project includes a comprehensive, automated top-level testbench (`tb_mini_rv32i_top.v`).

This testbench does not merely assert basic signal states; it executes a full compiled RISC-V firmware binary (`firmware.mem`), monitors internal pipeline propagation, emulates an external UART terminal, and automatically calculates the architectural timing metrics of the CPU.

--- 

## 2. Testbench Architecture

The testbench acts as the absolute top-level wrapper around the SoC and operates using a strictly defined Finite State Machine (FSM).

### 2.1 Verification FSM States

| State             | Purpose                                                                                                                   | Timeout / Failure Condition                                           |
| :---              | :---                                                                                                                      | :---                                                                  |
| `TB_MEM_INIT`     | Waits for the hardware `mem_init` controller to load the firmware into IMEM and clear DMEM.                               | Fails if `init_done` is not asserted within 100,000 cycles.           |
| `TB_CPU_RESET`    | Verifies the CPU correctly points to the Reset Vector (`0x00000000`) upon wake-up.                                        | Fails if `fetch_pc` diverges at boot.                                 |
| `TB_PIPELINE`     | Monitors the Program Counter (PC) to ensure it advances.                                                                  | Fails if the PC is frozen for 50 consecutive cycles (Stall lockup).   |
| `TB_PERIPH`       | Verifies that Wishbone Chip Select signals (`_select`) are successfully reaching the Slaves.                              | -                                                                     |
| `TB_FIRMWARE`     | Waits for the software to write the magic `TEST_PASS_CODE` (`0x1234ABCD`) to the simulated control address `0x50000000`.  | Fails if `MAX_SIM_CYCLES` is reached.                                 |

*Note: The address `0x50000000` is intentionally outside the valid Memory Map. It is normal to see an `[INTERCONNECT] Error: Invalid address` in the log when the test completes, as the hardware correctly traps the testbench signal.*

---

## 3. Transaction & Memory Latency

The theoretical CPI of a 5-stage pipeline is 1.0. However, the MiniSoC-RV32I connects its CPU to its memories via a pipelined Wishbone B4 interconnect. This architectural choice favors high clock frequencies (Fmax) by adding pipeline registers, but introduces latency.


### 3.1 Wishbone Transaction Duration

Every transaction on the Wishbone bus (Instruction Fetch or Data Read/Write) takes a minimum of **3 clock cycles**:

1. **Cycle 1**: CPU asserts `CYC`, `STB`, and `ADDR`.
2. **Cycle 2**: Interconnect registers the decode logic and drives the Slave.
3. **Cycle 3**: Interconnect registers the Slave's `ACK` and data, returning it to the CPU.

### 3.2 Per-Instruction Memory Latency

Because of the bus latency, instructions have the following minimum execution times:

| Instruction Type      | Memory Action                     | Pipeline Impact               | Minimum Duration  |
| :---                  | :---                              | :---                          | :---              |
| **ALU (ADD, SLL...)** | IMEM Fetch (3 cycles)             | Stall IF for 2 cycles         | **3 cycles**      |
| **Store (SW, SB...)** | IMEM Fetch (3) + DMEM Write (3)   | Stall IF (2) + Stall MEM (2)  | **5 cycles**      |
| **Load (LW, LB...)**  | IMEM Fetch (3) + DMEM Read (3)    | Stall IF (2) + Stall MEM (2)  | **5 cycles**      |
| **Load + Dependent**  | IMEM Fetch (3) + DMEM Read (3)    | Load + Load-Use Bubble (1)    | **6 cycles**      |

---

## 4. Architectural Timing Metrics

The testbench dynamically calculates the performance of the RISC-V core during execution by counting the total simulation cycles and the number of "Retired Instructions" (instructions that successfully exit the Writeback stage without being flushed or stalled).

### 4.1 Summary of Measurements (Tableau Récapitulatif)

The testbench provides a holistic view of the system's performance. Here are the key metrics extracted at the end of each simulation:

| Metric            | Typical Value     | Description / Significance                                                                                                    |
| :---              | :---              | :---                                                                                                                          |
| **Total Cycles**  | `~960,000`        | The absolute number of system clock cycles elapsed during the test. At 100MHz, 1,000,000 cycles = 10ms of real-world time.    |
| **Instr Retired** | `~200,000`        | Total number of valid RISC-V instructions fully executed. This excludes instructions flushed due to branch mispredictions.    |
| **CPI Average**   | `~4.74`           | **Cycles Per Instruction**. A critical metric showing pipeline efficiency. Lower is better.                                   |
| **Boot Latency**  | `~3,500 cycles`   | Time taken for the hardware to copy `.data` and zero `.bss` before jumping to `main()`.                                       |
| **UART TX Bytes** | `Variable`        | Number of characters successfully transmitted by the SoC and decoded by the testbench UART monitor.                           |


### 4.2 Real-World CPI Breakdown

A standard integration firmware test run yields the following results:

```text
[TB_TOP_LEVEL][ INFO] @9675175000 ns: Total Cycles: 967517
[TB_TOP_LEVEL][ INFO] @9675175000 ns: Instr Retired: 204151
[TB_TOP_LEVEL][ INFO] @9675175000 ns: CPI Average: 4.7392
```

**Why is the CPI ~4.74?**
This metric perfectly reflects the hardware reality of a pipelined bus without an Instruction Cache (ICache):

1. **Base Execution**: `1.0` cycle.

2. **Fetch Penalty**: `+ 2.0` cycles. Every single instruction fetched from IMEM incurs the 3-cycle Wishbone latency, stalling the pipeline for 2 extra cycles. *(Current subtotal: 3.0 CPI)*.

3. **Data Memory Penalty**: Loads and Stores add another 2 to 3 cycles of stall when accessing DMEM or Peripherals.

4. **Control Hazards**: Branch mispredictions and Jumps flush the pipeline, adding a 2-cycle penalty per occurrence.

5. **Load-Use Hazards**: Immediate data dependencies inject 1-cycle bubbles.

*Architectural Takeaway: To bring the CPI closer to 1.0 in future SoC iterations, the immediate bottleneck to resolve is the Fetch latency. Implementing an Instruction Cache (ICache) or a pre-fetcher between the IF stage and the Wishbone bus would instantly drop the CPI from ~4.74 to ~2.5.*

---

## 5. Pipeline Trace Logging & UART Output

### 5.1 Pipeline Trace (`mini_rv32i_top_cpu_trace.log`)

For deep timing analysis and debugging, the testbench generates a cycle-accurate log file. It dumps the Program Counter (PC) and the Instruction Hex code for all 5 pipeline stages simultaneously at every clock edge.

**Example: Memory Wait Stall (Wishbone Latency)**
The trace below shows the `EX`, `ID`, and `IF` stages freezing their PC values while waiting for a Wishbone transaction to complete in the `MEM` stage.

```text
  CYCLE    |   IF_PC    |   ID_PC    |   EX_PC    |   MEM_PC   |   WB_PC   
---------------------------------------------------------------------------
       50  | 00000028   | 00000024   | 00000020   | 0000001C   | 00000018
       51  | 00000028   | 00000024   | 00000020   | 0000001C   | xxxxxxxx  <-- WB Bubble (Wait for ACK)
       52  | 00000028   | 00000024   | 00000020   | 0000001C   | xxxxxxxx  <-- WB Bubble
       53  | 0000002C   | 00000028   | 00000024   | 00000020   | 0000001C  <-- Bus ACK received, pipeline advances
```

### 5.2 Virtual UART Terminal Extraction

The testbench continuously samples the `uart_tx` physical wire and decodes the standard 8N1 serial protocol. The decoded characters are printed to the main log `mini_rv32i_top.log` prefixed with `[UART TERMINAL]`.

To extract a clean, human-readable terminal output exactly as it would appear on a real hardware serial console (like PuTTY or Minicom), use the provided Python script:

```bash
python3 scripts/parse_uart.py build/sim/top/mini_rv32i_top.log
```

This script reconstructs the serial stream and outputs it both to the console and to a clean text file `uart_clean_output.txt`.