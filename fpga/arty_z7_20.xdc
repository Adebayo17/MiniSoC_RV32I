## =============================================================================
## arty_z7_20.xdc — Vivado Constraints for MiniSoC_RV32I on Arty Z7-20
## =============================================================================
## Reference: Digilent Arty Z7-20 Master XDC (Rev. J)
## https://github.com/Digilent/digilent-xdc/blob/master/Arty-Z7-20-Master.xdc
## =============================================================================

## -----------------------------------------------------------------------------
## Clock — 125 MHz differential oscillator (PL clock)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVDS_25 } [get_ports CLK125_P]
set_property -dict { PACKAGE_PIN F3  IOSTANDARD LVDS_25 } [get_ports CLK125_N]

## Tell Vivado this is a 125 MHz clock (period = 8 ns)
create_clock -period 8.000 -name sys_clk_pin -waveform {0.000 4.000} [get_ports CLK125_P]

## The MMCM output clock (sys_clk) is auto-derived — Vivado will propagate
## timing constraints through the MMCM automatically.

## -----------------------------------------------------------------------------
## Reset — BTN0 (active LOW)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports BTN0_N]

## Declare as async input; the design has a synchroniser
set_false_path -from [get_ports BTN0_N]

## -----------------------------------------------------------------------------
## UART — USB-UART bridge (Silicon Labs CP2102)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN F5  IOSTANDARD LVCMOS33 } [get_ports UART_RX_IN]
set_property -dict { PACKAGE_PIN E5  IOSTANDARD LVCMOS33 } [get_ports UART_TX_OUT]

## Relax timing on UART paths (slow compared to system clock)
set_false_path -to   [get_ports UART_TX_OUT]
set_false_path -from [get_ports UART_RX_IN]

## -----------------------------------------------------------------------------
## RGB LED — LD0 (active HIGH)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN F6  IOSTANDARD LVCMOS33 } [get_ports LED0_R]
set_property -dict { PACKAGE_PIN E6  IOSTANDARD LVCMOS33 } [get_ports LED0_G]
set_property -dict { PACKAGE_PIN E7  IOSTANDARD LVCMOS33 } [get_ports LED0_B]

## Plain LEDs LD1–LD3 (active HIGH)
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports LED1]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports LED2]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports LED3]

## Drive strength / slew for LEDs (reduce EMI)
set_property DRIVE  4    [get_ports LED0_R]
set_property SLEW   SLOW [get_ports LED0_R]
set_property DRIVE  4    [get_ports LED0_G]
set_property SLEW   SLOW [get_ports LED0_G]
set_property DRIVE  4    [get_ports LED0_B]
set_property SLEW   SLOW [get_ports LED0_B]
set_property DRIVE  4    [get_ports LED1]
set_property SLEW   SLOW [get_ports LED1]
set_property DRIVE  4    [get_ports LED2]
set_property SLEW   SLOW [get_ports LED2]
set_property DRIVE  4    [get_ports LED3]
set_property SLEW   SLOW [get_ports LED3]

## False paths on static LED outputs
set_false_path -to [get_ports {LED0_R LED0_G LED0_B LED1 LED2 LED3}]

## -----------------------------------------------------------------------------
## GPIO — PMOD JA (2×6 header, top row JA1-JA4, bottom row JA7-JA10)
## Bidirectional — IOSTANDARD LVCMOS33, drive 4 mA, slow slew
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN V12  IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports JA1]
set_property -dict { PACKAGE_PIN W12  IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports JA2]
set_property -dict { PACKAGE_PIN V10  IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports JA3]
set_property -dict { PACKAGE_PIN W10  IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports JA4]
set_property -dict { PACKAGE_PIN W11  IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports JA7]
set_property -dict { PACKAGE_PIN Y11  IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports JA8]
set_property -dict { PACKAGE_PIN Y12  IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports JA9]
set_property -dict { PACKAGE_PIN AA11 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW } [get_ports JA10]

## -----------------------------------------------------------------------------
## Bitstream configuration
## -----------------------------------------------------------------------------
set_property CONFIG_VOLTAGE        3.3 [current_design]
set_property CFGBVS                VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
