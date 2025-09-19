# Top-level Simulation Makefile

# -------------------------------------------
# Configuration
# -------------------------------------------
TOP_SIM_DIR          := $(SIM_DIR)/top
TOP_SRC_DIR          := $(TOP_DIR)/src/top
TOP_SIM_BUILD_DIR    := $(SIM_BUILD_DIR)/top
TOP_SIM_TESTCASES_DIR:= $(TOP_SIM_DIR)/testcases

# -------------------------------------------
# Source Files
# -------------------------------------------
TOP_SOURCES := \
    $(TOP_SRC_DIR)/top_soc.v \
    $(TOP_SRC_DIR)/mini_rv32i_top.v


TOP_TB := $(TOP_SIM_DIR)/tb_mini_rv32i_top.v

# Firmware file for memory initialization
FIRMWARE_FILE ?= $(SW_BUILD_DIR)/firmware.hex

# -------------------------------------------
# Targets
# -------------------------------------------
.PHONY: sim.top sim.top.run sim.top.wave sim.top.clean

sim.top: $(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.out

# Build
$(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.out: $(BUS_SOURCES) $(IMEM_SOURCES) $(DMEM_SOURCES) $(MEM_INIT_SOURCES) $(UART_SOURCES) $(TIMER_SOURCES) $(GPIO_SOURCES) $(CPU_SOURCES) $(PAD_SOURCES) $(TOP_SOURCES) $(TOP_TB)
	@echo "Building top-level SoC testbench..."
	@mkdir -p $(TOP_SIM_BUILD_DIR)
	$(IVERILOG) -o $@ \
		-I$(TOP_DIR)/src/bus \
		-I$(TOP_DIR)/src/cpu \
		-I$(TOP_DIR)/src/mem \
		-I$(TOP_DIR)/src/mem/imem \
		-I$(TOP_DIR)/src/mem/dmem \
		-I$(TOP_DIR)/src/mem/mem_init \
		-I$(TOP_DIR)/src/peripheral \
		-I$(TOP_DIR)/src/peripheral/uart \
		-I$(TOP_DIR)/src/peripheral/timer \
		-I$(TOP_DIR)/src/peripheral/gpio \
		-I$(TOP_DIR)/src/pad \
		-I$(TOP_SRC_DIR) \
		-DFIRMWARE_FILE=\"$(TOP_SIM_BUILD_DIR)/firmware.hex\" \
		-DBAUD_DIV_RST=104 \
		$^
	@echo "[TOP_SOC] Testbench built: $@"
	@echo ""

# Run
sim.top.run: $(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.out
	@echo "\n[TOP_SOC] Running top-level simulation..."
	@cp $(FIRMWARE_FILE) $(TOP_SIM_BUILD_DIR)/ 2>/dev/null || echo "Warning: Firmware file not found, using default initialization"
	@cd $(TOP_SIM_BUILD_DIR) && $(VVP) mini_rv32i_top_tb.out -l mini_rv32i_top.log
	@echo "[TOP_SOC] Simulation completed - see $(TOP_SIM_BUILD_DIR)/mini_rv32i_top.log"
	@echo ""

# Wave
sim.top.wave:
	$(GTKWAVE) $(TOP_SIM_BUILD_DIR)/mini_rv32i_top_tb.vcd &

# Clean
sim.top.clean:
	rm -rf $(TOP_SIM_BUILD_DIR)
	rm -f $(TOP_SIM_DIR)/*.vcd $(TOP_SIM_DIR)/*.log

# -------------------------------------------
# Shortcuts
# -------------------------------------------
top: sim.top
top-run: sim.top.run
top-wave: sim.top.wave
top-clean: sim.top.clean