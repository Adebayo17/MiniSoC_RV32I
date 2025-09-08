# sim/peripheral/include.sim.peripheral.mk : Peripheral Simulation Makefile

# -------------------------------------------
# Configuration
# -------------------------------------------
PERIPHERAL_SIM_DIR 			:= $(SIM_DIR)/peripheral
PERIPHERAL_SRC_DIR 			:= $(TOP_DIR)/src/peripheral
PERIPHERAL_SIM_BUILD_DIR 	:= $(SIM_BUILD_DIR)/peripheral

# Build directories
UART_BUILD_DIR 	:= $(MEM_SIM_BUILD_DIR)/uart
GPIO_BUILD_DIR 	:= $(MEM_SIM_BUILD_DIR)/gpio
TIMER_BUILD_DIR := $(MEM_SIM_BUILD_DIR)/timer

# -------------------------------------------
# UART Simulation
# -------------------------------------------
.PHONY: run.uart wave.uart
# Source Files
UART_SOURCES := \
	$(PERIPHERAL_SRC_DIR)/uart/uart_baudgen.v \
	$(PERIPHERAL_SRC_DIR)/uart/uart_rx.v \
	$(PERIPHERAL_SRC_DIR)/uart/uart_tx.v \
	$(PERIPHERAL_SRC_DIR)/uart/uart.v \
	$(PERIPHERAL_SRC_DIR)/uart/uart_wrapper.v \

# Testbench File
UART_TB := $(PERIPHERAL_SIM_DIR)/uart/tb_uart.v 

# Build target
$(UART_BUILD_DIR)/uart_tb.out: $(UART_SOURCES) $(UART_TB)
	@mkdir -p $(UART_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(PERIPHERAL_SRC_DIR) $^
	@echo "[UART] Testbench built: $@"

# Run target
run.uart: $(UART_BUILD_DIR)/uart_tb.out
	@echo "\n[UART] Running tests..."
	@cd $(UART_BUILD_DIR) && $(VVP) uart_tb.out -l uart.log
	@echo "[UART] Test completed - see $(UART_BUILD_DIR)/uart.log"

# Waveform Targets
wave.uart:
	$(GTKWAVE) $(UART_BUILD_DIR)/uart_tb.vcd &


# -------------------------------------------
# GPIO Simulation
# -------------------------------------------



# -------------------------------------------
# TIMER Simulation
# -------------------------------------------


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
# Shortcut Commands
# -------------------------------------------

# Build shortcuts
uart: $(UART_BUILD_DIR)/uart_tb.out

# Run shortcuts
uart-run: run.uart

# Wave shortcuts
uart-wave: wave.uart

# Clean shortcut
peripheral-clean: sim.peripheral.clean