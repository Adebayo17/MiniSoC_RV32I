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

_start:
    # Initialize stack pointer
    li sp, 0x10000FFC
    
    # Initialize GPIO - set all as output
    li t0, GPIO_BASE
    li t1, 0xFF
    sw t1, 4(t0)        # GPIO_DIR
    
    # Initialize UART - enable TX
    li t0, UART_BASE
    li t1, 0x1
    sw t1, 12(t0)       # UART_CTRL
    
    # Main loop - simple GPIO toggle
    li s0, 0            # Counter
    li s1, GPIO_BASE    # GPIO base
    
main_loop:
    # Write counter to GPIO
    sw s0, 0(s1)        # GPIO_DATA
    
    # Increment counter
    addi s0, s0, 1
    
    # Simple delay
    li t0, 1000
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop
    
    # Loop forever
    j main_loop