# sim/top/firmware_program/firmware.S
# Simple RISC-V RV32I firmware for MiniSoC testbench
# Uses only base instruction set (no M extension)

    .section .init
    .globl _start
    .globl _estack

# --------------------------------------------------
# Memory Map & Register Offsets
# --------------------------------------------------

# UART Definitions
.equ UART_BASE,         0x20000000
.equ UART_TX_OFF,       0x00        # Transmit Data
.equ UART_BAUD_OFF,     0x08        # Baud Rate Divisor
.equ UART_CTRL_OFF,     0x0C        # Control Register
.equ UART_STAT_OFF,     0x10        # Status Register
.equ UART_TX_DATA,      (UART_BASE + UART_TX_OFF)
.equ UART_BAUD_DIV,     (UART_BASE + UART_BAUD_OFF)
.equ UART_CTRL,         (UART_BASE + UART_CTRL_OFF)
.equ UART_STATUS,       (UART_BASE + UART_STAT_OFF)

# TIMER Definitions
.equ TIMER_BASE,        0x30000000
.equ TIMER_COUNT,       (TIMER_BASE + 0x00)
.equ TIMER_CMP,         (TIMER_BASE + 0x04)
.equ TIMER_CTRL,        (TIMER_BASE + 0x08)
.equ TIMER_STATUS,      (TIMER_BASE + 0x0C)

# GPIO Definitions
.equ GPIO_BASE,         0x40000000
.equ GPIO_DATA_OFF,     0x00        # Data Register
.equ GPIO_DIR_OFF,      0x04        # Direction Register
.equ GPIO_DATA,         (GPIO_BASE + GPIO_DATA_OFF)
.equ GPIO_DIR,          (GPIO_BASE + GPIO_DIR_OFF)


# Simulation Control
.equ SIM_CTRL_BASE,     0x50000000  
.equ SIM_CTRL_EXIT,     0x00

# Constants
.equ TEST_PASS_CODE,    0x1234ABCD
.equ MAX_CYCLES,        100

_start:
    # Initialize stack pointer
    la      sp, _estack

    /* --------------------------------------------------
     * Initialize .bss section to zero
     * -------------------------------------------------- */
    la      t0, _sbss               /* t0 = start of .bss */
    la      t1, _ebss               /* t1 = end of .bss */
    beq     t0, t1, bss_done        /* if no bss, skip */

bss_loop:
    sw      zero, 0(t0)             /* *t0 = 0 */
    addi    t0, t0, 4               /* next word */
    blt     t0, t1, bss_loop

bss_done:

    /* --------------------------------------------------
     * Copy .data section from LMA (IMEM) to VMA (DMEM)
     * -------------------------------------------------- */
    la      t0, _sidata             /* source (in IMEM image) */
    la      t1, _sdata              /* destination (in DMEM) */
    la      t2, _edata
    beq     t1, t2, main_entry

data_loop:
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    blt     t1, t2, data_loop


    /* --------------------------------------------------
     * Main Program Entry (One-time Init)
     * -------------------------------------------------- */
main_entry:
    # === 1. Initalization === 

    # Initialize GPIO - set all as output
    li t0, GPIO_BASE
    li t1, 0xFF
    sw t1, GPIO_DIR_OFF(t0)        # GPIO_DIR

    # Initialize UART - enable TX
    li t0, UART_BASE
    li t1, 0x1
    sw t1, UART_CTRL_OFF(t0)       # UART_CTRL

    # Send boot message via UART
    jal uart_send_boot_msg

    # Prepare registers for the main loop
    li s0, 0            # Counter
    li s1, GPIO_BASE    # GPIO base
    li s2, MAX_CYCLES   # Limit (moved to register for efficiency)


    /* --------------------------------------------------
     * Main Test Loop
     * -------------------------------------------------- */
main_loop:
    # Update GPIO with counter value
    sw      s0, GPIO_DATA_OFF(s1)
    
    # Check if we should send via UART (every 16 iterations)
    andi    t0, s0, 0x0F
    bnez    t0, skip_uart
    
    # Send counter value via UART
    mv      a0, s0
    jal     uart_send_hex
    
skip_uart:
    # Increment counter
    addi    s0, s0, 1
    
    # Simple delay loop
    li      t0, 1000
delay_loop:
    addi    t0, t0, -1
    bnez    t0, delay_loop
    
    # Check for test completion
    # If s0 < s2, jump back to main_loop
    blt     s0, s2, main_loop
    
    # Tests completed - signal success
    li      t0, SIM_CTRL_BASE
    li      t1, TEST_PASS_CODE
    sw      t1, SIM_CTRL_EXIT(t0)
    
    # Loop forever
    j       .


# --------------------------------------------------
# Subroutines
# --------------------------------------------------

# Send boot message
uart_send_boot_msg:
    addi    sp, sp, -8
    sw      ra, 0(sp)
    
    la      a0, boot_msg
    jal     uart_send_string
    
    lw      ra, 0(sp)
    addi    sp, sp, 8
    ret

# Send string (a0 = string pointer)
uart_send_string:
    addi    sp, sp, -12
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    
    mv      s0, a0           # String pointer

    
uart_string_loop:
    lbu     a0, 0(s0)       # Load character
    beqz    a0, uart_string_done
    
    jal     uart_send_char
    addi    s0, s0, 1
    j       uart_string_loop
    
uart_string_done:
    lw      ra, 0(sp)
    lw      s0, 4(sp)
    lw      s1, 8(sp)
    addi    sp, sp, 12
    ret

# Send character (a0 = character)
uart_send_char:
    li      t0, UART_BASE
    
uart_wait_tx:
    lw      t1, UART_STAT_OFF(t0)
    andi    t1, t1, 0x1         # Check TX_READY bit
    beqz    t1, uart_wait_tx
    
    sb      a0, UART_TX_OFF(t0)
    ret

# Send hex number (a0 = number)
uart_send_hex:
    addi    sp, sp, -20
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    sw      s2, 12(sp)
    sw      s3, 16(sp)
    
    mv      s0, a0              # Number to print
    li      s2, 28              # Initial shift amount
    
hex_loop:
    srl     a0, s0, s2          # Shift right
    andi    a0, a0, 0xF         # Mask last 4 bits
    
    # Convert to ASCII
    li      t0, 9
    bleu    a0, t0, hex_digit
    addi    a0, a0, 55          # 'A'-'F'
    j       hex_send
hex_digit:
    addi    a0, a0, 48          # '0'-'9'
hex_send:
    jal     uart_send_char
    
    addi    s2, s2, -4
    bgez    s2, hex_loop
    
    # Send newline (CR LF)
    li      a0, '\r'
    jal     uart_send_char
    li      a0, '\n'
    jal     uart_send_char
    
    lw      ra, 0(sp)
    lw      s0, 4(sp)
    lw      s1, 8(sp)
    lw      s2, 12(sp)
    lw      s3, 16(sp)
    addi    sp, sp, 20
    ret

.section .data
boot_msg: .string "MiniSoC Test Optimized...\r\n"

.section .bss
    .space 256