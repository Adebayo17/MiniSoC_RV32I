#!/usr/bin/env python3
"""
Generate Verilog Tracer and Symbols using 'nm' output
Usage: python3 gen_tracer.py <firmware.disasm> <firmware.sym> <output.v>
"""

import sys
import re
import os

def gen_tracer(disasm_file, sym_file, verilog_file):
    header_file = os.path.splitext(verilog_file)[0] + "_symbols.vh"
    
    print(f"Generating Tracer from {disasm_file}")
    print(f"Extracting Symbols from {sym_file}")

    # Regex pour le désassemblage (Instructions)
    re_instr = re.compile(r'^\s*([0-9a-fA-F]+):\s+[0-9a-fA-F]+\s+(.*)$')
    
    # Regex pour 'nm' (Symboles): "10000000 D _sdata" ou "0000001c t bss_loop"
    # Group 1: Address, Group 2: Type, Group 3: Name
    re_nm = re.compile(r'^\s*([0-9a-fA-F]+)\s+([a-zA-Z])\s+(.+)$')

    # Liste des mots clés locaux qu'on veut garder (même s'ils sont 't')
    KEEP_LOCALS = ["loop", "done", "hang", "start"]

    try:
        with open(disasm_file, 'r') as f_asm, \
             open(sym_file, 'r') as f_sym, \
             open(verilog_file, 'w') as f_v, \
             open(header_file, 'w') as f_h:
            
            # 1. Traitement des symboles (.sym)
            f_h.write("// Generated Firmware Symbols from nm\n")
            
            symbols_found = {}
            
            for line in f_sym:
                match = re_nm.match(line)
                if match:
                    addr = match.group(1)
                    type_char = match.group(2)
                    name = match.group(3).strip()
                    
                    # Logique de filtrage :
                    # 1. Garder les globaux (T, D, A, B)
                    # 2. Garder les symboles système (_)
                    # 3. Garder les boucles locales (loop, done)
                    is_global = type_char.upper() in ['T', 'D', 'A', 'B']
                    is_special = name.startswith("_") or "canary" in name
                    is_loop = any(k in name for k in KEEP_LOCALS)

                    if is_global or is_special or is_loop:
                        clean_name = re.sub(r'[^a-zA-Z0-9_]', '_', name).upper()
                        # Évite les doublons
                        if clean_name not in symbols_found:
                            f_h.write(f"localparam [31:0] SYM_{clean_name} = 32'h{addr};\n")
                            symbols_found[clean_name] = True

            # 2. Traitement des instructions (.disasm) - Reste inchangé
            f_v.write("/* Generated Verilog Tracer */\n")
            f_v.write("module firmware_tracer (input wire [31:0] pc, output reg [639:0] mnemonic);\n")
            f_v.write("    always @(pc) begin\n")
            f_v.write("        case (pc)\n")

            for line in f_asm:
                match = re_instr.match(line)
                if match:
                    addr = match.group(1)
                    instr = match.group(2).strip().replace('"', '\\"').replace('\\', '\\\\')
                    f_v.write(f'            32\'h{addr}: mnemonic = "{instr}";\n')

            f_v.write('            default: mnemonic = "UNKNOWN";\n')
            f_v.write("        endcase\n    end\nendmodule\n")

    except FileNotFoundError as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 gen_tracer.py <firmware.disasm> <firmware.sym> <output.v>")
        sys.exit(1)
    
    gen_tracer(sys.argv[1], sys.argv[2], sys.argv[3])