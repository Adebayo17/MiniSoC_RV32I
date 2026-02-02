# Memory System Architecture

## 1. Overview

The MiniSoC-RV32I memory system implements a Harvard architecture with separate instruction and data memories. This document describes the memory hierarchy, access mechanisms, and initialization process.

### 1.1 Memory System Summary

| Component         | Size          | Type                      | Access                | Features                                      |
|-------------------|---------------|---------------------------|-----------------------|-----------------------------------------------|
| **IMEM**          | 8KB (default) | Instruction Memory        | Read-Only (runtime)   | Dual-port, initialized at boot                |
| **DMEM**          | 4KB (default) | Data Memory               | Read/Write            | Byte-addressable, supports all access sizes   |
| **Memory Init**   | N/A           | Initialization Controller | Boot-time             | Loads firmware, clears DMEM                   |

### 1.2 Memory System Block Diagram
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


## 2. Instruction Memory (IMEM)

### 2.1 IMEM Architecture

**Module:** `imem.v` + `imem_wrapper.v`

#### 2.1.1 Key Features
- **Dual-port memory**: CPU fetch port + system read port
- **Read-only during operation**: Write protection enforced
- **Word-aligned access**: 32-bit instructions only
- **Configurable size**: Parameterized depth (default: 8KB)

#### 2.1.2 Interface Ports

| Port | Direction | Width | Purpose |
|------|-----------|-------|---------|
| **CPU Fetch Port** | Input/Output | Wishbone | Instruction fetch by CPU |
| **System Read Port** | Input/Output | Wishbone | Debug/verification access |
| **Initialization Port** | Input | Direct | Boot-time firmware loading |

#### 2.1.3 Memory Organization

IMEM Physical Layout (8KB default):

``` text
┌─────────────────────────────────────────────┐
│                 IMEM (8KB)                  │
├─────────────────────────────────────────────┤
│ Word Address │ Byte Address │    Content    │
├─────────────────────────────────────────────┤
│ 0x0000_0000  │ 0x0000_0000  │   instr[0]    │
│ 0x0000_0001  │ 0x0000_0004  │   instr[1]    │
│ 0x0000_0002  │ 0x0000_0008  │   instr[2]    │
│     ...      │     ...      │     ...       │
│ 0x0000_07FF  │ 0x0000_1FFC  │  instr[2047]  │
└─────────────────────────────────────────────┘
```

**Note:** CPU accesses via byte address, internal storage uses word address.


### 2.2 IMEM Access Modes

#### 2.2.1 CPU Instruction Fetch
- **Protocol**: Wishbone B4 pipelined
- **Address**: PC value (byte address)
- **Data**: 32-bit instruction
- **Timing**: 2-3 cycles per fetch

#### 2.2.2 System Bus Access
- **Purpose**: Debug, verification, firmware inspection
- **Access**: Read-only during operation
- **Address**: Memory-mapped (0x0000_0000 - 0x0000_1FFF)

#### 2.2.3 Initialization Access
- **Timing**: During system reset (before CPU starts)
- **Method**: Direct write to memory array
- **Source**: `mem_init` module with firmware file

### 2.3 IMEM Protection Mechanisms

#### 2.3.1 Write Protection
```verilog
// In imem.v - Runtime write protection
always @(posedge clk) begin
    if (wbs_if_cyc && wbs_if_stb && wbs_if_we) begin
        $display("[WARNING]: Attempted IMEM IF write at %h", wbs_if_addr);
        // Write is ignored by memory array
    end
end
```

#### 2.3.2 Initialization-Only Writes
```verilog
// Only allow writes during initialization
always @(posedge clk) begin
    if (init_en) begin
        mem[init_word_addr] <= init_data;  // Allow during init
    end
    // No else clause - prevents runtime writes
end
```


## 3. Data Memory (DMEM)

### 3.1 DMEM Architecture

**Module**: `dmem.v` + `dmem_wrapper.v`

#### 3.1.1 Key Features
- **Single-port memory**: CPU read/write access
- **Byte-addressable**: Supports byte, half-word, word accesses
- **Byte enable support**: Individual byte writes
- **Configurable size**: Parameterized depth (default: 4KB)

#### 3.1.2 Memory Organization

DMEM Physical Layout (4KB default):
```text
┌─────────────────────────────────────────────────────┐
│                   DMEM (4KB)                        │
├─────────────────────────────────────────────────────┤
│ Word  │ Bytes        │ CPU Access Examples          │
├───────┼──────────────┼──────────────────────────────┤
│ 0     │ [15:8] [7:0]                                │
│       │   0x3    0x2    0x1    0x0    ← Byte adds   │
├───────┼──────────────┼──────────────────────────────┤
│       │ LB x1, 0(x2)    // Load byte from addr 0    │
│       │ LH x1, 0(x2)    // Load half from addr 0    │
│       │ LW x1, 0(x2)    // Load word from addr 0    │
│       │ SB x1, 1(x2)    // Store byte to addr 1     │
└───────┴──────────────┴───────────────────────────── ┘
```

### 3.2 DMEM Access Types

#### 3.2.1 Load Operations

| Instruction   | funct3    | Size | Alignment  | Sign Extend   | Byte Select                                   |
| :---          | :---      | :--- | :---       | :---          | :---                                          |
| `LB`          | 000       | Byte | Any        | Yes           | addr[1:0] determines byte                     |
| `LH`          | 001       | Half | 2-byte     | Yes           | addr[1]=0: bytes 1,0; addr[1]=1: bytes 3,2    |
| `LW`          | 010       | Word | 4-byte     | No            | All bytes (1111)                              |
| `LBU`         | 100       | Byte | Any        | No            | addr[1:0] determines byte                     |
| `LHU`         | 101       | Half | 2-byte     | No            | Based on addr[1]                              |

#### 3.2.2 Store Operations

| Instruction   | funct3    | Size | Alignment  | Byte Select Pattern       |
| :---          | :---      | :--- | :---       | :---                      |
| `SB`          | 000       | Byte | Any        | `0001 << addr[1:0]`       |
| `SH`          | 001       | Half | 2-byte     | `0011 << {addr[1], 1'b0}` |
| `SW`          | 010       | Word | 4-byte     | `1111`                    |

#### 3.2.3 Byte Select Generation
```verilog
// In mem_stage.v - Byte select generation
always @(*) begin
    case (funct3_latched)
        BYTE, BYTEU:  wbm_dmem_sel = 4'b0001 << mem_addr_latched[1:0];
        HALF, HALFU:  wbm_dmem_sel = 4'b0011 << {mem_addr_latched[1], 1'b0};
        WORD:         wbm_dmem_sel = 4'b1111;
        default:      wbm_dmem_sel = 4'b0000;
    endcase
end
```

### 3.3 DMEM Implementation Details

#### 3.3.1 Write path
```verilog
// In dmem.v - Write with byte select
always @(posedge clk) begin
    if (wbs_cyc && wbs_stb && wbs_we) begin
        // Runtime writes with byte select
        if (wbs_sel[0]) mem[word_addr][7:0]   <= wbs_data_write[7:0];
        if (wbs_sel[1]) mem[word_addr][15:8]  <= wbs_data_write[15:8];
        if (wbs_sel[2]) mem[word_addr][23:16] <= wbs_data_write[23:16];
        if (wbs_sel[3]) mem[word_addr][31:24] <= wbs_data_write[31:24];
    end
end
```


#### 3.3.2 Read path
```verilog
// In dmem.v - Synchronous read
always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        wbs_data_read <= {DATA_WIDTH{1'b0}};
    end else begin
        if (wbs_cyc && wbs_stb && !wbs_we) begin
            wbs_data_read <= mem[word_addr];  // Full word read
        end else begin
            wbs_data_read <= {DATA_WIDTH{1'b0}};
        end
    end
end
```

#### 3.3.3 Read Data Processing
```verilog
// In mem_stage.v - Extract and sign-extend
case (funct3_latched)
    BYTE:  load_data = {{24{byte_data[7]}}, byte_data[7:0]};
    BYTEU: load_data = {24'b0, byte_data[7:0]};
    HALF:  load_data = {{16{half_data[15]}}, half_data[15:0]};
    HALFU: load_data = {16'b0, half_data[15:0]};
    default: load_data = wbm_dmem_data_read;  // WORD
endcase
```

## 4. Memory Initialization system

### 4.1 `mem_init` Module

**Module**: `mem_init.v`

#### 4.1.1 Purpose
- Load firmware into IMEM at system startup
- Clear DMEM to known state (all zeros)
- Provide synchronization for reset sequencing

#### 4.1.2 Initialization FSM
```text
        ┌────────┐
        │  IDLE  │
        └───┬────┘
            │ init_start
            ▼
        ┌────────┐
        │LOAD    │───┐
        │IMEM    │   │ for each IMEM word
        └───┬────┘   │
            │        │
            │done    │
            ▼        │
        ┌────────┐   │
        │LOAD    │◄──┘
        │DMEM    │───┐
        └───┬────┘   │ for each DMEM word
            │        │
            │done    │
            ▼        │
        ┌────────┐   │
        │ DONE   │◄──┘
        └────────┘
```

#### 4.1.3 Firmware File format
- **Format**: Hexadecimal values (32-bit words)
- **Tool**: Generated by RISC-V toolchain (objcopy)
- **Example**: `firmware.mem`

#### 4.1.4 Initialization Process
```verilog
// In mem_init.v
initial begin
    // 1. Fill IMEM with NOPs
    for (integer i = 0; i < IMEM_DEPTH; i = i + 1) begin
        firmware_mem[i] = NOP_INSTRUCTION;  // 32'h00000013
    end
    
    // 2. Load firmware from file
    $readmemh(INIT_FILE, firmware_mem);
    
    // 3. Count actual loaded instructions
    loaded_instructions = 0;
    for (integer i = 0; i < IMEM_DEPTH; i = i + 1) begin
        if (firmware_mem[i] !== 32'hxxxxxxxx) begin
            loaded_instructions = loaded_instructions + 1;
        end else begin
            firmware_mem[i] = NOP_INSTRUCTION;  // Fill uninitialized
        end
    end
end
```

### 4.2 Reset and Initialization Timing

#### 4.2.1 Reset Sequencing
```verilog
// In top_soc.v - Reset distribution
// Level 1: Memory and basic peripherals
assign memory_rst_n = rst_n_sync2;

// Level 2: Complex peripherals (after memory init)
assign peripheral_rst_n = rst_n_sync2 && init_done_sync2;

// Level 3: CPU (after everything is ready)
assign cpu_rst_n = rst_n_sync2 && init_done_sync2;
```

#### 4.2.2 Initialization Trigger
```verilog
// Generate init_start on rising edge of reset
always @(posedge clk or negedge rst_n_sync2) begin
    if (!rst_n_sync2) begin
        rst_n_prev <= 1'b0;
    end else begin
        rst_n_prev <= rst_n_sync2;
    end
end

assign init_start = rst_n_sync2 && !rst_n_prev;
```

#### 4.2.3 Initialization Timing Diagram

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
    "text": "Initializaton Sequence: IMEM then DMEM",
    "tick": 0
  },
  "foot": {
    "text": "CPU remains reset until DMEM initialized"
  }
}
```

## 5. Memory Performance Characteristics

### 5.1 Access Latency

| Memory | Operation        | Minimum Cycles    | Typical Cycles    | Notes                                                 |
| :---   | :---             | :---:             | :---:             | :---                                                  |
| `IMEM` | Read (CPU)       | 2                 | 3                 | Pipeline stages: decode(1) + drive(1) + response(1)   |
| `IMEM` | Read (System)    | 2                 | 3                 | Same as CPU but different port                        |
| `DMEM` | Read             | 3                 | 4                 | EX(addr) + MEM(req) + MEM(resp) + WB                  |
| `DMEM` | Write            | 3                 | 3                 | EX(addr) + MEM(req+data) + WB(ack)                    |

### 5.2 Bandwidth Analysis

#### 5.2.1 Theoretical Maximum
- **Instruction fetch**: 32 bits/cycle (with perfect pipeline)
- **Data access**: 32 bits every 3-4 cycles
- **Combined**: Limited by single memory port contention

#### 5.2.2 Practical Limitations
1. **Structural hazards**: None between IMEM/DMEM (separate)
2. **Load-use stalls**: 1 cycle penalty for dependent operations
3. **Memory busy**: DMEM operations can stall pipeline


### 5.3 Memory Timing Examples

#### 5.3.1 Sequential Instruction Fetch
```text
Cycle  IF Stage        Wishbone Transaction     IMEM Response
-----  --------------  ----------------------  --------------
  0    Request instr0  STB=1, ADDR=PC          -
  1    Wait            (registered)            Process address
  2    Receive instr0  ACK=1, DATA=instr0      Output data
  3    Request instr1  STB=1, ADDR=PC+4        -
  4    Wait                                    Process address
  5    Receive instr1  ACK=1, DATA=instr1      Output data
```

#### 5.3.2 Load Operation
```text
Cycle  Stage    CPU Action          DMEM Action          Wishbone
-----  ------   ----------          -----------          --------
  0    EX       Calculate address   -                    -
  1    MEM      Send load request   Receive request      STB=1, ADDR=addr
  2    MEM      Wait for data       Access memory        (processing)
  3    MEM      Receive data        Return data          ACK=1, DATA=value
  4    WB       Write to register   -                    -
```


## 6. Memory-Mapped I/O Considerations

### 6.1 Peripheral vs Memory Access

| Aspect        | Memory (DMEM)             | Peripheral (UART/Timer/GPIO)  |
| :---          | :---                      | :---                          |
| Access Size   | Byte, half, word          | Typically word-only           |
| Timing        | 1 cycle (after request)   | Variable (UART has baud rate) |
| Side Effects  | None                      | May trigger actions (UART TX) |
| Address Range | `0x1000_0000-0x1000_0FFF` | Various 4KB regions           |

### 6.2 Address Decoding in Interconnect

```verilog
// In wishbone_interconnect.v
always @(*) begin
    if (wbm_cpu_addr >= IMEM_BASE_ADDR && wbm_cpu_addr <= IMEM_END_ADDR) begin
        sel_slave_combo   = SLAVE_IMEM;
        address_valid_combo = 1'b1;
    end 
    else if (wbm_cpu_addr >= DMEM_BASE_ADDR && wbm_cpu_addr <= DMEM_END_ADDR) begin
        sel_slave_combo   = SLAVE_DMEM;
        address_valid_combo = 1'b1;
    end 
    // ... similar for peripherals
end
```

## 7. Error Handling and Protection

### 7.1 Misaligned Access Detection

**Location:** `mem_stage.v`


```verilog
// Alignment checking logic
always @(*) begin
    load_misaligned  = 1'b0;
    store_misaligned = 1'b0;

    if (is_load || is_store) begin
        case (funct3_in)
            WORD:  if (alu_result_in[1:0] != 2'b00) begin
                       load_misaligned  = is_load;
                       store_misaligned = is_store;
                   end
            HALF, HALFU: if (alu_result_in[0] != 1'b0) begin
                       load_misaligned  = is_load;
                       store_misaligned = is_store;
                   end
            // BYTE/BYTEU are always aligned
        endcase
    end
end
```

**Current Behavior**: Flag is set but no exception is raised.

### 7.2 Invalid Address Response

**Location**: `wishbone_interconnect.v`

```verilog
// Invalid address response
if (!address_valid_reg) begin
    // Invalid address - respond immediately in next cycle
    wbm_cpu_ack       <= 1'b1;
    wbm_cpu_data_read <= 32'hDEAD_BEEF;
end
```

### 7.3 IMEM Write Protection
- **Runtime protection**: Attempted writes are ignored with warning
- **Initialization-only**: Writes only allowed during boot


## 8. Configuration and Scalability

### 8.1 Memory Size Configuration

| Parameter      | Default  | Description                   | Valid Range    |
| :---           | :---     | :---                          | :---           |
| `IMEM_SIZE_KB` | 8        | Instruction memory in KB      | Power of 2, ≥1 |
| `DMEM_SIZE_KB` | 4        | Data memory in KB             | Power of 2, ≥1 |
| `DATA_SIZE_KB` | 4        | Peripheral space per device   | Power of 2, ≥1 |

### 8.2 Configuration Example

```verilog
// Custom memory sizes
top_soc #(
    .IMEM_SIZE_KB  = 16,   // 16KB instruction memory
    .DMEM_SIZE_KB  = 8,    // 8KB data memory
    .DATA_SIZE_KB  = 4     // 4KB per peripheral
) my_soc (...);
```

### 8.3 Scalability Considerations

#### 8.3.1 Increasing Memory Size
1. Update parameter in `top_soc.v`
2. Ensure address decoding in interconnect covers new range
3. Update firmware linker script for larger memory

#### 8.3.2 Adding Memory Types
1. **Cache**: Add between CPU and interconnect
2. **External Memory**: Add memory controller peripheral
3. **Flash**: Add boot ROM with different initialization


## 9. Verification and Testing

### 9.1 Memory Test Scenarios

#### 9.1.1 IMEM Tests
```verilog
// Test 1: Sequential read after initialization
for (int i = 0; i < IMEM_DEPTH; i++) begin
    read_address = IMEM_BASE + (i * 4);
    verify_data = expected_firmware[i];
end

// Test 2: Write protection
write_to_imem(IMEM_BASE, 32'h12345678);
verify_no_change();  // Should remain firmware value
```


#### 9.1.2 DMEM Tests
```verilog
// Test 1: Byte access patterns
for (int offset = 0; offset < 4; offset++) begin
    store_byte(DMEM_BASE + offset, 8'hA0 + offset);
    verify_byte(DMEM_BASE + offset, 8'hA0 + offset);
end

// Test 2: Half-word alignment
store_halfword(DMEM_BASE, 16'h1234);      // Should succeed
store_halfword(DMEM_BASE + 2, 16'h5678);  // Should succeed  
store_halfword(DMEM_BASE + 1, 16'h9ABC);  // Should flag misaligned
```

### 9.2 Performance Tests
1. **Throughput test**: Measure instructions per cycle with memory-intensive code
2. **Latency test**: Time load-use chains with varying memory delays
3. **Concurrent access**: CPU fetch while system reads IMEM


## 10. Design Trade-offs and Limitations

### 10.1 Current Limitations
1. **No memory protection**: All addresses accessible in all modes
2. **No cache**: All accesses go directly to memory
3. **Fixed latency**: No variable latency memory support
4. **No DMA**: CPU must handle all data movement

### 10.2 Design Trade-offs
1. **Separate IMEM/DMEM**: Simpler design vs. unified cache
2. **Byte-addressable DMEM**: Flexibility vs. complexity
3. **Synchronous memory**: Simpler timing vs. potential performance
4. **Fixed memory map**: Simplicity vs. flexibility

### 10.3 Future Enhancements
1. **Instruction cache**: Reduce IMEM access frequency
2. **Write buffer**: Allow stores to complete without stalling
3. **Memory protection**: Add basic region protection
4. **DMA controller**: Offload data movement from CPU


---
---

## Appendix A: Memory Address Calculation

```text
For IMEM (8KB = 8192 bytes = 2048 words):
- Byte address range: 0x0000_0000 to 0x0000_1FFF
- Word index = (byte_address - IMEM_BASE) >> 2
- Valid if: (byte_address >= IMEM_BASE) && 
            (byte_address < IMEM_BASE + IMEM_SIZE_BYTES)

Example: Address 0x0000_1004
- Offset = 0x1004 - 0x0000 = 0x1004
- Word index = 0x1004 >> 2 = 0x401 (word 1025)
- Valid: 0x1004 < 0x2000 = true
```

## Appendix B: Memory Initialization Flow

```text
Boot Process:
1. System reset released (memory_rst_n = 1)
2. mem_init module starts (init_start pulse)
3. IMEM loaded from firmware.mem (2048 writes)
4. DMEM cleared to zeros (1024 writes)
5. init_done asserted
6. Peripheral reset released (peripheral_rst_n = 1)
7. CPU reset released (cpu_rst_n = 1)
8. CPU starts executing from PC = 0x0000_0000
```