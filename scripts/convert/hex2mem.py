#!/usr/bin/env python3
"""
Convert Intel HEX format to Verilog $readmemh compatible format
"""

import sys

def hex2mem(hex_file, mem_file):
    """Convert Intel HEX file to Verilog mem format"""
    
    with open(hex_file, 'r') as hf, open(mem_file, 'w') as mf:
        for line in hf:
            line = line.strip()
            if not line.startswith(':'):
                continue
                
            # Parse Intel HEX record
            byte_count = int(line[1:3], 16)
            address = int(line[3:7], 16)
            record_type = int(line[7:9], 16)
            
            # Only process data records (type 00)
            if record_type == 0:
                data = line[9:9 + byte_count * 2]
                
                # Convert to 32-bit words (little-endian for RISC-V)
                for i in range(0, len(data), 8):
                    if i + 8 <= len(data):
                        # Extract 32-bit word (4 bytes)
                        word_bytes = data[i:i+8]
                        # Convert to little-endian for RISC-V
                        word_le = ''.join([word_bytes[j:j+2] for j in range(6, -1, -2)])
                        mf.write(word_le + '\n')
    
    print(f"Converted {hex_file} to {mem_file}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 hex2mem.py <input.hex> <output.mem>")
        sys.exit(1)
    
    hex2mem(sys.argv[1], sys.argv[2])