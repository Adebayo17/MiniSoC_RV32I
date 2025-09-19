# Peripheral Simulation Makefile

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
# Peripheral target
# -------------------------------------------
.PHONY: sim.uart sim.timer sim.gpio sim.peripheral

sim.peripheral: sim.uart sim.timer sim.gpio

# -------------------------------------------
# UART Simulation
# -------------------------------------------
.PHONY: sim.uart.run sim.uart.wave

# Source Files
UART_SOURCES := \
    $(PERIPHERAL_SRC_DIR)/uart/uart_baudgen.v \
    $(PERIPHERAL_SRC_DIR)/uart/uart_rx.v \
    $(PERIPHERAL_SRC_DIR)/uart/uart_tx.v \
    $(PERIPHERAL_SRC_DIR)/uart/uart.v \
    $(PERIPHERAL_SRC_DIR)/uart/uart_wrapper.v

UART_TB := $(PERIPHERAL_SIM_DIR)/uart/tb_uart.v

$(UART_BUILD_DIR)/uart_tb.out: $(UART_SOURCES) $(UART_TB)
	@mkdir -p $(UART_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(PERIPHERAL_SRC_DIR) -I$(PERIPHERAL_SRC_DIR)/uart $^
	@echo "[UART] Testbench built: $@"
	@echo ""

sim.uart: $(UART_BUILD_DIR)/uart_tb.out

sim.uart.run: sim.uart
	@echo "\n[UART] Running tests..."
	@cd $(UART_BUILD_DIR) && $(VVP) uart_tb.out -l uart.log
	@echo "[UART] Test completed - see $(UART_BUILD_DIR)/uart.log"
	@echo ""

sim.uart.wave:
	$(GTKWAVE) $(UART_BUILD_DIR)/uart_tb.vcd &

# -------------------------------------------
# TIMER Simulation
# -------------------------------------------
.PHONY: sim.timer.run sim.timer.wave

TIMER_SOURCES := \
    $(PERIPHERAL_SRC_DIR)/timer/timer.v \
    $(PERIPHERAL_SRC_DIR)/timer/timer_wrapper.v

TIMER_TB := $(PERIPHERAL_SIM_DIR)/timer/tb_timer.v

$(TIMER_BUILD_DIR)/timer_tb.out: $(TIMER_SOURCES) $(TIMER_TB)
	@mkdir -p $(TIMER_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(PERIPHERAL_SRC_DIR) -I$(PERIPHERAL_SRC_DIR)/timer $^
	@echo "[TIMER] Testbench built: $@"
	@echo ""

sim.timer: $(TIMER_BUILD_DIR)/timer_tb.out

sim.timer.run: sim.timer
	@echo "\n[TIMER] Running tests..."
	@cd $(TIMER_BUILD_DIR) && $(VVP) timer_tb.out -l timer.log
	@echo "[TIMER] Test completed - see $(TIMER_BUILD_DIR)/timer.log"
	@echo ""

sim.timer.wave:
	$(GTKWAVE) $(TIMER_BUILD_DIR)/timer_tb.vcd &

# -------------------------------------------
# GPIO Simulation
# -------------------------------------------
.PHONY: sim.gpio.run sim.gpio.wave sim.gpio.latency sim.gpio.latency.run sim.gpio.latency.wave

GPIO_SOURCES := \
    $(PERIPHERAL_SRC_DIR)/gpio/gpio.v \
    $(PERIPHERAL_SRC_DIR)/gpio/gpio_wrapper.v

GPIO_TB         := $(PERIPHERAL_SIM_DIR)/gpio/tb_gpio.v
GPIO_TB_LATENCY := $(PERIPHERAL_SIM_DIR)/gpio/tb_gpio_latency.v

$(GPIO_BUILD_DIR)/gpio_tb.out: $(GPIO_SOURCES) $(GPIO_TB)
	@mkdir -p $(GPIO_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(PERIPHERAL_SRC_DIR) -I$(PERIPHERAL_SRC_DIR)/gpio $^
	@echo "[GPIO] Testbench built: $@"
	@echo ""

$(GPIO_BUILD_DIR)/gpio_latency_tb.out: $(GPIO_SOURCES) $(GPIO_TB_LATENCY)
	@mkdir -p $(GPIO_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(PERIPHERAL_SRC_DIR) -I$(PERIPHERAL_SRC_DIR)/gpio $^
	@echo "[GPIO] Latency testbench built: $@"
	@echo ""

sim.gpio: $(GPIO_BUILD_DIR)/gpio_tb.out
sim.gpio.latency: $(GPIO_BUILD_DIR)/gpio_latency_tb.out

sim.gpio.run: sim.gpio
	@echo "\n[GPIO] Running tests..."
	@cd $(GPIO_BUILD_DIR) && $(VVP) gpio_tb.out -l gpio.log
	@echo "[GPIO] Test completed - see $(GPIO_BUILD_DIR)/gpio.log"
	@echo ""

sim.gpio.latency.run: sim.gpio.latency
	@echo "\n[GPIO] Running latency tests..."
	@cd $(GPIO_BUILD_DIR) && $(VVP) gpio_latency_tb.out -l gpio_latency.log
	@echo "[GPIO] Latency test completed - see $(GPIO_BUILD_DIR)/gpio_latency.log"
	@echo ""

sim.gpio.wave:
	$(GTKWAVE) $(GPIO_BUILD_DIR)/gpio_tb.vcd &

sim.gpio.latency.wave:
	$(GTKWAVE) $(GPIO_BUILD_DIR)/gpio_latency_tb.vcd &

# -------------------------------------------
# Aggregate Targets
# -------------------------------------------
.PHONY: sim.peripheral.run sim.peripheral.wave

sim.peripheral.run: sim.uart.run sim.timer.run sim.gpio.run
	@echo "All peripheral tests completed"

sim.peripheral.wave: sim.uart.wave sim.timer.wave sim.gpio.wave

# -------------------------------------------
# Clean Targets
# -------------------------------------------
.PHONY: sim.peripheral.clean

sim.peripheral.clean:
	@echo "Cleaning peripheral test files..."
	@rm -rf $(PERIPHERAL_SIM_BUILD_DIR)
	@find $(PERIPHERAL_SIM_DIR) -name "*.vcd" -delete
	@find $(PERIPHERAL_SIM_DIR) -name "*.log" -delete

# -------------------------------------------
# Shortcut Commands (consistent naming)
# -------------------------------------------
peripheral: sim.peripheral
peripheral-run: sim.peripheral.run
peripheral-wave: sim.peripheral.wave
peripheral-clean: sim.peripheral.clean

uart: sim.uart
uart-run: sim.uart.run
uart-wave: sim.uart.wave

timer: sim.timer
timer-run: sim.timer.run
timer-wave: sim.timer.wave

gpio: sim.gpio
gpio-run: sim.gpio.run
gpio-wave: sim.gpio.wave

gpio-latency: sim.gpio.latency
gpio-latency-run: sim.gpio.latency.run
gpio-latency-wave: sim.gpio.latency.wave