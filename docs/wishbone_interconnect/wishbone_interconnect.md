# 1. Define Address Map (Wishbone-Slave Mapping)

We'll use **4 KB memory regions** for each device, making address decoding clean and simple.

|Address Range                     |Slave          |Base Address   |Notes                 |
|----------------------------------|---------------|---------------|----------------------|
| `0x0000_0000` -- `0x0000_0FFF`   | **IMEM**      | `0x0000_0000` | Instruction fetch    |
| `0x1000_0000` -- `0x1000_0FFF`   | **DMEM**      | `0x1000_0000` | Data read/write      |
| `0x2000_0000` -- `0x2000_0FFF`   | **UART**      | `0x2000_0000` | UART registers       |
| `0x3000_0000` -- `0x3000_0FFF`   | **TIMER**     | `0x3000_0000` | Timer registers      |
| `0x4000_0000` -- `0x4000_0FFF`   | **GPIO**      | `0x4000_0000` | GPIO registers       |

This gives us **5 Wishbone slaves** and **1 Wishbone master** (the CPU core).

---

# 2. Wishbone Master Interface in CPU

The CPU acts as a **Wishbone B4 classic master**. Here's the **minimal Wishbone master signal set:**

## Interface Signals


| Signals       | Direction       | Description                     |
|---------------|-----------------|---------------------------------|
| `wb_clk_i`    | **input**       | Clock                           |
| `wb_rst_i`    | **input**       | Reset                           |
| `wb_cyc_o`    | **output**      | Bus cycle active                |
| `wb_stb_o`    | **output**      | Strobe signal (valid request)   |
| `wb_we_o`     | **output**      | Write enable                    |
| `wb_addr_o`   | **output**      | Address Bus                     |
| `wb_data_o`   | **output**      | Write data bus                  |
| `wb_sel_o`    | **output**      | Byte select                     |
| `wb_data_i`   | **input**       | Read data bus                   |
| `wb_ack_i`    | **input**       | Acknowledge from slave          |


## Minimal Verilog Template in CPU Core

```verilog
// Wishbone Master Output
output reg          wb_cyc_o,
output reg          wb_stb_o,
output reg          wb_we_o,
output reg [31:0]   wb_addr_o,
output reg [31:0]   wb_data_o,
output reg [3:0]    wb_sel_o,

// Wishbone Master Input
input wire [31:0]   wb_data_i,
input wire          wb_ack_i
```

## Example Bus Read FSM Logic

```verilog
always @(posedge clk) begin
    if (!rst_n) begin
        wb_cyc_o    <= 0;
        wb_stb_o    <= 0;
        wb_we_o     <= 0;
    end else begin
        case (state)
            STATE_IDLE: begin
                if (do_read) begin
                    wb_cyc_o    <= 1;
                    wb_stb_o    <= 1;
                    wb_we_o     <= 0;
                    wb_addr_o   <= read_addr;
                    state       <= STATE_WAIT;
                end
            end
            STATE_WAIT: begin
                if (wb_ack_i) begin
                    read_data   <= wb_data_i;
                    wb_cyc_o    <= 1;
                    wb_stb_o    <= 1;
                    state       <= STATE_DONE;
                end
            end
        endcase
    end
end
```

---

# 3. Wishbone Slave Interface

Each peripheral gets:

```verilog
// Wishbone Slave Input
input wire          wb_cyc_i,
input wire          wb_stb_i,
input wire          wb_we_i,
input wire [31:0]   wb_addr_i,
input wire [31:0]   wb_data_i,
input wire [3:0]    wb_sel_i,

// Wishbone Slave Output
output reg [31:0]   wb_data_o,
output reg          wb_ack_o
```

---

# 4. Wishbone Interconnect: Decoder + Mux Logic

We need to:
-   Decode `wb_addr_o` to generate a chip-select for each slave
-   Route CPU master signals to the selected slave
-   Mux the data and `ack` signals from slave back to CPU

## 4.1 Address Decoder (Verilog)

```verilog
// Input: wb_addr_o from CPU
// Output: one-hot slave select

always @(*) begin
    slave_imem    = 0;
    slave_dmem    = 0;
    slave_uart    = 0;
    slave_timer   = 0;
    slave_gpio    = 0;

    case (wb_addr_o[31:12]) // 0xAAAA_Axxx; A:range address
        20'h00000:  slave_imem    = 1; // 0x0000_0000
        20'h10000:  slave_dmem    = 1; // 0x1000_0000
        20'h20000:  slave_uart    = 1; // 0x2000_0000
        20'h30000:  slave_timer   = 1; // 0x3000_0000
        20'h40000:  slave_gpio    = 1; // 0x4000_0000
        default: ;                     // None selected
    endcase
end
```

## 4.2 Signal Muxing Logic

CPU &rarr; Slave (write signals go to selected slave)

```verilog
assign imem_cyc_i  = slave_imem ? wb_cyc_o : 0;
assign imem_stb_i  = slave_imem ? wb_stb_o : 0;
assign imem_we_i   = slave_imem ? wb_we_o  : 0;
assign imem_addr_i = wb_addr_o;
assign imem_data_i = wb_data_o;
assign imem_sel_i  = wb_sel_o;

// Repeat similarly for dmem, uart, timer, gpio
```

Slave &rarr; CPU (only one selected at a time)

```verilog
assign wb_ack_i =   (slave_imem  && imem_ack_o)  ||
                    (slave_dmem  && dmem_ack_o)  ||
                    (slave_uart  && uart_ack_o)  ||
                    (slave_timer && timer_ack_o) ||
                    (slave_gpio  && gpio_ack_o);

assign wb_data_i =  (slave_imem  ? imem_data_o    :
                     slave_dmem  ? dmem_data_o    :
                     slave_uart  ? uart_data_o    :
                     slave_timer ? timer_data_o   :
                     slave_gpio  ? gpio_data_o    :
                     32'hDEADDEAD); // Default

```

