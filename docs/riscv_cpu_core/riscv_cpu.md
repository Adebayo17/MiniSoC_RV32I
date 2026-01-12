# 1. Core Architecture Overview

![RISC-V CPU Architecture](../diagrams/cpu_architecture.png)

# 2. File structure

```text
src/cpu/
├── rv32i_core.v          - Top level CPU module
├── fetch_stage.v         - Instruction fetch
├── decode_stage.v        - Instruction decode
├── execute_stage.v       - Execution unit
├── mem_stage.v           - Memory access
├── wb_stage.v            - Writeback
├── regfile.v             - Register file
├── csr.v                 - Control/status registers
└── alu.v                 - Arithmetic logic unit
```

<!--- https://msyksphinz-self.github.io/riscv-isadoc/ >
