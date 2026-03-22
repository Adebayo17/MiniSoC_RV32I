# ==============================================================================
# sim/peripheral/include.sim.peripheral.mk : Peripheral Simulation Makefile
# ==============================================================================

# -------------------------------------------
# Configuration
# -------------------------------------------
PERIPHERAL_SIM_DIR         := $(SIM_DIR)/peripheral
PERIPHERAL_SRC_DIR         := $(TOP_DIR)/src/peripheral
PERIPHERAL_SIM_BUILD_DIR   := $(SIM_BUILD_DIR)/peripheral

# Build directories
UART_BUILD_DIR  := $(PERIPHERAL_SIM_BUILD_DIR)/uart
GPIO_BUILD_DIR  := $(PERIPHERAL_SIM_BUILD_DIR)/gpio
TIMER_BUILD_DIR := $(PERIPHERAL_SIM_BUILD_DIR)/timer

# -------------------------------------------
# Source Files (Auto-discovery)
# -------------------------------------------
# UART
UART_SOURCES := $(wildcard $(PERIPHERAL_SRC_DIR)/uart/*.v)
UART_TB      := $(wildcard $(PERIPHERAL_SIM_DIR)/uart/*.v)

# TIMER
TIMER_SOURCES := $(wildcard $(PERIPHERAL_SRC_DIR)/timer/*.v)
TIMER_TB      := $(wildcard $(PERIPHERAL_SIM_DIR)/timer/*.v)

# GPIO
GPIO_SOURCES := $(wildcard $(PERIPHERAL_SRC_DIR)/gpio/*.v)
GPIO_TB      := $(wildcard $(PERIPHERAL_SIM_DIR)/gpio/*.v)

# -------------------------------------------
# Aggregate Peripheral Target
# -------------------------------------------
.PHONY: sim.uart sim.timer sim.gpio sim.peripheral

sim.peripheral: sim.uart sim.timer sim.gpio

# -------------------------------------------
# UART Simulation
# -------------------------------------------
.PHONY: sim.uart.run sim.uart.wave

$(UART_BUILD_DIR)/uart_tb.out: $(UART_SOURCES) $(UART_TB)
	@mkdir -p $(dir $@)
	$(Q)echo "  [IVERILOG]  Compiling UART Testbench"
	$(Q)$(IVERILOG) -o $@ -I$(PERIPHERAL_SRC_DIR) -I$(PERIPHERAL_SRC_DIR)/uart $^

sim.uart: $(UART_BUILD_DIR)/uart_tb.out

sim.uart.run: sim.uart
	$(Q)echo "  [VVP]       Running UART Simulation..."
	$(Q)cd $(UART_BUILD_DIR) && $(VVP) uart_tb.out -l uart.log
	$(Q)echo "  [SIM-UART]  Test completed. Log: $(UART_BUILD_DIR)/uart.log"

sim.uart.wave:
	$(Q)echo "  [GTKWAVE]   Opening UART Waveform"
	$(Q)$(GTKWAVE) $(UART_BUILD_DIR)/uart_tb.vcd &

# -------------------------------------------
# TIMER Simulation
# -------------------------------------------
.PHONY: sim.timer.run sim.timer.wave

$(TIMER_BUILD_DIR)/timer_tb.out: $(TIMER_SOURCES) $(TIMER_TB)
	@mkdir -p $(dir $@)
	$(Q)echo "  [IVERILOG]  Compiling TIMER Testbench"
	$(Q)$(IVERILOG) -o $@ -I$(PERIPHERAL_SRC_DIR) -I$(PERIPHERAL_SRC_DIR)/timer $^

sim.timer: $(TIMER_BUILD_DIR)/timer_tb.out

sim.timer.run: sim.timer
	$(Q)echo "  [VVP]       Running TIMER Simulation..."
	$(Q)cd $(TIMER_BUILD_DIR) && $(VVP) timer_tb.out -l timer.log
	$(Q)echo "  [SIM-TIMER] Test completed. Log: $(TIMER_BUILD_DIR)/timer.log"

sim.timer.wave:
	$(Q)echo "  [GTKWAVE]   Opening TIMER Waveform"
	$(Q)$(GTKWAVE) $(TIMER_BUILD_DIR)/timer_tb.vcd &

# -------------------------------------------
# GPIO Simulation
# -------------------------------------------
.PHONY: sim.gpio sim.gpio.run sim.gpio.wave 

$(GPIO_BUILD_DIR)/gpio_tb.out: $(GPIO_SOURCES) $(GPIO_TB)
	@mkdir -p $(dir $@)
	$(Q)echo "  [IVERILOG]  Compiling GPIO Testbench"
	$(Q)$(IVERILOG) -o $@ -I$(PERIPHERAL_SRC_DIR) -I$(PERIPHERAL_SRC_DIR)/gpio $^

sim.gpio: $(GPIO_BUILD_DIR)/gpio_tb.out

sim.gpio.run: sim.gpio
	$(Q)echo "  [VVP]       Running GPIO Simulation..."
	$(Q)cd $(GPIO_BUILD_DIR) && $(VVP) gpio_tb.out -l gpio.log
	$(Q)echo "  [SIM-GPIO]  Test completed. Log: $(GPIO_BUILD_DIR)/gpio.log"

sim.gpio.wave:
	$(Q)echo "  [GTKWAVE]   Opening GPIO Waveform"
	$(Q)$(GTKWAVE) $(GPIO_BUILD_DIR)/gpio_tb.vcd &

# -------------------------------------------
# Aggregate Run/Wave Targets
# -------------------------------------------
.PHONY: sim.peripheral.run sim.peripheral.wave

sim.peripheral.run: sim.uart.run sim.timer.run sim.gpio.run
	$(Q)echo "  [SIM]       All peripheral tests completed"

sim.peripheral.wave: sim.uart.wave sim.timer.wave sim.gpio.wave

# -------------------------------------------
# Clean Targets
# -------------------------------------------
.PHONY: sim.peripheral.clean

sim.peripheral.clean:
	$(Q)echo "  [CLEAN]     Peripheral Simulation artifacts"
	$(Q)rm -rf $(PERIPHERAL_SIM_BUILD_DIR)

# -------------------------------------------
# Help
# -------------------------------------------
.PHONY: sim.peripheral.help

sim.peripheral.help:
	@echo "================================================================================"
	@echo "MiniSoC-RV32I: PERIPHERALS Makefile Commands"
	@echo "================================================================================"
	@echo ""
	@echo "PERIPHERAL:"
	@echo "  make sim.peripheral        - Build all peripherals simulation"
	@echo "  make sim.peripheral.run    - Run all peripherals simulation"
	@echo "  make sim.peripheral.wave   - Open all peripherals waveform"
	@echo "  make sim.peripheral.clean  - Clean all peripherals simulation files"
	@echo "  make sim.peripheral.help   - Show peripheral simulation help"
	@echo ""
	@echo "UART:"
	@echo "  make sim.uart              - Build uart simulation"
	@echo "  make sim.uart.run          - Run uart simulation"
	@echo "  make sim.uart.wave         - Open uart waveform"
	@echo ""
	@echo "GPIO:"
	@echo "  make sim.gpio              - Build gpio simulation"
	@echo "  make sim.gpio.run          - Run gpio simulation"
	@echo "  make sim.gpio.wave         - Open gpio waveform"
	@echo ""
	@echo "TIMER:"
	@echo "  make sim.timer             - Build timer simulation"
	@echo "  make sim.timer.run         - Run timer simulation"
	@echo "  make sim.timer.wave        - Open timer waveform"
	@echo ""
	@echo "Shortcuts:"
	@echo "  make peripheral            - Alias for sim.peripheral"
	@echo "  make peripheral-run        - Alias for sim.peripheral.run"
	@echo "  make peripheral-wave       - Alias for sim.peripheral.wave"
	@echo "  make peripheral-clean      - Alias for sim.peripheral.clean"
	@echo "  make peripheral-help       - Alias for sim.peripheral.help"
	@echo "  make uart                  - Alias for sim.uart"
	@echo "  make uart-run              - Alias for sim.uart.run"
	@echo "  make uart-wave             - Alias for sim.uart.wave"
	@echo "  make gpio                  - Alias for sim.gpio"
	@echo "  make gpio-run              - Alias for sim.gpio.run"
	@echo "  make gpio-wave             - Alias for sim.gpio.wave"
	@echo "  make timer                 - Alias for sim.timer"
	@echo "  make timer-run             - Alias for sim.timer.run"
	@echo "  make timer-wave            - Alias for sim.timer.wave"
	@echo "================================================================================"

# -------------------------------------------
# Shortcut Commands
# -------------------------------------------
.PHONY: peripheral peripheral-run peripheral-wave peripheral-clean peripheral-help \
        uart uart-run uart-wave \
        timer timer-run timer-wave \
        gpio gpio-run gpio-wave

peripheral:       sim.peripheral
peripheral-run:   sim.peripheral.run
peripheral-wave:  sim.peripheral.wave
peripheral-clean: sim.peripheral.clean
peripheral-help:  sim.peripheral.help

uart:       sim.uart
uart-run:   sim.uart.run
uart-wave:  sim.uart.wave

timer:      sim.timer
timer-run:  sim.timer.run
timer-wave: sim.timer.wave

gpio:       sim.gpio
gpio-run:   sim.gpio.run
gpio-wave:  sim.gpio.wave