# ==============================================================================
# src/include.src.mk : Hardware Source Preparation
# ==============================================================================

# -------------------------------------------
# Source Directories
# -------------------------------------------
SRC_DIR 		:= $(TOP_DIR)/src
SRC_BUILD_DIR 	:= $(MINISOC_BUILD_DIR)/src

export SRC_DIR SRC_BUILD_DIR

# -------------------------------------------
# Source Files by Category
# -------------------------------------------
# Wildcards automatically find all .v and .vh files!

# CPU Core (src/cpu/*.v)
CPU_SRCS    := $(wildcard $(SRC_DIR)/cpu/*.v $(SRC_DIR)/cpu/*.vh)

# Memory (src/mem/*/*.v) - Search in all subfolders of mem/
MEM_SRCS    := $(wildcard $(SRC_DIR)/mem/*/*.v $(SRC_DIR)/mem/*/*.vh)

# Bus
BUS_SRCS    := $(wildcard $(SRC_DIR)/bus/*.v $(SRC_DIR)/bus/*.vh)

# Peripherals (src/peripheral/*/*.v)
PERIPH_SRCS := $(wildcard $(SRC_DIR)/peripheral/*/*.v $(SRC_DIR)/peripheral/*/*.vh)

# Top Level
TOP_SRCS    := $(wildcard $(SRC_DIR)/top/*.v $(SRC_DIR)/top/*.vh)

# Common & Pads
COMMON_SRCS := $(wildcard $(SRC_DIR)/common/*.v $(SRC_DIR)/common/*.vh) \
               $(wildcard $(SRC_DIR)/pad/*.v $(SRC_DIR)/pad/*.vh)

# Merge all files
ALL_SRCS    := $(CPU_SRCS) $(MEM_SRCS) $(BUS_SRCS) $(PERIPH_SRCS) $(TOP_SRCS) $(COMMON_SRCS)


# -------------------------------------------
# Filelist Generation (For Simulation/Synthesis)
# -------------------------------------------
MINISOC_FILELIST := $(MINISOC_BUILD_DIR)/minisoc.f

# Source targets
.PHONY: src.all src.clean src.filelist

src.all: src.filelist
	$(Q)echo "  [SRC] Hardware sources ready "
	$(Q)echo "    - Total files: $(words $(ALL_SRCS))"
	$(Q)echo ""

src.clean:
	$(Q)echo "  [CLEAN]     Hardware filelist"
	$(Q)rm -f $(MINISOC_FILELIST)

src.filelist: $(MINISOC_FILELIST)

# Automatic generation of the file listing all original source paths
$(MINISOC_FILELIST): $(ALL_SRCS)
	@mkdir -p $(dir $@)
	$(Q)echo "  [FILELIST]  $@"
	$(Q)echo "# MiniSoC-RV32I Source File List" > $@
	$(Q)echo "# Generated automatically by Makefile - DO NOT EDIT" >> $@
	$(Q)echo "" >> $@
	$(Q)for file in $(ALL_SRCS); do \
		echo "$$file" >> $@; \
	done