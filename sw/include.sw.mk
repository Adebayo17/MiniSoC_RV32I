# sw/include.sw.mk : sw Folder Makefile

# -------------------------------------------
# Common Simulation Settings
# -------------------------------------------
SW_DIR := $(TOP_DIR)/sw
SW_BUILD_DIR := $(BUILD_DIR)/sw


# -------------------------------------------
# Include sub-components
# -------------------------------------------


# -------------------------------------------
# Top-level simulation Targets
# -------------------------------------------
.PHONY: sw.all sw.clean

sw.all: 

sw.clean:
	@rm -rf $(SW_BUILD_DIR)
