# Mini RV32I SoC - Software Documentation

## Overview
This directory contains documentation for the Mini RV32I SoC software stack.

## Quick Navigation
- **[Architecture](architecture/overview.md)** - Software architecture and design
- **[API Reference](api_reference/system_api.md)** - Function documentation
- **[Build System](build_system/makefile.md)** - Compilation and building
- **[Memory Map](memory_map/overview.md)** - Memory layout and addresses  
- **[Error Handling](errors/error_codes.md)** - Error codes and handling
- **[Linker Script](linker/script_explanation.md)** - Memory layout and linking
- **[Diagrams](diagrams/)** - Visual documentation
- **[Tutorials](tutorials/getting_started.md)** - Step-by-step guides

## Getting Started
1. Read the [Getting Started](tutorials/getting_started.md) guide
2. Check the [Memory Map](memory_map/overview.md) for addresses
3. Look at [API Examples](api_reference/examples/) for code samples

## Building the Software
```bash
# Navigate to project root
cd MiniSoC_RV32I

# Build firmware
make sw.firmware

# Run tests
make sw.test