# sim/top/firmware_program/firmware.S
# Simple RISC-V RV32I firmware for MiniSoC testbench
# Uses only base instruction set (no M extension)

    .section .init
    .globl _start
    .globl _estack

# Memory-mapped peripheral addresses
.equ UART_BASE,         0x20000000
.equ UART_TX_DATA,      (UART_BASE + 0x00)
.equ UART_BAUD_DIV,     (UART_BASE + 0x08)
.equ UART_CTRL,         (UART_BASE + 0x0C)
.equ UART_STATUS,       (UART_BASE + 0x10)


.equ TIMER_BASE,        0x30000000
.equ TIMER_COUNT,       (TIMER_BASE + 0x00)
.equ TIMER_CMP,         (TIMER_BASE + 0x04)
.equ TIMER_CTRL,        (TIMER_BASE + 0x08)
.equ TIMER_STATUS,      (TIMER_BASE + 0x0C)

.equ GPIO_BASE,         0x40000000
.equ GPIO_DATA,         (GPIO_BASE + 0x00)
.equ GPIO_DIR,          (GPIO_BASE + 0x04)


.equ SIM_CTRL_BASE,     0x50000000  # Simulation control

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
    beq     t1, t2, data_done

data_loop:
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    blt     t1, t2, data_loop

data_done:
    call main_loop
    

main_loop:
    # Initialize GPIO - set all as output
    li t0, GPIO_BASE
    li t1, 0xFF
    sw t1, 4(t0)        # GPIO_DIR
    
    # Initialize UART - enable TX
    li t0, UART_BASE
    li t1, 0x1
    sw t1, 12(t0)       # UART_CTRL
    
    # Send boot message via UART
    jal uart_send_boot_msg
    
    # Main test loop
    li s0, 0            # Counter
    li s1, GPIO_BASE    # GPIO base
    li s2, UART_BASE    # UART base


    # Update GPIO with counter value
    sw s0, 0(s1)        # Write to GPIO_DATA
    
    # Send counter via UART every 16 iterations
    andi t0, s0, 0x0F
    bnez t0, skip_uart
    
    # Send counter value via UART
    mv a0, s0
    jal uart_send_hex
    
skip_uart:
    # Increment counter
    addi s0, s0, 1
    
    # Simple delay
    li t0, 1000
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop
    
    # Check for test completion (after some iterations)
    li t0, 100
    blt s0, t0, main_loop
    
    # Tests completed - signal success
    li t0, SIM_CTRL_BASE
    li t1, 0x1234ABCD   # TEST_PASS_CODE
    sw t1, 0(t0)
    
    # Loop forever
    j .

# Send boot message
uart_send_boot_msg:
    addi sp, sp, -8
    sw ra, 0(sp)
    
    la a0, boot_msg
    jal uart_send_string
    
    lw ra, 0(sp)
    addi sp, sp, 8
    ret

# Send string (a0 = string pointer)
uart_send_string:
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    
    mv s0, a0           # String pointer
    li s1, UART_BASE    # UART base
    
uart_string_loop:
    lbu a0, 0(s0)       # Load character
    beqz a0, uart_string_done
    
    jal uart_send_char
    addi s0, s0, 1
    j uart_string_loop
    
uart_string_done:
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    addi sp, sp, 12
    ret

# Send character (a0 = character)
uart_send_char:
    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)
    
    li t0, UART_BASE
    
uart_wait_tx:
    lw t1, 16(t0)       # UART_STATUS
    andi t1, t1, 0x1    # Check TX_READY bit
    beqz t1, uart_wait_tx
    
    sb a0, 0(t0)        # UART_TX_DATA
    
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    ret

# Send hex number (a0 = number)
uart_send_hex:
    addi sp, sp, -20
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    
    mv s0, a0           # Number
    li s1, 8            # 8 hex digits
    li s2, 28           # Initial shift
    li s3, UART_BASE    # UART base
    
hex_loop:
    srl a0, s0, s2      # Get digit
    andi a0, a0, 0xF
    
    # Convert to ASCII
    li t0, 9
    bleu a0, t0, hex_digit
    addi a0, a0, 55     # A-F
    j hex_send
hex_digit:
    addi a0, a0, 48     # 0-9
hex_send:
    jal uart_send_char
    
    addi s2, s2, -4
    bgez s2, hex_loop
    
    # Send newline
    li a0, '\r'
    jal uart_send_char
    li a0, '\n'
    jal uart_send_char
    
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    addi sp, sp, 20
    ret

.section .data
boot_msg: .string "MiniSoC Test Running...\r\n"

.section .bss
    .space 256