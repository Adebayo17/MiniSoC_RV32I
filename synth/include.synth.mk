# ==============================================================================
# synth/include.synth.mk : synth Folder Makefile
# ==============================================================================

# -------------------------------------------
# Common Simulation Settings
# -------------------------------------------
SYNTH_DIR 		:= $(TOP_DIR)/synth
SYNTH_BUILD_DIR ?= $(BUILD_DIR)/synth

# Synthesis Script
SYNTH_SCRIPT 	:= $(SYNTH_DIR)/synth_generic.ys

# Outputs
SYNTH_NETLIST 	:= $(SYNTH_BUILD_DIR)/minisoc_netlist_generic.v
SYNTH_LOG     	:= $(SYNTH_BUILD_DIR)/yosys_synth.log
SYNTH_STATS 	:= $(SYNTH_BUILD_DIR)/minisoc_stats.txt

# -------------------------------------------
# Sources Files
# -------------------------------------------
# Hardware
SYNTH_SOURCES := $(sort \
    $(TOP_SOURCES) \
    $(CPU_SOURCES) \
    $(BUS_SOURCES) \
    $(IMEM_SOURCES) $(DMEM_SOURCES) $(MEM_INIT_SOURCES) \
    $(UART_SOURCES) $(TIMER_SOURCES) $(GPIO_SOURCES) \
    $(PAD_SOURCES)) \
	$(COMMON_SRCS)

# Firmware 
FIRMWARE_MEM_FILE := $(SW_BUILD_DIR)/firmware.mem

# -------------------------------------------
# Top-level Synthesis Targets
# -------------------------------------------
.PHONY: synth.all synth.clean

# Alias standard
synth.all: $(SYNTH_NETLIST)

# La compilation dépend des sources matérielles ET du firmware .mem
$(SYNTH_NETLIST): $(SYNTH_SOURCES) $(FIRMWARE_MEM_FILE) $(SYNTH_SCRIPT)
	@mkdir -p $(SYNTH_BUILD_DIR)
	$(Q)echo "  [YOSYS]     Starting logic synthesis..."
	$(Q)yosys -l $(SYNTH_LOG) -p "\
		read_verilog -I$(INC_DIR) -DSYNTHESIS -DFIRMWARE_PATH=\"$(FIRMWARE_MEM_FILE)\" $(SYNTH_SOURCES); \
		script $(SYNTH_SCRIPT); \
		write_verilog $@"
	
# --- STATISTICS EXTRACTION ---
	$(Q)echo "  [STATS]     Extracting hardware statistics to $(SYNTH_STATS)..."
	$(Q)awk '/Printing statistics\./, /End of script\./' $(SYNTH_LOG) > $(SYNTH_STATS)

	$(Q)echo "  [YOSYS]     ✅ Synthesis successfully completed!"
	$(Q)echo "  [YOSYS]     Netlist : $@"
	$(Q)echo "  [YOSYS]     Hardware Statistics:"
	$(Q)grep -A 20 "Printing statistics" $(SYNTH_LOG)


synth.clean:
	$(Q)echo "  [CLEAN]     Cleaning Synthesis build files..."
	$(Q)rm -rf $(SYNTH_BUILD_DIR)
