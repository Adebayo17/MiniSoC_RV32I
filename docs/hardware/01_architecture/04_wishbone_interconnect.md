# Wishbone Interconnect Architecture

## 1. Overview

The Wishbone B4 interconnect provides the communication backbone for the MiniSoC-RV32I system, connecting a single CPU master to multiple memory and peripheral slaves. This document details the pipelined architecture, timing, and operation of the interconnect fabric.

### 1.1 Interconnect Summary

| Feature               | Specification                         |
|-----------------------|---------------------------------------|
| **Protocol**          | Wishbone B4 Pipelined                 |
| **Topology**          | Single Master to Multiple Slaves      |
| **Pipeline Stages**   | 3-stage (Decode, Drive, Response)     |
| **Data Width**        | 32-bit                                |
| **Address Width**     | 32-bit                                |
| **Slaves Supported**  | 5 (IMEM, DMEM, UART, TIMER, GPIO)     |
| **Latency**           | 2-3 cycles per transaction            |
| **Throughput**        | 1 transaction per cycle (pipelined)   |

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


## 2. Wishbone B4 Protocol Implementation

### 2.1 Protocol Overview

Wishbone B4 Pipelined protocol key characteristics:
- **Pipelined transfers**: New requests can start before previous completes
- **Single master**: Simplified arbitration (none needed)
- **Registered feedback**: ACK and data registered for timing

### 2.2 Signal Definitions

#### 2.2.1 Master Interface (CPU → Interconnect)

| Signal                | Width | Direction | Description   | Timing                            |
|-----------------------|-------|-----------|---------------|-----------------------------------|
| `wbm_cpu_cyc`         | 1     | Input     | Cycle valid   | Asserted for duration of transfer |
| `wbm_cpu_stb`         | 1     | Input     | Strobe        | Asserted for each beat            |
| `wbm_cpu_we`          | 1     | Input     | Write enable  | 1=Write, 0=Read                   |
| `wbm_cpu_addr`        | 32    | Input     | Address bus   | Valid when STB=1                  |
| `wbm_cpu_data_write`  | 32    | Input     | Write data    | Valid when STB=1 and WE=1         |
| `wbm_cpu_sel`         | 4     | Input     | Byte select   | Which bytes are valid             |
| `wbm_cpu_data_read`   | 32    | Output    | Read data     | Valid when ACK=1                  |
| `wbm_cpu_ack`         | 1     | Output    | Acknowledge   | Indicates transfer complete       |


#### 2.2.2 Slave Interfaces (Interconnect → Peripherals)


| Signal Pattern        | Example               | Width | Direction | Description               |
|-----------------------|-----------------------|-------|-----------|---------------------------|
| `wbs_*_cyc`           | `wbs_imem_cyc`        | 1     | Output    | Slave cycle select        |
| `wbs_*_stb`           | `wbs_imem_stb`        | 1     | Output    | Slave strobe              |
| `wbs_*_we`            | `wbs_imem_we`         | 1     | Output    | Write enable to slave     |
| `wbs_*_addr`          | `wbs_imem_addr`       | 32    | Output    | Address to slave          |
| `wbs_*_data_write`    | `wbs_imem_data_write` | 32    | Output    | Write data to slave       |
| `wbs_*_sel`           | `wbs_imem_sel`        | 4     | Output    | Byte select to slave      |
| `wbs_*_data_read`     | `wbs_imem_data_read`  | 32    | Input     | Read data from slave      |
| `wbs_*_ack`           | `wbs_imem_ack`        | 1     | Input     | Acknowledge from slave    |

**Where `*`** is one of: `imem`, `dmem`, `uart`, `timer`, `gpio`

### 2.3 Protocol Timing

#### 2.3.1 Basic Read Timing (Pipelined)

```wavedrom
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
  "foot": { "text": "a: Recording, b: Slave Access, c: Return multiplexing" }
}
```

#### 2.3.2 Basic Write Timing (Pipelined)

```wavedrom
{ "signal": [
  { "name": "clk",           "wave": "p..........." },
  { "name": "cyc_m / stb_m", "wave": "010........." },
  { "name": "we_m",          "wave": "010........." },
  { "name": "addr_m",        "wave": "x=x.........", "data": ["A0"] },
  { "name": "data_m",        "wave": "x=x.........", "data": ["D0"] },
  { "name": "stb_r",         "wave": "0.10........" },
  { "name": "we_s (Slave)",  "wave": "0.10........" },
  { "name": "addr_s (Slave)","wave": "x.=x........", "data": ["A0"] },
  { "name": "data_s (Slave)","wave": "x.=x........", "data": ["D0"] },
  { "name": "ack_m",         "wave": "0...10......" }
],
  "head": { "text": "Pipelined Writing: Data Alignment and Ack" }
}
```

## 3. Three-Stage Pipeline Architecture

### 3.1 Pipeline Block Diagram

![Wishbone Pipeline Architectue](../diagrams/wishbone_pipeline.png)


### 3.2 Stage 1: Combinational Address Decode

#### 3.2.1 Address Decode Logic
```verilog
// In wishbone_interconnect.v
always @(*) begin
    // Defaults
    sel_slave_combo = SLAVE_NONE;
    address_valid_combo = 1'b0;

    // Range-based address decoding
    if (wbm_cpu_addr >= IMEM_BASE_ADDR && wbm_cpu_addr <= IMEM_END_ADDR) begin
        sel_slave_combo   = SLAVE_IMEM;
        address_valid_combo = 1'b1;
    end 
    else if (wbm_cpu_addr >= DMEM_BASE_ADDR && wbm_cpu_addr <= DMEM_END_ADDR) begin
        sel_slave_combo   = SLAVE_DMEM;
        address_valid_combo = 1'b1;
    end 
    // ... similar for UART, TIMER, GPIO
    else begin
        sel_slave_combo = SLAVE_NONE;
        address_valid_combo = 1'b0;
    end
end
```

#### 3.2.2 Memory Map Constants

```verilog
// Memory map definitions (matching top_soc.v)
localparam [31:0] IMEM_BASE_ADDR  = 32'h0000_0000;
localparam [31:0] DMEM_BASE_ADDR  = 32'h1000_0000;
localparam [31:0] UART_BASE_ADDR  = 32'h2000_0000;
localparam [31:0] TIMER_BASE_ADDR = 32'h3000_0000;
localparam [31:0] GPIO_BASE_ADDR  = 32'h4000_0000;

// Calculate end addresses based on configurable sizes
localparam [31:0] IMEM_SIZE_BYTES   = IMEM_SIZE_KB * 1024;
localparam [31:0] DMEM_SIZE_BYTES   = DMEM_SIZE_KB * 1024;
localparam [31:0] PERIPH_SIZE_BYTES = PERIPH_SIZE_KB * 1024;

localparam [31:0] IMEM_END_ADDR     = IMEM_BASE_ADDR  + IMEM_SIZE_BYTES - 1;
localparam [31:0] DMEM_END_ADDR     = DMEM_BASE_ADDR  + DMEM_SIZE_BYTES - 1;
localparam [31:0] UART_END_ADDR     = UART_BASE_ADDR  + PERIPH_SIZE_BYTES - 1;
// ... similar for TIMER and GPIO
```

### 3.3 Stage 2: Registered Slave Drive

#### 3.3.1 Pipeline Registers

```verilog
// Pipeline registers (clocked)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sel_slave_reg      <= SLAVE_NONE;
        address_valid_reg  <= 1'b0;
        request_active_reg <= 1'b0;
        
        // Register all master inputs
        wbm_cpu_cyc_reg        <= 1'b0;
        wbm_cpu_stb_reg        <= 1'b0;
        wbm_cpu_we_reg         <= 1'b0;
        wbm_cpu_addr_reg       <= {ADDR_WIDTH{1'b0}};
        wbm_cpu_data_write_reg <= {DATA_WIDTH{1'b0}};
        wbm_cpu_sel_reg        <= 4'b0;
    end else begin
        sel_slave_reg      <= sel_slave_combo;
        address_valid_reg  <= address_valid_combo;
        request_active_reg <= wbm_cpu_cyc && wbm_cpu_stb;
        
        // Register master inputs
        wbm_cpu_cyc_reg        <= wbm_cpu_cyc;
        wbm_cpu_stb_reg        <= wbm_cpu_stb;
        wbm_cpu_we_reg         <= wbm_cpu_we;
        wbm_cpu_addr_reg       <= wbm_cpu_addr;
        wbm_cpu_data_write_reg <= wbm_cpu_data_write;
        wbm_cpu_sel_reg        <= wbm_cpu_sel;
    end
end
```


#### 3.3.2 Slave Drive Logic

```verilog
// Drive selected slave (combinational from registered values)
always @(*) begin
    // Default all slave outputs to inactive
    wbs_imem_cyc        = 1'b0;
    wbs_imem_stb        = 1'b0;
    wbs_imem_we         = 1'b0;
    wbs_imem_addr       = {ADDR_WIDTH{1'b0}};
    wbs_imem_data_write = {DATA_WIDTH{1'b0}};
    wbs_imem_sel        = 4'b0;
    
    // ... default all other slaves similarly

    // If request is active and address is valid, drive the selected slave
    if (request_active_reg && address_valid_reg) begin
        case (sel_slave_reg)
            SLAVE_IMEM: begin
                wbs_imem_cyc        = 1'b1;
                wbs_imem_stb        = 1'b1;
                wbs_imem_we         = 1'b0; // IMEM is read-only
                wbs_imem_addr       = wbm_cpu_addr_reg;
                wbs_imem_data_write = wbm_cpu_data_write_reg;
                wbs_imem_sel        = wbm_cpu_sel_reg;
            end
            SLAVE_DMEM: begin
                wbs_dmem_cyc        = 1'b1;
                wbs_dmem_stb        = 1'b1;
                wbs_dmem_we         = wbm_cpu_we_reg;
                wbs_dmem_addr       = wbm_cpu_addr_reg;
                wbs_dmem_data_write = wbm_cpu_data_write_reg;
                wbs_dmem_sel        = wbm_cpu_sel_reg;
            end
            // ... similar for other slaves
        endcase
    end
end
```

### 3.4 Stage 3: Registered Response Multiplexing

#### 3.4.1 Response Logic

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wbm_cpu_ack       <= 1'b0;
        wbm_cpu_data_read <= {DATA_WIDTH{1'b0}};
    end else begin
        // Default
        wbm_cpu_ack       <= 1'b0;
        wbm_cpu_data_read <= {DATA_WIDTH{1'b0}};
        
        // Check if we had an active request in the previous cycle
        if (request_active_reg) begin
            if (address_valid_reg) begin
                // Valid address - wait for slave ACK
                case (sel_slave_reg)
                    SLAVE_IMEM: begin
                        wbm_cpu_ack       <= wbs_imem_ack;
                        wbm_cpu_data_read <= wbs_imem_data_read;
                    end
                    SLAVE_DMEM: begin
                        wbm_cpu_ack       <= wbs_dmem_ack;
                        wbm_cpu_data_read <= wbs_dmem_data_read;
                    end
                    // ... similar for other slaves
                    default: begin
                        // Should not happen if address_valid_reg is true
                        wbm_cpu_ack       <= 1'b1;
                        wbm_cpu_data_read <= 32'hBADADD01;
                    end
                endcase
            end else begin
                // Invalid address - respond immediately in next cycle
                wbm_cpu_ack       <= 1'b1;
                wbm_cpu_data_read <= 32'hDEAD_BEEF;
            end
        end
    end
end
```

## 4. Timing and Performance

### 4.1 Transaction Latency Analysis

#### 4.1.1 Minimum Latency Transaction

```text
Clock Cycle   Stage           Action
-----------   -----           ------
    0         CPU             Assert CYC, STB, ADDR
    1         Interconnect    Stage 1: Decode address (combinational)
                            Stage 2: Register decode result
    2         Interconnect    Stage 2: Drive slave (combinational)
                            Slave: Process request
    3         Interconnect    Stage 3: Receive ACK and data (registered)
                            CPU: Receive ACK and data
```
**Total**: 3 cycles from request to response

#### 4.1.2 Pipeline Throughput

```text
Clock   Transaction 1        Transaction 2        Transaction 3
-----   -------------        -------------        -------------
  0     CPU: Req A0          -                    -
  1     Int: Decode A0       -                    -
  2     Int: Drive Slave     CPU: Req A1          -
  3     Int: Resp D0         Int: Decode A1       -
  4     CPU: Get D0          Int: Drive Slave     CPU: Req A2
  5     -                    Int: Resp D1         Int: Decode A2
  6     -                    CPU: Get D1          Int: Drive Slave
  7     -                    -                    Int: Resp D2
  8     -                    -                    CPU: Get D2
```
**Throughput**: 1 transaction every 2 cycles after initial latency


### 4.2 Timing Diagrams

#### 4.2.1 Back-to-Back Read Operations

```wavedrom
{ "signal": [
  { "name": "clk",         "wave": "p.........." },
  { "name": "cyc_m",       "wave": "01........0" },
  { "name": "stb_m",       "wave": "0111110...." },
  { "name": "addr_m",      "wave": "x= ===x....", "data": ["A0", "A1", "A2", "A3", "A4"] },
  { "name": "stb_r",       "wave": "0.111110..." },
  { "name": "ack_s (slv)", "wave": "0..111110.." },
  { "name": "ack_m",       "wave": "0...111110." },
  { "name": "data_m",      "wave": "x...=====x.", "data": ["D0", "D1", "D2", "D3", "D4"] }
],
  "head": { "text": "Back-to-Back Read (2-Cycle Pipeline Latency)" },
  "foot": { "text": "Note the 2-cycle shift between stb_m and ack_m due to Stage 1 and Stage 3 registers" }
}
```

#### 4.2.2 Mixed Read/Write Operations

```wavedrom
{ "signal": [
  { "name": "clk",         "wave": "p.........." },
  { "name": "stb_m",       "wave": "0111110...." },
  { "name": "we_m",        "wave": "0010100...." },
  { "name": "addr_m",      "wave": "x====x.....", "data": ["R0", "W0", "R1", "W1", "R2"] },
  { "name": "data_wr_m",   "wave": "x.=.=.x....", "data": ["Dw0", "Dw1"] },
  { "name": "stb_r",       "wave": "0.111110..." },
  { "name": "we_s (slv)",  "wave": "0.010100..." },
  { "name": "ack_m",       "wave": "0...111110." },
  { "name": "data_rd_m",   "wave": "x...=.=.=x.", "data": ["Dr0", "Dr1", "Dr2"] }
],
  "head": { "text": "True Mixed Read/Write (Sequential)" },
  "foot": { "text": "R=Read, W=Write. Data_rd is only valid when ack_m is high and we_m was low." }
}
```


## 5. Memory Map and Address Decoding

### 5.1 Default Memory Map

| Slave         | Base Address  | Default Size  | Address Range                    | Access Mode    |
|---------------|---------------|---------------|----------------------------------|----------------|
| **IMEM**      | `0x0000_0000` | 8 KB          | `0x0000_0000` -- `0x0000_1FFF`   | Read-only      |
| **DMEM**      | `0x1000_0000` | 4 KB          | `0x1000_0000` -- `0x1000_0FFF`   | Read/Write     |
| **UART**      | `0x2000_0000` | 4 KB          | `0x2000_0000` -- `0x2000_0FFF`   | Read/Write     |
| **TIMER**     | `0x3000_0000` | 4 KB          | `0x3000_0000` -- `0x3000_0FFF`   | Read/Write     |
| **GPIO**      | `0x4000_0000` | 4 KB          | `0x4000_0000` -- `0x4000_0FFF`   | Read/Write     |


### 5.2 Configurable Memory Sizes

The interconnect supports configurable memory sizes via parameters:
```verilog
module wishbone_interconnect #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter IMEM_SIZE_KB      = 8,    // Configurable: 8KB default
    parameter DMEM_SIZE_KB      = 4,    // Configurable: 4KB default
    parameter PERIPH_SIZE_KB    = 4     // Configurable: 4KB per peripheral
) (...);
```

### 5.3 Address Decoding Example

For address `0x2000_0100` (UART register):
```text
Address: 0x2000_0100
Base:    0x2000_0000 (UART_BASE_ADDR)
Offset:  0x0000_0100 (256 bytes)
Check:   0x2000_0100 >= 0x2000_0000 = TRUE
         0x2000_0100 <= 0x2000_0FFF = TRUE (for 4KB region)
Result:  Slave select = SLAVE_UART, Address valid = 1
```

## 6. Error Handling and Special Cases

### 6.1 Invalid Address Response

```verilog
// Invalid address detection and response
if (!address_valid_reg) begin
    // Invalid address - respond immediately in next cycle
    wbm_cpu_ack       <= 1'b1;
    wbm_cpu_data_read <= 32'hDEAD_BEEF;
end
```

**Behavior**:
- **ACK**: Asserted 1 cycle after invalid address detected
- **Data**: Returns `0xDEAD_BEEF` (easily identifiable in debug)
- **Condition**: Address outside all defined memory regions

### 6.2 IMEM Write Protection

```verilog
// IMEM is forced read-only regardless of CPU request
SLAVE_IMEM: begin
    wbs_imem_cyc        = 1'b1;
    wbs_imem_stb        = 1'b1;
    wbs_imem_we         = 1'b0; // FORCED to 0 - READ ONLY
    // ... other signals passed through
end
```

**Rationale**: Prevents accidental corruption of instruction memory during operation.

### 6.3 Unselected Slave Case

```verilog
default: begin
    // Should not happen if address_valid_reg is true
    wbm_cpu_ack       <= 1'b1;
    wbm_cpu_data_read <= 32'hBADADD01;
end
```

**Condition**: Internal error - address marked valid but no slave selected.


## 7. Debug and Monitoring Features

### 7.1 Simulation-Only Debug Logic
```verilog
// synthesis translate_off
reg [31:0] access_count;
reg [31:0] error_count;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        access_count <= 0;
        error_count <= 0;
    end else if (wbm_cpu_ack) begin
        access_count <= access_count + 1;
        if (!address_valid_reg) begin
            error_count <= error_count + 1;
            $display("[INTERCONNECT] Error: Invalid address %h at time %t", 
                     wbm_cpu_addr_reg, $time);
        end
    end
end
// synthesis translate_on
``` 

### 7.2 Combinatorial Loop Detection

```verilog
// Monitor for combinatorial loops
reg wbm_cpu_stb_prev;
reg wbm_cpu_ack_prev;
integer loop_counter;

always @(posedge clk) begin
    // Check for immediate ACK (possible combinatorial loop)
    if (wbm_cpu_stb && wbm_cpu_ack) begin
        loop_counter <= loop_counter + 1;
        if (loop_counter > 10) begin
            $display("[INTERCONNECT] WARNING: Possible combinatorial loop detected!");
            $display("  STB and ACK are asserted simultaneously %d times", loop_counter);
        end
    end else begin
        loop_counter <= 0;
    end
    wbm_cpu_stb_prev <= wbm_cpu_stb;
    wbm_cpu_ack_prev <= wbm_cpu_ack;
end
```


## 8. Design Consideration and Trade-offs

### 8.1 Pipeline Depth Trade-off

| Pipeline Depth        | Pros                          | Cons                                      |
|-----------------------|-------------------------------|-------------------------------------------|
| **1-stage**           | Minimal Latency               | Lower frequency, combinational path long  |
| **2-stage**           | Balanced latency/throughput   | More complex than 1-stage                 |
| **3-stage** (current) | High frequency, clean timing  | Extra latency (3 cycles)                  |
| **4-stage**           | High frequency, clean timing  | Excessive latency for small system        |

**Current choice (3-stage)**: Optimal for educational system with clean timing.

### 8.2 Arbitration Strategy

**Current**: No arbitration (single master)

**Future expansion options**:
1. Fixed priority: Simple, deterministic
2. Round-robin: Fair allocation
3. Time-division multiplexing: Guaranteed bandwidth


### 8.3 Byte Select (SEL) Handling

**Important Note**: The interconnect passes SEL signals unmodified, but slaves interpret them differently:

| Slave Type        | SEL Interpretation on Read    | SEL Interpretation on Write   |
|-------------------|-------------------------------|-------------------------------|
| **IMEM**          | Ignored (returns full word)   | Ignored (write-protected)     |
| **DMEM**          | Ignored (returns full word)   | Respected (byte-level write)  |
| **Peripheral**    | Typically ignored             | Typically respected           |


**Reason**: CPU's `mem_stage` handles byte extraction, simplifying slave implementations.


## 9. Verification and Testing

### 9.1 Test Scenarios

#### 9.1.1 Basic Functionality Tests

```verilog
// Test 1: Access each slave
test_access(IMEM_BASE_ADDR, READ);      // Should succeed
test_access(DMEM_BASE_ADDR, WRITE);     // Should succeed
test_access(UART_BASE_ADDR, READ);      // Should succeed
test_access(TIMER_BASE_ADDR, WRITE);    // Should succeed
test_access(GPIO_BASE_ADDR, READ);      // Should succeed

// Test 2: Invalid address
test_access(0x5000_0000, READ);         // Should return 0xDEAD_BEEF with ACK
```

#### 9.1.2 Timing Tests

```verilog
// Test 3: Pipelined back-to-back accesses
for (int i = 0; i < 10; i++) begin
    start_transaction(DMEM_BASE_ADDR + i*4, READ);
    // Don't wait for ACK before starting next
end
verify_all_responses_received();

// Test 4: Mixed read/write pattern
start_read(IMEM_BASE_ADDR);
start_write(DMEM_BASE_ADDR, 32'h12345678);
start_read(UART_BASE_ADDR);
verify_proper_sequencing();
```

#### 9.1.3 Corner Case Tests

```verilog
// Test 5: Address boundary conditions
test_access(IMEM_END_ADDR - 3, READ);   // Last word in IMEM
test_access(IMEM_END_ADDR + 1, READ);   // First invalid after IMEM
test_access(DMEM_BASE_ADDR - 4, READ);  // Last invalid before DMEM

// Test 6: IMEM write protection
attempt_imem_write(IMEM_BASE_ADDR, 32'hFFFFFFFF);
verify_imem_unchanged();  // Should remain original firmware
```

