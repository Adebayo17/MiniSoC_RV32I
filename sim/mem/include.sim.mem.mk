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
	@echo ""

sim.dmem: $(DMEM_BUILD_DIR)/dmem_tb.out

# IMEM
$(IMEM_BUILD_DIR)/imem_tb.out: $(IMEM_SOURCES) $(IMEM_TB)
	@mkdir -p $(IMEM_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^
	@echo "[IMEM] Testbench built: $@"
	@echo ""

sim.imem: $(IMEM_BUILD_DIR)/imem_tb.out

# MEM_INIT
$(MEM_INIT_BUILD_DIR)/mem_init_tb.out: $(MEM_INIT_SOURCES) $(MEM_INIT_TB)
	@mkdir -p $(MEM_INIT_BUILD_DIR)
	@touch $(MEM_INIT_BUILD_DIR)/firmware.hex
	$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^
	@echo "[MEM_INIT] Testbench built: $@"
	@echo ""

sim.mem_init: $(MEM_INIT_BUILD_DIR)/mem_init_tb.out

# -------------------------------------------
# Run Targets
# -------------------------------------------
.PHONY: sim.dmem.run sim.imem.run sim.mem_init.run sim.mem.run

# Individual run targets
sim.dmem.run: sim.dmem
	@echo "\n[DMEM] Running tests..."
	@cd $(DMEM_BUILD_DIR) && $(VVP) dmem_tb.out -l dmem.log
	@echo "[DMEM] Test completed - see $(DMEM_BUILD_DIR)/dmem.log"
	@echo ""

sim.imem.run: sim.imem
	@echo "\n[IMEM] Running tests..."
	@cd $(IMEM_BUILD_DIR) && $(VVP) imem_tb.out -l imem.log
	@echo "[IMEM] Test completed - see $(IMEM_BUILD_DIR)/imem.log"
	@echo ""

sim.mem_init.run: sim.mem_init
	@echo "\n[MEM_INIT] Running tests..."
	@cd $(MEM_INIT_BUILD_DIR) && $(VVP) mem_init_tb.out -l mem_init.log
	@echo "[MEM_INIT] Test completed - see $(MEM_INIT_BUILD_DIR)/mem_init.log"
	@echo ""

# Run all memory tests
sim.mem.run: sim.dmem.run sim.imem.run sim.mem_init.run
	@echo "All memory tests completed"
	@echo ""


# -------------------------------------------
# Waveform Targets
# -------------------------------------------
.PHONY: sim.dmem.wave sim.imem.wave sim.mem_init.wave sim.mem.wave

sim.dmem.wave:
	$(GTKWAVE) $(DMEM_BUILD_DIR)/dmem_tb.vcd &

sim.imem.wave:
	$(GTKWAVE) $(IMEM_BUILD_DIR)/imem_tb.vcd &

sim.mem_init.wave:
	$(GTKWAVE) $(MEM_INIT_BUILD_DIR)/mem_init_tb.vcd &

sim.mem.wave: sim.dmem.wave sim.imem.wave sim.mem_init.wave

# -------------------------------------------
# Clean Targets
# -------------------------------------------
.PHONY: sim.mem.clean

sim.mem.clean:
	@echo "Cleaning memory test files..."
	@rm -rf $(MEM_SIM_BUILD_DIR)
	@find $(MEM_SIM_DIR) -name "*.vcd" -delete
	@find $(MEM_SIM_DIR) -name "*.log" -delete
	@echo ""

# -------------------------------------------
# Shortcut Commands
# -------------------------------------------
mem: sim.mem
mem-run: sim.mem.run
mem-wave: sim.mem.wave
mem-clean: sim.mem.clean

dmem: sim.dmem
dmem-run: sim.dmem.run
dmem-wave: sim.dmem.wave

imem: sim.imem
imem-run: sim.imem.run
imem-wave: sim.imem.wave

mem-init: sim.mem_init
mem-init-run: sim.mem_init.run
mem-init-wave: sim.mem_init.wave