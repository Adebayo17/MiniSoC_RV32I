# 04. Memory System Architecture

## 1. Overview

The MiniSoC-RV32I memory system implements a strict **Harvard architecture internally** (separate instruction and data memory blocks) mapped onto a unified Wishbone physical memory space.

This document details the internal SRAM structures, the byte-enable masking logic for sub-word accesses, and the hardware bootloader (`mem_init`) responsible for loading the firmware binary into the simulated ROM before the CPU is released from reset.


### 1.1 Memory System Summary

| Component     | Default Size  | Type                      | Access Rights         | Features                                      |
|---------------|---------------|---------------------------|-----------------------|-----------------------------------------------|
| **IMEM**      | 32KB          | Instruction Memory        | Read-Only (Runtime)   | Dual-ported (Fetch & System Bus). Hardware write-protected. |
| **DMEM**      | 16KB          | Data Memory               | Read/Write            | BSingle-ported. Supports Byte, Half-Word, and Word accesses via Wishbone `SEL`. |
| **MEM_INIT**  | N/A           | Boot Controller           | Write-Only (Boot)     | FSM that loads `firmware.mem` into IMEM and zeroes out DMEM during system reset. |


### 1.2 Subsystem Block Diagram

```text
┌─────────────────────────────────────────────────────────────────────┐
│                      Memory System Architecture                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────┐             ┌─────────────────────┐        │
│  │      CPU Core       │             │   System Bus (WB)   │        │
│  ├─────────────────────┤             ├─────────────────────┤        │
│  │   IF: IMEM Master   │             │                     │        │
│  │  MEM: DMEM Master   │             │                     │        │
│  └─────────┬───────────┘             └──────────┬──────────┘        │
│            │                                    │                   │
│            ▼                                    ▼                   │
│     ┌──────────────┐                     ┌────────────────┐         │
│     │              │                     │                │         │
│     │   Wishbone   │                     │    Wishbone    │         │
│     │ Interconnect │                     │  Interconnect  │         │
│     │              │                     │                │         │
│     └──────┬───────┘                     └───────┬────────┘         │
│            │                                     │                  │
│            ▼                                     ▼                  │
│  ┌─────────────────┐             ┌─────────────────────┐            │
│  │                 │             │                     │            │
│  │  IMEM Wrapper   │◄────────────┤   mem_init Module   │            │
│  │  (0x0000_0000)  │    Init     │  (Boot Controller)  │            │
│  │                 │    Data     │                     │            │
│  └────────┬────────┘             └──────────┬──────────┘            │
│            │                                 │                      │
│            ▼                                 ▼                      │
│  ┌─────────────────┐             ┌─────────────────────┐            │
│  │    IMEM Core    │             │    DMEM Wrapper     │            │
│  │  Dual-port SRAM │             │    (0x1000_0000)    │            │
│  │  8KB (2048x32)  │             │                     │            │
│  └─────────────────┘             └──────────┬──────────┘            │
│                                              │                      │
│                                              ▼                      │
│                                  ┌─────────────────────┐            │
│                                  │      DMEM Core      │            │
│                                  │  Single-port SRAM   │            │
│                                  │    4KB (1024x32)    │            │
│                                  └─────────────────────┘            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Instruction Memory (IMEM)

### 2.1 Dual-Port Architecture
The `imem_wrapper.v` manages a dual-port SRAM block (`imem.v`)

1. **CPU Fetch Port (`wbs_if`)**: Exclusively connected to the CPU's IF stage. Used strictly for fetching 32-bit instructions.

2. **System Read Port (`wbs_ro`)**: Connected to the standard Wishbone interconnect. This allows the CPU's MEM stage to read constants (the `.rodata` section of the C binary, like strings or lookup tables) stored in the firmware.


### 2.2 Write Protection (ROM Emulation)

During runtime, the IMEM must act as a Read-Only Memory (ROM) to prevent runaway pointers from corrupting the executable code.

The Interconnect actively strips the Write Enable (`WE`) signal, but the `imem_wrapper.v` also enforces a secondary hardware protection:

```verilog
always @(posedge clk) begin
    if (wbs_if_cyc && wbs_if_stb && wbs_if_we) begin
        $display("[WARNING]: Attempted IMEM IF write at %h", wbs_if_addr);
        // The write is physically ignored by the SRAM array.
    end
end
```

*Note: Writes are exclusively permitted to the `mem_init` controller during the reset phase.*


---

## 3. Data Memory (DMEM)

The DMEM (`dmem_wrapper.v` +` dmem.v`) is a standard single-port SRAM acting as the system's Random Access Memory (RAM). It hosts the `.data`, `.bss`, Heap, and Stack sections of the C application.

### 3.1 Sub-Word Accesses & Byte Enables

RISC-V requires byte-addressability (`LB`, `SB`, `LH`, `SH`). Since the SRAM physical width is 32 bits, the hardware uses the Wishbone Byte Select (`SEL[3:0]`) lines to mask writes.

**Store Operations (Write)**

The CPU MEM stage dynamically generates the `wbm_dmem_sel` mask based on the instruction's `funct3` field and the two lowest bits of the target address:

| Instruction   | funct3    | Size | Alignment  | Byte Select Pattern       |
| :---          | :---      | :--- | :---       | :---                      |
| `SB`          | `000`     | Byte | Any        | `0001 << addr[1:0]`       |
| `SH`          | `001`     | Half | 2-byte     | `0011 << {addr[1], 1'b0}` |
| `SW`          | `010`     | Word | 4-byte     | `1111`                    |

The SRAM block applies this mask directly to the write registers:

```verilog
if (wbs_cyc && wbs_stb && wbs_we) begin
    if (wbs_sel[0]) mem[word_addr][7:0]   <= wbs_data_write[7:0];
    if (wbs_sel[1]) mem[word_addr][15:8]  <= wbs_data_write[15:8];
    if (wbs_sel[2]) mem[word_addr][23:16] <= wbs_data_write[23:16];
    if (wbs_sel[3]) mem[word_addr][31:24] <= wbs_data_write[31:24];
end
```

**Load Operations (Read)**

On a read, the DMEM always returns the full 32-bit word. It is the responsibility of the CPU's MEM stage to extract the correct byte/half-word and apply sign-extension (e.g., extending bit 7 of a loaded byte to bits 8-31 for an `LB` instruction, or padding with zeroes for `LBU`).

| Instruction   | funct3    | Size | Alignment  | Sign Extend   | Byte Select                                           |
| :---          | :---      | :--- | :---       | :---          | :---                                                  |
| `LB`          | `000`     | Byte | Any        | Yes           | `addr[1:0]` determines byte                           |
| `LH`          | `001`     | Half | 2-byte     | Yes           | `addr[1]=0`: `bytes 1,0`; `addr[1]=1`: `bytes 3,2`    |
| `LW`          | `010`     | Word | 4-byte     | No            | All bytes (`1111`)                                    |
| `LBU`         | `100`     | Byte | Any        | No            | `addr[1:0]` determines byte                           |
| `LHU`         | `101`     | Half | 2-byte     | No            | Based on `addr[1]`                                    |


---

## 4. Boot & Initialization System (`mem_init`)

FPGAs and ASICs do not magically wake up with C code inside their SRAM blocks. The `mem_init.v `hardware module acts as the SoC's bootloader.


### 4.1 Integration with the Staged Reset Tree

As documented in `01_SOC_OVERVIEW.md`, the SoC uses a 3-level reset tree. `mem_init` is the reason this tree exists:

1. **Level 1 Reset (`memory_rst_n`)**: Wakes up `mem_init`, IMEM, and DMEM.

2. **Initialization Phase**: `mem_init` reads the physical `firmware.mem` file (generated by the RISC-V GCC `objcopy` tool) using the Verilog `$readmemh` system task. It injects the binary into the IMEM and zeroes out the DMEM.

3. **Level 3 Reset (`cpu_rst_n`)**: Once initialization is complete, `mem_init` asserts the `init_done` signal. This releases the CPU from reset, allowing it to fetch the very first instruction at `0x0000_0000`.

### 4.2 State Machine TIming Diagram

```wavedrom
{ "signal": [
  { "name": "Clock",      "wave": "p...................." },
  { "name": "Reset",      "wave": "10..................1" },
  { "name": "init_start", "wave": "0.10................0" },
  { "name": "IMEM init",  "wave": "x.==..=x.............", "data": ["instr0", "instr1", "instrN"] },
  { "name": "DMEM init",  "wave": "x.......==..=x.......", "data": ["zero", "...", "zero"] },
  { "name": "init_done",  "wave": "0............1......." },
  { "name": "CPU start",  "wave": "0.............1......" }
],
  "head": {
    "text": "Hardware Bootloader Sequence (Staged Reset)",
    "tick": 0
  },
  "foot": {
    "text": "CPU remains safely parked in reset until firmware is fully loaded."
  }
}
```

---

## 5. Memory Exceptions & Software Co-Design

The memory hardware actively participates in system safety, but relies on the Software HAL (`sw/src/memory.c`) to complete the protection loop.

### 5.1 Alignment Detection

The RV32I specification dictates that words must be 4-byte aligned and half-words 2-byte aligned. The CPU's `mem_stage.v` detects misalignment:

```verilog
WORD:  if (alu_result_in[1:0] != 2'b00) begin
           load_misaligned  = is_load;
       end

```

**HW/SW Co-Design**: Because this lightweight SoC does not include an exception controller (Trap handler) to catch this hardware flag, the Software HAL strictly enforces alignment prior to generating the bus request (e.g., `system_read_word_safe` checks `(addr & 3U) != 0U` and returns `SYSTEM_ERROR_MEMORY_ACCESS`).


### 5.2 Out-of-Bounds Accesses

If the CPU requests an address outside the defined IMEM/DMEM parameters:

- **Hardware Response**: The interconnect intercepts the request and instantly replies with `ACK=1` and `DATA=0xDEAD_BEEF`.

- **Software Link**: The HAL (`sw/include/errors.h`) identifies `HARDWARE_ERROR_INVALID_ADDR` (`0xDEADBEEF`) and translates it to `SYSTEM_ERROR_INVALID_ADDRESS` to cleanly halt the C application.

---

## 6. Performance Characteristics

The internal SRAM blocks (`imem.v`, `dmem.v`) have a native latency of 1 cycle (synchronous read/write). However, because they are wrapped in Wishbone B4 interfaces and routed through the pipelined interconnect, the effective latency seen by the CPU pipeline is higher:

| Memory    | Operation     | CPU Latency       | Pipeline Breakdown                                    |
| :---      | :---          | :---              | :---                                                  |
| **IMEM**  | Fetch (IF)    | **2-3 cycles**    | Req(1) + Decode(1) + SRAM(1) + Resp(1) *(Pipelined)*  |
| **DMEM**  | Read (LW)     | **3-4 cycles**    | Mem Req(1) + Int. Decode(1) + SRAM(1) + Int. Resp(1)  |
| **DMEM**  | Write (SW)    | **2-3 cycles**    | Mem Req(1) + Int. Decode(1) + SRAM Write(1)           |

*Note: These latencies explain the necessity of the Load-Use Stall mechanism detailed in `02_CPU_PIPELINE.md`.*