#!/usr/bin/env python3
"""
Convert Intel HEX format to Verilog $readmemh format
Handles address gaps by padding with zeros.
"""

import sys

def hex2mem(hex_file, mem_file):
    try:
        with open(hex_file, 'r') as hf, open(mem_file, 'w') as mf:
            current_addr = 0
            # Offset de base (si la flash commence à 0x00000000)
            base_addr = 0 
            
            for line in hf:
                line = line.strip()
                if not line.startswith(':'):
                    continue
                    
                # Parse Intel HEX record
                byte_count = int(line[1:3], 16)
                addr_offset = int(line[3:7], 16)
                record_type = int(line[7:9], 16)
                
                # Extended Linear Address Record (Type 04) - Gère les adresses > 64KB
                if record_type == 4:
                    base_addr = int(line[9:13], 16) << 16
                    continue

                # Data Record (Type 00)
                if record_type == 0:
                    abs_addr = base_addr + addr_offset
                    
                    # Détection d'un saut d'adresse (Gap)
                    # Si l'adresse du record est plus loin que notre curseur actuel, on remplit
                    if abs_addr > current_addr:
                        # Calcul du nombre de mots de 32 bits manquant
                        gap = abs_addr - current_addr
                        # On aligne sur 4 octets
                        n_words = gap // 4
                        for _ in range(n_words):
                            mf.write("00000000\n") # Padding
                        current_addr += n_words * 4
                    
                    data = line[9:9 + byte_count * 2]
                    
                    # Conversion Little Endian vers mots 32 bits
                    # On assume que les records sont alignés ou complets
                    for i in range(0, len(data), 8):
                        if i + 8 <= len(data):
                            word_bytes = data[i:i+8]
                            # Swap pour RISC-V (Little Endian -> Verilog Word)
                            # Hex string: "AABBCCDD" -> Byte0=AA, Byte1=BB... 
                            # Mem file wants: DDCCBBAA (MSB first in Verilog hex)
                            word_le = ''.join([word_bytes[j:j+2] for j in range(6, -1, -2)])
                            mf.write(word_le + '\n')
                            current_addr += 4

        print(f"Success: Converted {hex_file} to {mem_file}")
        
    except Exception as e:
        print(f"Error converting hex2mem: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 hex2mem.py <input.hex> <output.mem>")
        sys.exit(1)
    
    hex2mem(sys.argv[1], sys.argv[2])