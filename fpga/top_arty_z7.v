// =============================================================================
// top_arty_z7.v — FPGA Wrapper for MiniSoC_RV32I on Digilent Arty Z7-20
// =============================================================================
//
// This module is the FPGA-specific top-level. It:
//   1. Accepts the 125 MHz board clock (E3 pin) and generates a clean
//      SYS_CLK_FREQ system clock via a Xilinx MMCM primitive.
//   2. Synchronises the active-low reset (BTN0) out of the MMCM lock.
//   3. Instantiates top_soc with the correct BAUD_DIV_RST for 125 MHz.
//   4. Maps physical Arty Z7-20 pins (LEDs, UART, PMOD JA) to the SoC ports.
//
// Clock plan (MMCM, VCO @ 1000 MHz):
//   CLKIN  = 125 MHz  (board oscillator, BUFG input)
//   CLKFBOUT_MULT_F = 8.000  → VCO = 125 × 8 = 1000 MHz
//   CLKOUT0_DIVIDE_F = 8.000 → CLKOUT0 = 125 MHz  (sys_clk)
//
// UART baud divisor @ 125 MHz, 115200 baud:
//   BAUD_DIV_RST = 125_000_000 / 115_200 − 1 = 1084
//
// GPIO mapping (PMOD JA, 8 pins):
//   gpio[0..3] → JA[1..4]   (JA top row:  V12 W12 V10 W10)
//   gpio[4..7] → JA[7..10]  (JA bot row:  W11 Y11  Y12 AA11)
//
// =============================================================================
 
`default_nettype none

module top_arty_z7 (
    // Board clock (125 Mhz)
    input   wire    CLK125_P,
    input   wire    CLK125_N,

    // Reset: active-high push-button
    input   wire    BTN0,

    // UART 
    input   wire    UART_RX_IN,
    output  wire    UART_TX_OUT,

    // Status LEDs (active HIGH)
    output  wire    LED0_R,
    output  wire    LED0_G,
    output  wire    LED0_B,
    output  wire    LED1,
    output  wire    LED2,
    output  wire    LED3,

    // GPIO -> PMOD JA
    inout   wire    JA1,
    inout   wire    JA2,
    inout   wire    JA3,
    inout   wire    JA4,
    inout   wire    JA7,
    inout   wire    JA8,
    inout   wire    JA9,
    inout   wire    JA10
);

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam SYS_CLK_FREQ     = 125_000_000;
    localparam BAUD_RATE        = 115_200;
    localparam BAUD_DIV_FPGA    = SYS_CLK_FREQ / BAUD_RATE - 1;


    // =========================================================================
    // Clock generation — MMCM
    // =========================================================================
    wire clk_in_buf;        // After IBUFDS
    wire clk_fb;            // MMCM feedback
    wire clk_fb_buf;        // Buffered feedback
    wire clkout0_raw;       // MMCM output, before BUFG
    wire sys_clk;           // System clock, after BUFG
    wire mmcm_locked;       // MMCM lock signal
 
    // Differential input buffer (125 MHz board clock)
    IBUFDS #(
        .DIFF_TERM    ("FALSE"),
        .IBUF_LOW_PWR ("TRUE"),
        .IOSTANDARD   ("LVDS_25")
    ) clk_ibufds (
        .I  (CLK125_P),
        .IB (CLK125_N),
        .O  (clk_in_buf)
    );
 
    // MMCM — generate 125 MHz system clock
    // VCO = 125 × 8 = 1000 MHz (within 600–1200 MHz for Zynq-7020 speed grade −1)
    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (8.000),       // × 8 → VCO = 1000 MHz
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (8.000),       // 125 MHz → period = 8 ns
        .CLKOUT0_DIVIDE_F   (8.000),       // ÷ 8 → 125 MHz
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    ) mmcm_inst (
        .CLKIN1   (clk_in_buf),
        .CLKFBIN  (clk_fb_buf),
        .CLKOUT0  (clkout0_raw),
        .CLKFBOUT (clk_fb),
        .LOCKED   (mmcm_locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );
 
    // Feedback buffer
    BUFG clk_fb_bufg (
        .I (clk_fb),
        .O (clk_fb_buf)
    );
 
    // Output global buffer
    BUFG sys_clk_bufg (
        .I (clkout0_raw),
        .O (sys_clk)
    );
 
    // =========================================================================
    // Reset synchronisation
    // =========================================================================
    // External reset source: BTN0 (active high) AND MMCM lock
    // We synchronise into sys_clk domain with a 4-stage pipeline.
    // The SoC already has its own 2-stage synchroniser in top_soc,
    // so 2 extra stages here are sufficient — we use 4 for safety.
 
    wire   ext_rst_n = ~BTN0 & mmcm_locked;
    reg [3:0] rst_pipe;
 
    always @(posedge sys_clk or negedge ext_rst_n) begin
        if (!ext_rst_n)
            rst_pipe <= 4'b0000;
        else
            rst_pipe <= {rst_pipe[2:0], 1'b1};
    end
 
    wire sys_rst_n = rst_pipe[3];   // Active-low, synchronised to sys_clk
 
    // =========================================================================
    // SoC instantiation
    // =========================================================================
    top_soc #(
        .FIRMWARE_FILE  ("firmware.mem"),
        .ADDR_WIDTH     (32),
        .DATA_WIDTH     (32),
        .IMEM_SIZE_KB   (8),
        .DMEM_SIZE_KB   (4),
        .DATA_SIZE_KB   (4),
        .BAUD_DIV_RST   (BAUD_DIV_FPGA),   // 1084 @ 125 MHz / 115200
        .N_GPIO         (8)
    ) soc_inst (
        .clk        (sys_clk    ),
        .rst_n      (sys_rst_n  ),
        .uart_rx    (UART_RX_IN ),
        .uart_tx    (UART_TX_OUT),
        .gpio0_io   (JA1        ),
        .gpio1_io   (JA2        ),
        .gpio2_io   (JA3        ),
        .gpio3_io   (JA4        ),
        .gpio4_io   (JA7        ),
        .gpio5_io   (JA8        ),
        .gpio6_io   (JA9        ),
        .gpio7_io   (JA10       )
    );
 
    // =========================================================================
    // LED diagnostics (visible feedback without a terminal)
    // =========================================================================
    // LED0 RGB: locked=green, reset=red, both=blue
    assign LED0_R = ~sys_rst_n;             // Red while in reset
    assign LED0_G = mmcm_locked;            // Green when MMCM is locked
    assign LED0_B = mmcm_locked & sys_rst_n; // Blue = fully operational
 
    // LD1/LD2/LD3: driven by gpio[5..7] (output-only view for debugging)
    // These shadow the GPIO output signals; direction is controlled by the SoC.
    // They are open-drain-safe: only turn on when gpio_oe drives OUT.
    assign LED1 = 1'b0;   // Available for user firmware via gpio[5] on JA8
    assign LED2 = 1'b0;   // Available for user firmware via gpio[6] on JA9
    assign LED3 = 1'b0;   // Available for user firmware via gpio[7] on JA10
    // Tip: connect these to gpio_out signals if you want LED visibility.
    //      Requires minor modification in top_soc to expose gpio_out/oe.
endmodule


`default_nettype wire