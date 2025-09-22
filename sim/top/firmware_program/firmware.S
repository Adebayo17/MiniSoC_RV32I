# sim/top/firmware_program/firmware.S
# Simple RISC-V RV32I firmware for MiniSoC testbench
# Uses only base instruction set (no M extension)

.section .text
.global _start

# Memory-mapped peripheral addresses
.equ UART_BASE,      0x20000000
.equ UART_TX_DATA,   (UART_BASE + 0x00)
.equ UART_STATUS,    (UART_BASE + 0x10)
.equ UART_CTRL,      (UART_BASE + 0x0C)

.equ GPIO_BASE,      0x40000000
.equ GPIO_DATA,      (GPIO_BASE + 0x00)
.equ GPIO_DIR,       (GPIO_BASE + 0x04)

.equ TIMER_BASE,     0x30000000
.equ TIMER_COUNT,    (TIMER_BASE + 0x00)

_start:
    # Initialize stack pointer (end of DMEM)
    li sp, 0x10001000
    
    # Initialize peripherals
    jal init_uart
    jal init_gpio
    
    # Send boot message
    la a0, boot_msg
    jal uart_puts
    
    # Main loop
main_loop:
    # Increment counter (simple version without multiplication)
    la t0, counter
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    
    # Display counter on GPIO (lower 8 bits)
    li t2, GPIO_DATA
    sb t1, 0(t2)         # Store only byte to GPIO
    
    # Send counter value via UART (simplified)
    la a0, count_msg
    jal uart_puts
    
    # Send counter value as hex (simpler than decimal)
    la t0, counter
    lw a0, 0(t0)
    jal uart_puthex
    
    la a0, newline
    jal uart_puts
    
    # Simple delay loop
    li t0, 200000        # Reduced delay for faster simulation
delay:
    addi t0, t0, -1
    bnez t0, delay
    
    j main_loop

# Initialize UART
init_uart:
    # Enable TX (minimal configuration)
    li t0, UART_CTRL
    li t1, 0x1           # TX enable
    sw t1, 0(t0)
    ret

# Initialize GPIO
init_gpio:
    # Set all GPIO as output
    li t0, GPIO_DIR
    li t1, 0xFF          # All pins output
    sw t1, 0(t0)
    ret

# UART: Send string (a0 = string pointer)
uart_puts:
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s0, 4(sp)
    
    mv s0, a0            # Save string pointer
    
uart_puts_loop:
    lbu a0, 0(s0)        # Load character
    beqz a0, uart_puts_end  # Null terminator
    
    jal uart_putc        # Send character
    addi s0, s0, 1       # Next character
    j uart_puts_loop
    
uart_puts_end:
    lw ra, 0(sp)
    lw s0, 4(sp)
    addi sp, sp, 8
    ret

# UART: Send character (a0 = character)
uart_putc:
    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    
    # Wait for TX ready
    li t0, UART_STATUS
uart_tx_wait:
    lw t1, 0(t0)
    andi t1, t1, 0x1     # Check TX_READY bit
    beqz t1, uart_tx_wait
    
    # Send character
    li t0, UART_TX_DATA
    sb a0, 0(t0)
    
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    ret

# UART: Send number as hex (a0 = number) - RV32I compatible
uart_puthex:
    addi sp, sp, -20
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    
    mv s0, a0            # Save number
    li s1, 8             # 8 hex digits for 32-bit number
    li s2, 28            # Initial shift amount (28 bits for first digit)
    li s3, 0             # Digit counter
    
uart_hex_loop:
    # Extract 4-bit hex digit
    srl a0, s0, s2       # Shift right to get digit in position
    andi a0, a0, 0xF     # Mask to 4 bits
    
    # Convert to ASCII
    li t0, 9
    bleu a0, t0, uart_hex_digit  # If 0-9, jump to digit conversion
    addi a0, a0, 55      # Convert 10-15 to 'A'-'F' (55 = 'A' - 10)
    j uart_hex_send
    
uart_hex_digit:
    addi a0, a0, 48      # Convert 0-9 to '0'-'9'
    
uart_hex_send:
    jal uart_putc        # Send hex digit
    
    addi s3, s3, 1       # Increment digit count
    addi s2, s2, -4      # Decrement shift amount
    bgez s2, uart_hex_loop  # Continue until all digits sent
    
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    addi sp, sp, 20
    ret

# Simple counter display (shows counter as single digit 0-9)
uart_putdigit:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    andi a0, a0, 0xF     # Get lowest 4 bits (0-15)
    li t0, 9
    bleu a0, t0, uart_digit_ok
    li a0, 9             # Cap at 9 if larger
    
uart_digit_ok:
    addi a0, a0, 48      # Convert to ASCII '0'-'9'
    jal uart_putc
    
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# Data section
.section .data
counter:
    .word 0

boot_msg:
    .string "RV32I SoC Boot!\r\n"

count_msg:
    .string "Count: 0x"

newline:
    .string "\r\n"

# Stack space
.section .bss
    .space 128  # 128 bytes for stack