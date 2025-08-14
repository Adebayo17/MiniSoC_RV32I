# Memory Simulation Makefile

# -------------------------------------------
# Configuration
# -------------------------------------------
MEM_SIM_DIR := $(SIM_DIR)/mem
MEM_SRC_DIR := $(TOP_DIR)/src/mem
MEM_SIM_BUILD_DIR := $(SIM_BUILD_DIR)/mem

# -------------------------------------------
# Source files
# -------------------------------------------
MEM_SOURCES := \
    $(MEM_SRC_DIR)/dmem/dmem.v \
    $(MEM_SRC_DIR)/dmem/dmem_wrapper.v \
    $(MEM_SRC_DIR)/imem/imem.v \
    $(MEM_SRC_DIR)/imem/imem_wrapper.v \
    $(MEM_SRC_DIR)/mem_init/mem_init.v

MEM_TESTBENCHES := \
    $(MEM_SIM_DIR)/tb_dmem.v \
    $(MEM_SIM_DIR)/tb_imem.v \
    $(MEM_SIM_DIR)/tb_mem_init.v

# -------------------------------------------
# Targets
# -------------------------------------------
.PHONY: sim.mem sim.mem.run sim.mem.wave sim.mem.clean

sim.mem: $(MEM_SIM_BUILD_DIR)/dmem_tb.out $(MEM_SIM_BUILD_DIR)/imem_tb.out $(MEM_SIM_BUILD_DIR)/mem_init_tb.out

$(MEM_SIM_BUILD_DIR)/dmem_tb.out: $(MEM_SOURCES) $(MEM_SIM_DIR)/tb_dmem.v
	@mkdir -p $(MEM_SIM_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^
	@echo ""
	@echo "DMEM testbench built: $@"

$(MEM_SIM_BUILD_DIR)/imem_tb.out: $(MEM_SOURCES) $(MEM_SIM_DIR)/tb_imem.v
	@mkdir -p $(MEM_SIM_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^
	@echo ""
	@echo "IMEM testbench built: $@"

$(MEM_SIM_BUILD_DIR)/mem_init_tb.out: $(MEM_SOURCES) $(MEM_SIM_DIR)/tb_mem_init.v
	@mkdir -p $(MEM_SIM_BUILD_DIR)
	$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^
	@echo ""
	@echo "mem_init testbench built: $@"

sim.mem.run: sim.mem
	@echo ""
	@echo "Running memory module tests..."
	@cd $(MEM_SIM_BUILD_DIR) && $(VVP) dmem_tb.out -l dmem_simulation.log
	@cd $(MEM_SIM_BUILD_DIR) && $(VVP) imem_tb.out -l imem_simulation.log
	@cd $(MEM_SIM_BUILD_DIR) && $(VVP) mem_init_tb.out -l mem_init_simulation.log

sim.mem.wave:
	$(GTKWAVE) $(MEM_SIM_BUILD_DIR)/dmem_tb.vcd &
	$(GTKWAVE) $(MEM_SIM_BUILD_DIR)/imem_tb.vcd &
	$(GTKWAVE) $(MEM_SIM_BUILD_DIR)/mem_init_tb.vcd &

sim.mem.clean:
	rm -rf $(MEM_SIM_BUILD_DIR)
	rm -f *.vcd *.log

# -------------------------------------------
# Shortcuts
# -------------------------------------------
mem: sim.mem
mem-run: sim.mem.run
mem-wave: sim.mem.wave
mem-clean: sim.mem.clean