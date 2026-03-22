# ==============================================================================
# sim/mem/include.sim.mem.mk : Memory Simulation Makefile
# ==============================================================================

# -------------------------------------------
# Configuration
# -------------------------------------------
MEM_SIM_DIR 		:= $(SIM_DIR)/mem
MEM_SRC_DIR 		:= $(TOP_DIR)/src/mem
MEM_SIM_BUILD_DIR 	:= $(SIM_BUILD_DIR)/mem

# Build directories for sub-components
DMEM_BUILD_DIR 		:= $(MEM_SIM_BUILD_DIR)/dmem
IMEM_BUILD_DIR 		:= $(MEM_SIM_BUILD_DIR)/imem
MEM_INIT_BUILD_DIR 	:= $(MEM_SIM_BUILD_DIR)/mem_init

# -------------------------------------------
# Source Files
# -------------------------------------------

# Common sources
MEM_COMMON_SOURCES := $(wildcard $(MEM_SRC_DIR)/mem_init/*.v)

# Hardware sources per module
DMEM_SOURCES       := $(wildcard $(MEM_SRC_DIR)/dmem/*.v) $(MEM_COMMON_SOURCES)
IMEM_SOURCES       := $(wildcard $(MEM_SRC_DIR)/imem/*.v) $(MEM_COMMON_SOURCES)
MEM_INIT_SOURCES   := $(MEM_COMMON_SOURCES) $(wildcard $(MEM_SRC_DIR)/imem/*.v) $(wildcard $(MEM_SRC_DIR)/dmem/*.v)

# Testbenches
DMEM_TB            := $(wildcard $(MEM_SIM_DIR)/dmem/*.v)
IMEM_TB            := $(wildcard $(MEM_SIM_DIR)/imem/*.v)
MEM_INIT_TB        := $(wildcard $(MEM_SIM_DIR)/mem_init/*.v)

# -------------------------------------------
# Build Targets
# -------------------------------------------
.PHONY: sim.dmem sim.imem sim.mem_init sim.mem

# All memory tests
sim.mem: sim.dmem sim.imem sim.mem_init

# DMEM
$(DMEM_BUILD_DIR)/dmem_tb.out: $(DMEM_SOURCES) $(DMEM_TB)
	@mkdir -p $(dir $@)
	$(Q)echo "  [IVERILOG]  Compiling DMEM Testbench"
	$(Q)$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^

sim.dmem: $(DMEM_BUILD_DIR)/dmem_tb.out

# IMEM
$(IMEM_BUILD_DIR)/imem_tb.out: $(IMEM_SOURCES) $(IMEM_TB)
	@mkdir -p $(dir $@)
	$(Q)echo "  [IVERILOG]  Compiling IMEM Testbench"
	$(Q)$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^

sim.imem: $(IMEM_BUILD_DIR)/imem_tb.out

# MEM_INIT
$(MEM_INIT_BUILD_DIR)/mem_init_tb.out: $(MEM_INIT_SOURCES) $(MEM_INIT_TB)
	@mkdir -p $(dir $@)
	$(Q)touch $(dir $@)/firmware.hex
	$(Q)echo "  [IVERILOG]  Compiling MEM_INIT Testbench"
	$(Q)$(IVERILOG) -o $@ -I$(MEM_SRC_DIR) $^

sim.mem_init: $(MEM_INIT_BUILD_DIR)/mem_init_tb.out

# -------------------------------------------
# Run Targets
# -------------------------------------------
.PHONY: sim.dmem.run sim.imem.run sim.mem_init.run sim.mem.run

# Individual run targets
sim.dmem.run: sim.dmem
	$(Q)echo "  [VVP]       Running DMEM Simulation..."
	$(Q)cd $(DMEM_BUILD_DIR) && $(VVP) dmem_tb.out -l dmem.log
	$(Q)echo "  [SIM-DMEM]  Test completed. Log: $(DMEM_BUILD_DIR)/dmem.log"

sim.imem.run: sim.imem
	$(Q)echo "  [VVP]       Running IMEM Simulation..."
	$(Q)cd $(IMEM_BUILD_DIR) && $(VVP) imem_tb.out -l imem.log
	$(Q)echo "  [SIM-IMEM]  Test completed. Log: $(IMEM_BUILD_DIR)/imem.log"

sim.mem_init.run: sim.mem_init
	$(Q)echo "  [VVP]       Running MEM_INIT Simulation..."
	$(Q)cd $(MEM_INIT_BUILD_DIR) && $(VVP) mem_init_tb.out -l mem_init.log
	$(Q)echo "  [SIM-MINIT] Test completed. Log: $(MEM_INIT_BUILD_DIR)/mem_init.log"

# Run all memory tests
sim.mem.run: sim.dmem.run sim.imem.run sim.mem_init.run
	$(Q)echo "  [SIM]       All memory tests completed"


# -------------------------------------------
# Waveform Targets
# -------------------------------------------
.PHONY: sim.dmem.wave sim.imem.wave sim.mem_init.wave sim.mem.wave

sim.dmem.wave:
	$(Q)echo "  [GTKWAVE]   Opening DMEM Waveform"
	$(Q)$(GTKWAVE) $(DMEM_BUILD_DIR)/dmem_tb.vcd &

sim.imem.wave:
	$(Q)echo "  [GTKWAVE]   Opening IMEM Waveform"
	$(Q)$(GTKWAVE) $(IMEM_BUILD_DIR)/imem_tb.vcd &

sim.mem_init.wave:
	$(Q)echo "  [GTKWAVE]   Opening MEM_INIT Waveform"
	$(Q)$(GTKWAVE) $(MEM_INIT_BUILD_DIR)/mem_init_tb.vcd &

sim.mem.wave: sim.dmem.wave sim.imem.wave sim.mem_init.wave

# -------------------------------------------
# Clean Targets
# -------------------------------------------
.PHONY: sim.mem.clean

sim.mem.clean:
	$(Q)echo "  [CLEAN]     Memory Simulation artifacts"
	$(Q)rm -rf $(MEM_SIM_BUILD_DIR)


# -------------------------------------------
# Help
# -------------------------------------------
.PHONY: sim.mem.help

sim.mem.help:
	@echo "================================================================================"
	@echo "MiniSoC-RV32I: MEMORIES Makefile Commands"
	@echo "================================================================================"
	@echo ""
	@echo "MEM:"
	@echo "  make sim.mem             	- Build all memories simulation"
	@echo "  make sim.mem.run         	- Run all memories simulation"
	@echo "  make sim.mem.wave        	- Open all memories waveform"
	@echo "  make sim.mem.clean       	- Clean all memories simulation files"
	@echo "  make sim.mem.help        	- Show mem simulation help"
	@echo ""
	@echo "IMEM:"
	@echo "  make sim.imem          	- Build imem simulation"
	@echo "  make sim.imem.run         	- Run imem simulation"
	@echo "  make sim.imem.wave     	- Open imem waveform"
	@echo ""
	@echo "DMEM:"
	@echo "  make sim.dmem          	- Build dmem simulation"
	@echo "  make sim.dmem.run         	- Run dmem simulation"
	@echo "  make sim.dmem.wave     	- Open dmem waveform"
	@echo ""
	@echo "MEM_INIT:"
	@echo "  make sim.mem_init         	- Build mem_init simulation"
	@echo "  make sim.mem_init.run     	- Run mem_init simulation"
	@echo "  make sim.mem_init.wave    	- Open mem_init waveform"
	@echo ""
	@echo "Shortcuts:"
	@echo "  make mem                	- Alias for sim.mem"
	@echo "  make mem-run            	- Alias for sim.mem.run"
	@echo "  make mem-wave            	- Alias for sim.mem.wave"
	@echo "  make mem-clean     		- Alias for sim.mem.clean"
	@echo "  make mem-help            	- Alias for sim.mem.help"
	@echo "  make imem                	- Alias for sim.imem"
	@echo "  make imem-run            	- Alias for sim.imem.run"
	@echo "  make imem-wave     		- Alias for sim.imem.wave"
	@echo "  make dmem                	- Alias for sim.dmem"
	@echo "  make dmem-run            	- Alias for sim.dmem.run"
	@echo "  make dmem-wave          	- Alias for sim.dmem.wave"
	@echo "  make mem-init            	- Alias for sim.mem_init"
	@echo "  make mem-init-run        	- Alias for sim.mem_init.run"
	@echo "  make mem-init-wave       	- Alias for sim.mem_init.wave"
	@echo "================================================================================"


# -------------------------------------------
# Shortcut Commands
# -------------------------------------------
.PHONY: mem mem-run mem-wave mem-clean mem-help \
        dmem dmem-run dmem-wave \
        imem imem-run imem-wave \
        mem-init mem-init-run mem-init-wave
		
mem: 			sim.mem
mem-run: 		sim.mem.run
mem-wave: 		sim.mem.wave
mem-clean: 		sim.mem.clean
mem-help: 		sim.mem.help

dmem: 			sim.dmem
dmem-run: 		sim.dmem.run
dmem-wave: 		sim.dmem.wave

imem: 			sim.imem
imem-run: 		sim.imem.run
imem-wave: 		sim.imem.wave

mem-init: 		sim.mem_init
mem-init-run: 	sim.mem_init.run
mem-init-wave: 	sim.mem_init.wave