# Build System

## Introduction
This document describes the build system for the Mini RV32I SoC software. The build system uses GNU Make to automate compilation, linking, and binary generation for the bare-metal RISC-V RV32I target.

Since this project does not use a standard C library (libc) or an Operating System, the build system is highly customized to carefully control memory placement and initialization.

## Build System Architecture

### Directory Structure
```text
MiniSoC_RV32I/
├── Makefile                # Top-level entry point
├── build/                  # Build artifacts directory
│   ├── sw/                 # Software build outputs
│   │   ├── firmware.elf    # Executable with debug symbols
│   │   ├── firmware.bin    # Raw binary format
│   │   ├── firmware.hex    # Intel HEX format
│   │   ├── firmware.mem    # Verilog memory format (for simulation)
│   │   ├── firmware.disasm # Disassembly listing
│   │   ├── firmware.map    # Linker map file
│   │   └── tests/          # Compiled test executables
│   └── sim/                # Simulation outputs
├── scripts/                # Build utilities
│   └── convert/
│       └── hex2mem.py      # Converts .hex to Verilog $readmemh format
└── sw/                     # Software source
    ├── include.sw.mk       # Software build definitions
    └── linker.ld           # Memory layout definition
```


### Build System Components
```text
┌─────────────────────────────────────┐
│ Top-Level Makefile 				  │
│ • Orchestrates the entire project	  │
│ • Includes sub-makefiles 			  │
│ • Defines global variables		  │
├─────────────────────────────────────┤
│ Software Makefile (include.sw.mk)	  │
│ • Compiler toolchain configuration  │
│ • C/Assembly compilation rules	  │
│ • Linking and binary conversion 	  │
├─────────────────────────────────────┤
│ Hardware Makefile (include.*.mk)	  │
│ • RTL simulation rules 			  │
│ • Synthesis rules 				  │
└─────────────────────────────────────┘
```


## Toolchain Configuration

### Required Tools
| Tool 							| Purpose 			| Note 							|
|-------------------------------|-------------------|-------------------------------|
| `riscv32-unknown-elf-gcc` 	| C Compiler 		| Used with 32-bit flags 		|
| `riscv32-unknown-elf-as` 		| Assembler 		| Translates `startup.S` 		|
| `riscv32-unknown-elf-ld` 		| Linker 			| Maps code to IMEM/DMEM 		|
| `riscv32-unknown-elf-objcopy` | Binary conversion | Generates `.bin` and `.hex`	|
| `riscv32-unknown-elf-objdump` | Disassembly 		| Generates `.disam`			|
| `make` 						| Build automation 	| Version 3.81+ 				|
| `python3` 					| Script execution 	| For `hex2mem.py` 				|

*Note: On modern Linux distributions (like Ubuntu), the `gcc-riscv64-unknown-elf` package is used for both 64-bit and 32-bit compilation. The architecture is enforced via compiler flags.*

### Core Compiler Flags (`sw/include.sw.mk`)
```bash
# Force 32-bit Integer architecture (no floats, no hardware multiply/divide)
ARCH_FLAGS := -march=rv32i -mabi=ilp32

# Bare-Metal safety flags
CFLAGS := $(ARCH_FLAGS) -Os -Wall -Wextra -ffreestanding -nostartfiles
```

- `-Os`: Optimize for size (critical to fit inside the 32KB IMEM).
- `-ffreestanding`: Instructs the compiler that the standard library may not exist, and program startup may not necessarily be at `main()`.
- `-nostartfiles`: Prevents the compiler from linking its default startup code, as we provide our own `startup.S`.


## Build Targets

### Command
```bash
# Build everything (firmware + tests)
make sw.all

# Build only the main application firmware
make sw.firmware

# Build standalone test executables
make sw.test

# Clean all software build artifacts
make sw.clean

# Print the build configuration and discovered source files
make sw.info
```


## Build Process Details

### Step 1: Compilation
```text
Source files (.c, .S)
     ↓ (Compiler: riscv32-unknown-elf-gcc)
     ↓ Flags: -march=rv32i -mabi=ilp32 -Os -Wall
Object files (.o) located in build/sw/
```

### Step 2: Linking
```text
Object files (.o) + linker.ld
     ↓ (Linker: riscv32-unknown-elf-ld)
     ↓ Flags: -T linker.ld -nostdlib -static
ELF executable (firmware.elf)
```

*Note: We pass `-Wl,--gc-sections` to allow the linker to perform "Garbage Collection" on unused functions, significantly reducing the final binary size.*

### Step 3: Binary Format Conversion
```text
ELF executable (firmware.elf)
     ↓ (Objcopy: riscv32-unknown-elf-objcopy)
     ↓ Format: binary, hex, etc.
Output files (.bin, .hex, .mem)
```


### Step 4: Verilog Memory Initialization Generation
```text
Intel HEX file (firmware.hex)
     ↓ (Python script: hex2mem.py)
Verilog memory file (firmware.mem)
```

*The `.mem` file is formatted specifically for the Verilog `$readmemh` system task, allowing the hardware simulator (e.g., Icarus Verilog) to load the software into the simulated ROM instantly.*


## Build Output Files

### Generated Files in `build/sw/`

| File 				| Format 		| Purpose 																								|
|-------------------|---------------|-------------------------------------------------------------------------------------------------------|
| `firmware.elf` 	| Executable	| Contains machine code + debug symbols. Used by `objdump` and `size`. 									|
| `firmware.bin` 	| Raw Binary	| Pure machine code. Useful for real hardware bootloaders.												|
| `firmware.hex` 	| Intel HEX 	| Standardized ASCII representation of the binary. 														|
| `firmware.mem` 	| Text (Hex)	| Read by the Verilog testbench  to initialize IMEM.													|
| `firmware.disam` 	| Text (ASM)	| Human-readable assembly code. Highly recommended for debugging hardware/software integration issues.	|
| `firmware.map` 	| Text 			| Linker map showing exact memory addresses of every function and variable.								|


### Memory Usage Report
When running `make sw.firmware`, the build system automatically calls size to report memory consumption::

```text
[SW] Linking firmware: build/sw/firmware.elf
   text    data     bss     dec     hex filename
   1856     256     128    2240     8c0 build/sw/firmware.elf
```

- **text**: Executable instructions and constants (Stored in IMEM).
- **data**: Variables with initial values (Stored in IMEM, copied to DMEM at boot).
- **bss**:  Variables initialized to zero (Allocated in DMEM).


## Troubleshooting

### Issue: "Command not found: riscv32-unknown-elf-gcc"
**Cause**: Your CROSS`_COMPILE variable doesn't match your installed toolchain, or it is not in your PATH.
**Solution**: Edit `sw/include.sw.mk` or pass the variable via the command line:

```bash
make sw.firmware CROSS_COMPILE=riscv64-unknown-elf-
```

### Issue: "Error: selected processor does not support `mul`"
**Cause**: You used the standard `*` multiplication operator in C, but the RV32I architecture lacks the Hardware Multiplier (`M` extension).
**Solution**: Do not use `*`, `/`, or `%` for variables. Instead, include math.h and use the software implementations:
```c
// Incorrect
uint32_t result = a * b;

// Correct
uint32_t result = system_umul32(a, b);

```

### Issue: "undefined reference to `_estack` or `_sdata`"
**Cause**: Your `startup.S` assembly code is referencing symbols that do not exist in your `linker.ld` file.
**Solution**: Check `sw/linker.ld` and ensure the stack and data boundary markers exactly match the names expected by `startup.S`.


### Issue: "section `.text` will not fit in region `IMEM`"
**Cause**: Your compiled code is larger than the available 32KB Instruction Memory.
**Solution**:
1. Ensure `CFLAGS` includes `-Os` (Optimize for Size).
2. Remove large lookup tables or unused global arrays.
3. Check `firmware.map` to identify which functions are consuming the most space.
