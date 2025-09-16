# MiniSoC_RV32I

A minimalist System-on-Chip (SoC) built around a custom RV32I RISC-V core, using the **Wishbone bus** as the interconnect.  
The project is focused on **learning and experimentation** in VLSI/ASIC/FPGA design, keeping the design simple and modular.

---

## 🚀 Project Goals
- Implement a simple RV32I CPU core (no interrupts, no MMU, no caches).
- Integrate basic peripherals: **UART, Timer, GPIO**.
- Use **Wishbone** as the interconnect fabric.
- Provide software toolchain integration with a linker script and test programs.
- Allow simulation, synthesis, and FPGA prototyping.

---

## 📂 Repository Structure
```text
├── build                               # Build folder
├── docs                                # Documentation folder
├── scripts                             # Utils scripts (setup)
├── sim                                 # Simulation Environment + Testbenches
├── src                                 # RTL Source Code (Verilog)
│   ├── bus
│   ├── common
│   ├── cpu
│   ├── mem
│   ├── pad
│   ├── peripheral
│   └── top
├── sw                                  # Software (C/ASM programs, linker script)
└── synth                               # Synthesis and FPGA Build
```


---

## 🧩 Memory Map
| Region       | Base Address | Size   | Notes                       |
|--------------|--------------|--------|-----------------------------|
| IMEM         | `0x0000_0000`| 4 KB   | Instruction memory          |
| DMEM         | `0x1000_0000`| 4 KB   | Data memory                 |
| UART         | `0x2000_0000`| 4 KB   | UART registers              |
| TIMER        | `0x3000_0000`| 4 KB   | Timer registers             |
| GPIO         | `0x4000_0000`| 4 KB   | General-purpose I/O         |

---

## 🛠️ Tools & Dependencies
- **Icarus Verilog**        – Simulation
- **GTKWave**               – Waveform visualization
- **Yosys** + **nextpnr**   – Synthesis and FPGA mapping
- **RISC-V GCC toolchain**  – Compile test programs

A setup script is provided:
```bash
make check_env
```

---

## 📖 References
- [RISC-V Spec](https://riscv.org/specifications/ratified/)
- [Wishbone b4](https://cdn.opencores.org/downloads/wbspec_b4.pdf)
