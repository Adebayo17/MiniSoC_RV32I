# sim/top/firmware_program/firmware.S
# Simple RISC-V RV32I firmware for MiniSoC testbench
# Includes timer test functionality

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

# TIMER Definitions
.equ TIMER_BASE,        0x30000000
.equ TIMER_COUNT_OFF,   0x00        # Read-only counter
.equ TIMER_CMP_OFF,     0x04        # Compare value
.equ TIMER_CTRL_OFF,    0x08        # Control register
.equ TIMER_STATUS_OFF,  0x0C        # Status register

# Timer Control Bits
.equ TIMER_ENABLE,      (1 << 0)    # Enable timer
.equ TIMER_RESET,       (1 << 1)    # Reset counter
.equ TIMER_ONESHOT,     (1 << 2)    # One-shot mode
# Prescaler bits [3:4] - 00=/1, 01=/8, 10=/64, 11=/1024
.equ TIMER_PRESCALE_0,  (1 << 3)
.equ TIMER_PRESCALE_1,  (1 << 4)

# Timer Status Bits
.equ TIMER_MATCH,       (1 << 0)    # Compare match occurred
.equ TIMER_OVERFLOW,    (1 << 1)    # Counter overflow occurred

# GPIO Definitions
.equ GPIO_BASE,         0x40000000
.equ GPIO_DATA_OFF,     0x00        # Data Register
.equ GPIO_DIR_OFF,      0x04        # Direction Register

# Simulation Control
.equ SIM_CTRL_BASE,     0x50000000  
.equ SIM_CTRL_EXIT,     0x00

# Constants
.equ TEST_PASS_CODE,    0x1234ABCD
.equ MAX_CYCLES,        100
.equ TIMER_CMP_VALUE,   1000        # Compare value for timer test
.equ TIMER_PRESCALE_VAL, (0b11 << 3) # Prescaler = /1024

_start:
    # Initialize stack pointer
    la      sp, _estack

    # Initialize .bss section to zero
    la      t0, _sbss
    la      t1, _ebss
    beq     t0, t1, bss_done

bss_loop:
    sw      zero, 0(t0)
    addi    t0, t0, 4
    blt     t0, t1, bss_loop

bss_done:

    # Copy .data section from LMA to VMA
    la      t0, _sidata
    la      t1, _sdata
    la      t2, _edata
    beq     t1, t2, main_entry

data_loop:
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    blt     t1, t2, data_loop

main_entry:
    # === 1. Initialization === 
    # Initialize GPIO - set all as output
    li      t0, GPIO_BASE
    li      t1, 0xFF
    sw      t1, GPIO_DIR_OFF(t0)

    # Initialize UART - set baud rate
    li      t0, UART_BASE
    li      t1, 868          # Divisor for 115200 @ 100MHz
    sw      t1, UART_BAUD_OFF(t0)

    # Enable UART TX
    li      t1, 0x1
    sw      t1, UART_CTRL_OFF(t0)

    # Send boot message via UART
    jal     uart_send_boot_msg

    # Send timer initialization message
    la      a0, timer_init_msg
    jal     uart_send_string

    # === 2. Timer Test ===
    # Test Timer - configure and start
    jal     test_timer

    # === 3. Main Test Loop ===
    # Prepare registers for the main loop
    li      s0, 0            # Counter
    li      s1, GPIO_BASE    # GPIO base
    li      s2, MAX_CYCLES   # Limit
    li      s3, TIMER_BASE   # Timer base for monitoring

    # Start main loop with timer monitoring
main_loop:
    # Update GPIO with counter value
    sw      s0, GPIO_DATA_OFF(s1)
    
    # Check if we should send via UART (every 16 iterations)
    andi    t0, s0, 0x0F
    bnez    t0, skip_uart
    
    # Send counter value via UART
    mv      a0, s0
    jal     uart_send_hex
    
    # Also read and display timer value
    jal     display_timer_status
    
skip_uart:
    # Check timer status
    li      t0, TIMER_BASE
    addi    t1, t0, TIMER_STATUS_OFF   # Calculate TIMER_STATUS address
    lw      t2, 0(t1)                  # Load timer status
    andi    t3, t2, TIMER_MATCH        # Check match flag
    
    # If timer match occurred, toggle GPIO bit 7
    beqz    t3, no_timer_match
    li      t4, 0x80                   # GPIO bit 7
    sw      t4, GPIO_DATA_OFF(s1)      # Set bit 7 high
    j       clear_timer_status
    
no_timer_match:
    # Clear GPIO bit 7
    li      t4, 0x00
    sw      t4, GPIO_DATA_OFF(s1)
    
clear_timer_status:
    # Clear timer status by writing 1 to status bits
    li      t5, TIMER_MATCH | TIMER_OVERFLOW
    sw      t5, 0(t1)                  # Write to TIMER_STATUS
    
    # Increment counter
    addi    s0, s0, 1
    
    # Simple delay loop
    li      t0, 500
delay_loop:
    addi    t0, t0, -1
    bnez    t0, delay_loop
    
    # Check for test completion
    blt     s0, s2, main_loop
    
    # Tests completed - signal success
    li      t0, SIM_CTRL_BASE
    li      t1, TEST_PASS_CODE
    sw      t1, SIM_CTRL_EXIT(t0)
    
    # Loop forever
    j       .

# --------------------------------------------------
# Timer Test Subroutine
# --------------------------------------------------
test_timer:
    addi    sp, sp, -8
    sw      ra, 0(sp)
    
    # Send test start message
    la      a0, timer_test_start_msg
    jal     uart_send_string
    
    # Step 1: Reset timer
    li      t0, TIMER_BASE
    addi    t1, t0, TIMER_CTRL_OFF    # Calculate TIMER_CTRL address
    li      t2, TIMER_RESET
    sw      t2, 0(t1)                 # Write to TIMER_CTRL
    
    # Step 2: Set compare value
    addi    t3, t0, TIMER_CMP_OFF     # Calculate TIMER_CMP address
    li      t4, TIMER_CMP_VALUE
    sw      t4, 0(t3)                 # Write to TIMER_CMP
    
    # Step 3: Configure control register
    # Enable + Prescaler /1024 + Free-running mode
    li      t5, TIMER_ENABLE | TIMER_PRESCALE_VAL
    sw      t5, 0(t1)                 # Write to TIMER_CTRL
    
    # Step 4: Read back configuration
    la      a0, timer_config_msg
    jal     uart_send_string

    # Reload TIMER address
    li      t0, TIMER_BASE
    addi    t3, t0, TIMER_CMP_OFF
    
    # Read and display compare value
    lw      a0, 0(t3)                 # Read from TIMER_CMP
    jal     uart_send_hex
    
    la      a0, newline
    jal     uart_send_string

    # Reload TIMER address
    li      t0, TIMER_BASE
    addi    t1, t0, TIMER_CTRL_OFF
    
    # Read and display control register
    lw      a0, 0(t1)                 # Read from TIMER_CTRL
    jal     uart_send_hex
    
    la      a0, newline
    jal     uart_send_string
    
    # Send test completion message
    la      a0, timer_test_done_msg
    jal     uart_send_string
    
    lw      ra, 0(sp)
    addi    sp, sp, 8
    ret

# --------------------------------------------------
# Display Timer Status Subroutine
# --------------------------------------------------
display_timer_status:
    addi    sp, sp, -16
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    sw      s2, 12(sp)
    
    li      s0, TIMER_BASE
    mv      s1, s0                    # Save base
    
    # Send timer status prefix
    la      a0, timer_status_msg
    jal     uart_send_string
    
    # Read and display counter value
    addi    s2, s0, TIMER_COUNT_OFF   # Calculate TIMER_COUNT address
    lw      a0, 0(s2)                 # Read timer count
    jal     uart_send_hex
    
    la      a0, space
    jal     uart_send_string
    
    # Read and display status register
    addi    s2, s0, TIMER_STATUS_OFF  # Calculate TIMER_STATUS address
    lw      a0, 0(s2)                 # Read timer status
    jal     uart_send_hex
    
    la      a0, newline
    jal     uart_send_string
    
    lw      ra, 0(sp)
    lw      s0, 4(sp)
    lw      s1, 8(sp)
    lw      s2, 12(sp)
    addi    sp, sp, 16
    ret

# --------------------------------------------------
# Existing UART Subroutines (unchanged)
# --------------------------------------------------
uart_send_boot_msg:
    addi    sp, sp, -8
    sw      ra, 0(sp)
    la      a0, boot_msg
    jal     uart_send_string
    lw      ra, 0(sp)
    addi    sp, sp, 8
    ret

uart_send_string:
    addi    sp, sp, -12
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    mv      s0, a0
uart_string_loop:
    lbu     a0, 0(s0)
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

uart_send_char:
    li      t0, UART_BASE
    addi    t1, t0, UART_STAT_OFF    # Calculate UART_STATUS address
uart_wait_tx:
    lw      t2, 0(t1)                # Load UART status
    andi    t3, t2, 0x1              # Check TX_READY bit
    beqz    t3, uart_wait_tx
    addi    t4, t0, UART_TX_OFF      # Calculate UART_TX address
    sb      a0, 0(t4)                # Send character
    ret

uart_send_hex:
    addi    sp, sp, -20
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    sw      s2, 12(sp)
    sw      s3, 16(sp)
    mv      s0, a0
    li      s2, 28
hex_loop:
    srl     a0, s0, s2
    andi    a0, a0, 0xF
    li      t0, 9
    bleu    a0, t0, hex_digit
    addi    a0, a0, 55               # 'A'-'F'
    j       hex_send
hex_digit:
    addi    a0, a0, 48               # '0'-'9'
hex_send:
    jal     uart_send_char
    addi    s2, s2, -4
    bgez    s2, hex_loop
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

# --------------------------------------------------
# Data Section
# --------------------------------------------------
.section .data
boot_msg:               .string "MiniSoC Timer Test...\r\n"
timer_init_msg:         .string "Initializing Timer...\r\n"
timer_test_start_msg:   .string "Starting Timer Test...\r\n"
timer_config_msg:       .string "Timer Config - CMP: 0x"
timer_status_msg:       .string "Timer - Count: 0x"
timer_test_done_msg:    .string "Timer Test Complete!\r\n"
newline:                .string "\r\n"
space:                  .string " "

.section .bss
    .space 256