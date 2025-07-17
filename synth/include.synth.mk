# synth/include.synth.mk : synth Folder Makefile

# -------------------------------------------
# Common Simulation Settings
# -------------------------------------------
SYNTH_DIR := $(TOP_DIR)/synth
SYNTH_BUILD_DIR := $(BUILD_DIR)/synth


# -------------------------------------------
# Include sub-components
# -------------------------------------------


# -------------------------------------------
# Top-level simulation Targets
# -------------------------------------------
.PHONY: synth.all synth.clean

synth.all: 

synth.clean:
	@rm -rf $(SYNTH_BUILD_DIR)
