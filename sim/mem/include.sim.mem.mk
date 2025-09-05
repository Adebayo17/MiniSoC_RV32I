# Memory Simulation Makefile

# -------------------------------------------
# Configuration
# -------------------------------------------
MEM_SIM_DIR := $(SIM_DIR)/mem
MEM_SRC_DIR := $(TOP_DIR)/src/mem
MEM_SIM_BUILD_DIR := $(SIM_BUILD_DIR)/mem

# Build directories
DMEM_BUILD_DIR := $(MEM_SIM_BUILD_DIR)/dmem
IMEM_BUILD_DIR := $(MEM_SIM_BUILD_DIR)/imem
MEM_INIT_BUILD_DIR := $(MEM_SIM_BUILD_DIR)/mem_init

# -------------------------------------------
# Source Files
# -------------------------------------------

# Common sources
MEM_COMMON_SOURCES := $(MEM_SRC_DIR)/mem_init/mem_init.v

# DMEM sources
DMEM_SOURCES := \
    $(MEM_SRC_DIR)/dmem/dmem.v \
    $(MEM_SRC_DIR)/dmem/dmem_wrapper.v \
    $(MEM_COMMON_SOURCES)

# IMEM sources
IMEM_SOURCES := \
    $(MEM_SRC_DIR)/imem/imem.v \
    $(MEM_SRC_DIR)/imem/imem_wrapper.v \
    $(MEM_COMMON_SOURCES)

# MEM_INIT sources
MEM_INIT_SOURCES := $(MEM_COMMON_SOURCES) \
					$(IMEM_SOURCES) \
					$(DMEM_SOURCES)

# Testbenches
DMEM_TB := $(MEM_SIM_DIR)/dmem/tb_dmem.v
IMEM_TB := $(MEM_SIM_DIR)/imem/tb_imem.v
MEM_INIT_TB := $(MEM_SIM_DIR)/mem_init/tb_mem_init.v

# -------------------------------------------
# Build Targets
# -------------------------------------------
.PHONY: sim.dmem sim.imem sim.mem_init sim.mem

# All memory tests
sim.mem: sim.dmem sim.imem sim.mem_init

# DMEM
$(DMEM_BUILD_DIR)/dmem_tb.out: $(DMEM_SOURCES) $(DMEM_TB)
	@mkdir -p $(DMEM_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^
	@echo "[DMEM] Testbench built: $@"

# IMEM
$(IMEM_BUILD_DIR)/imem_tb.out: $(IMEM_SOURCES) $(IMEM_TB)
	@mkdir -p $(IMEM_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^
	@echo "[IMEM] Testbench built: $@"

# MEM_INIT
$(MEM_INIT_BUILD_DIR)/mem_init_tb.out: $(MEM_INIT_SOURCES) $(MEM_INIT_TB)
	@mkdir -p $(MEM_INIT_BUILD_DIR)
	@touch $(MEM_INIT_BUILD_DIR)/firmware.hex
	$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^
	@echo "[MEM_INIT] Testbench built: $@"

# -------------------------------------------
# Run Targets
# -------------------------------------------
.PHONY: run.dmem run.imem run.mem_init sim.mem.run

# Run all memory tests
sim.mem.run: sim.mem
	@echo "\nRunning all memory tests..."
	@$(MAKE) --no-print-directory run.dmem
	@$(MAKE) --no-print-directory run.imem
	@$(MAKE) --no-print-directory run.mem_init
	@echo "All memory tests completed"

# Run DMEM tests
run.dmem: $(DMEM_BUILD_DIR)/dmem_tb.out
	@echo "\n[DMEM] Running tests..."
	@cd $(DMEM_BUILD_DIR) && $(VVP) dmem_tb.out -l dmem.log
	@echo "[DMEM] Test completed - see $(DMEM_BUILD_DIR)/dmem.log"

# Run IMEM tests
run.imem: $(IMEM_BUILD_DIR)/imem_tb.out
	@echo "\n[IMEM] Running tests..."
	@cd $(IMEM_BUILD_DIR) && $(VVP) imem_tb.out -l imem.log
	@echo "[IMEM] Test completed - see $(IMEM_BUILD_DIR)/imem.log"

# Run MEM_INIT tests
run.mem_init: $(MEM_INIT_BUILD_DIR)/mem_init_tb.out
	@echo "\n[MEM_INIT] Running tests..."
	@cd $(MEM_INIT_BUILD_DIR) && $(VVP) mem_init_tb.out -l mem_init.log
	@echo "[MEM_INIT] Test completed - see $(MEM_INIT_BUILD_DIR)/mem_init.log"

# -------------------------------------------
# Waveform Targets
# -------------------------------------------
.PHONY: wave.dmem wave.imem wave.mem_init sim.mem.wave

sim.mem.wave:
	$(GTKWAVE) $(DMEM_BUILD_DIR)/dmem_tb.vcd &
	$(GTKWAVE) $(IMEM_BUILD_DIR)/imem_tb.vcd &
	$(GTKWAVE) $(MEM_INIT_BUILD_DIR)/mem_init_tb.vcd &

# Individual waveform targets
wave.dmem:
	$(GTKWAVE) $(DMEM_BUILD_DIR)/dmem_tb.vcd &

wave.imem:
	$(GTKWAVE) $(IMEM_BUILD_DIR)/imem_tb.vcd &

wave.mem_init:
	$(GTKWAVE) $(MEM_INIT_BUILD_DIR)/mem_init_tb.vcd &

# -------------------------------------------
# Clean Targets
# -------------------------------------------
.PHONY: sim.mem.clean

sim.mem.clean:
	@echo "Cleaning memory test files..."
	@rm -rf $(MEM_SIM_BUILD_DIR)
	@find $(MEM_SIM_DIR) -name "*.vcd" -delete
	@find $(MEM_SIM_DIR) -name "*.log" -delete

# -------------------------------------------
# Shortcut Commands
# -------------------------------------------

# Build shortcuts
mem: sim.mem
dmem: $(DMEM_BUILD_DIR)/dmem_tb.out
imem: $(IMEM_BUILD_DIR)/imem_tb.out
mem-init: $(MEM_INIT_BUILD_DIR)/mem_init_tb.out

# Run shortcuts
mem-run: sim.mem.run
dmem-run: run.dmem
imem-run: run.imem
mem-init-run: run.mem_init

# Wave shortcuts
mem-wave: sim.mem.wave
dmem-wave: wave.dmem
imem-wave: wave.imem
mem-init-wave: wave.mem_init

# Clean shortcut
mem-clean: sim.mem.clean