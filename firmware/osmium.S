.equ MMIO_BASE,        0xFE000000
.equ GPIO_BASE,        MMIO_BASE + 0x200000
.equ UART0_BASE,       MMIO_BASE + 0x201000

.equ GPFSEL1,          GPIO_BASE + 0x04
.equ GPPUPPDN0,        GPIO_BASE + 0xE4

.equ UART0_DR,         UART0_BASE + 0x00
.equ UART0_FR,         UART0_BASE + 0x18
.equ UART0_IBRD,       UART0_BASE + 0x24
.equ UART0_FBRD,       UART0_BASE + 0x28
.equ UART0_LCRH,       UART0_BASE + 0x2C
.equ UART0_CR,         UART0_BASE + 0x30
.equ UART0_IMSC,       UART0_BASE + 0x38
.equ UART0_ICR,        UART0_BASE + 0x44

.equ LINE_BUF_SIZE,    192
.equ PATH_BUF_SIZE,    64
.equ FILE_DATA_SIZE,   256
.equ NUM_BUF_SIZE,     32

.equ MAX_DIRS,         16
.equ MAX_FILES,        16

.equ DIR_SLOT_SIZE,    72
.equ DIR_USED_OFFSET,  0
.equ DIR_PATH_OFFSET,  8

.equ FILE_SLOT_SIZE,   328
.equ FILE_USED_OFFSET, 0
.equ FILE_PATH_OFFSET, 8
.equ FILE_DATA_OFFSET, 72

.section .text
.globl _start

_start:
    mrs x0, mpidr_el1
    and x0, x0, #0b11
    cbz x0, 1f
0:
    wfe
    b 0b

1:
    ldr x0, =__boot_stack_top
    mov sp, x0
    bl zero_bss
    bl uart_init
    bl timer_init
    bl fs_init
    bl banner
    bl shell_loop
    b halt

halt:
    wfe
    b halt

zero_bss:
    ldr x0, =__bss_start
    ldr x1, =__bss_end
0:
    cmp x0, x1
    b.hs 1f
    str xzr, [x0], #8
    b 0b
1:
    ret

uart_init:
    ldr x0, =UART0_CR
    str wzr, [x0]

    ldr x0, =GPFSEL1
    ldr w1, [x0]
    mov w2, #(7 << 12)
    bic w1, w1, w2
    mov w2, #(7 << 15)
    bic w1, w1, w2
    mov w2, #(4 << 12)
    orr w1, w1, w2
    mov w2, #(4 << 15)
    orr w1, w1, w2
    str w1, [x0]

    ldr x0, =GPPUPPDN0
    ldr w1, [x0]
    mov w2, #(3 << 28)
    bic w1, w1, w2
    mov w2, #(3 << 30)
    bic w1, w1, w2
    str w1, [x0]

    ldr x0, =UART0_ICR
    mov w1, #0x7ff
    str w1, [x0]

    ldr x0, =UART0_IBRD
    mov w1, #26
    str w1, [x0]

    ldr x0, =UART0_FBRD
    mov w1, #3
    str w1, [x0]

    ldr x0, =UART0_LCRH
    mov w1, #(1 << 4)
    orr w1, w1, #(1 << 5)
    orr w1, w1, #(1 << 6)
    str w1, [x0]

    ldr x0, =UART0_IMSC
    str wzr, [x0]

    ldr x0, =UART0_CR
    mov w1, #1
    orr w1, w1, #(1 << 8)
    orr w1, w1, #(1 << 9)
    str w1, [x0]
    ret

uart_putc:
    mov w1, w0
0:
    ldr x2, =UART0_FR
    ldr w3, [x2]
    tst w3, #(1 << 5)
    b.ne 0b
    ldr x2, =UART0_DR
    str w1, [x2]
    ret

uart_getc:
0:
    ldr x1, =UART0_FR
    ldr w2, [x1]
    tst w2, #(1 << 4)
    b.ne 0b
    ldr x1, =UART0_DR
    ldr w0, [x1]
    and w0, w0, #0xff
    ret

puts:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x2, x0
0:
    ldrb w0, [x2], #1
    cbz w0, 1f
    cmp w0, #10
    b.ne 2f
    mov w0, #13
    bl uart_putc
    mov w0, #10
    bl uart_putc
    b 0b
2:
    bl uart_putc
    b 0b
1:
    ldp x29, x30, [sp], #16
    ret

newline:
    mov w0, #13
    bl uart_putc
    mov w0, #10
    b uart_putc

puts_ln:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl puts
    bl newline
    ldp x29, x30, [sp], #16
    ret

read_line:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    mov x21, #0
0:
    bl uart_getc
    cmp w0, #13
    b.eq 4f
    cmp w0, #10
    b.eq 4f
    cmp w0, #8
    b.eq 2f
    cmp w0, #127
    b.eq 2f
    cmp w0, #32
    b.lo 0b
    cmp w0, #126
    b.hi 0b
    subs x22, x20, #1
    cmp x21, x22
    b.hs 0b
    strb w0, [x19, x21]
    add x21, x21, #1
    bl uart_putc
    b 0b
2:
    cbz x21, 0b
    sub x21, x21, #1
    mov w0, #8
    bl uart_putc
    mov w0, #' '
    bl uart_putc
    mov w0, #8
    bl uart_putc
    b 0b
4:
    strb wzr, [x19, x21]
    bl newline
    mov x0, x19
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret

skip_spaces:
0:
    ldrb w1, [x0]
    cmp w1, #' '
    b.eq 1f
    cmp w1, #9
    b.ne 2f
1:
    add x0, x0, #1
    b 0b
2:
    ret

trim_in_place:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    bl skip_spaces
    mov x19, x0
    bl string_length
    cbz x0, 2f
    add x20, x19, x0
1:
    cmp x20, x19
    b.eq 2f
    sub x20, x20, #1
    ldrb w1, [x20]
    cmp w1, #' '
    b.eq 3f
    cmp w1, #9
    b.eq 3f
    b 2f
3:
    strb wzr, [x20]
    b 1b
2:
    mov x0, x19
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

string_length:
    mov x1, x0
0:
    ldrb w2, [x1], #1
    cbz w2, 1f
    b 0b
1:
    sub x0, x1, x0
    sub x0, x0, #1
    ret

streq:
0:
    ldrb w2, [x0], #1
    ldrb w3, [x1], #1
    cmp w2, w3
    b.ne 1f
    cbnz w2, 0b
    mov x0, #1
    ret
1:
    mov x0, #0
    ret

startswith:
0:
    ldrb w2, [x1], #1
    cbz w2, 1f
    ldrb w3, [x0], #1
    cmp w2, w3
    b.ne 2f
    b 0b
1:
    mov x0, #1
    ret
2:
    mov x0, #0
    ret

match_prefix:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    mov x20, x1
0:
    ldrb w2, [x20], #1
    cbz w2, 1f
    ldrb w3, [x19], #1
    cmp w2, w3
    b.ne 2f
    b 0b
1:
    mov x0, x19
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
2:
    mov x0, #0
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

copy_string_bounded:
    mov x3, #0
0:
    cmp x3, x2
    b.hs 2f
    ldrb w4, [x1, x3]
    strb w4, [x0, x3]
    cbz w4, 1f
    add x3, x3, #1
    b 0b
1:
    mov x0, #0
    ret
2:
    sub x4, x2, #1
    strb wzr, [x0, x4]
    mov x0, #1
    ret

copy_prefix:
    mov x3, #0
0:
    cmp x3, x2
    b.hs 1f
    ldrb w4, [x1, x3]
    strb w4, [x0, x3]
    add x3, x3, #1
    b 0b
1:
    strb wzr, [x0, x2]
    ret

append_string_bounded:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    mov x20, x2
    bl string_length
    mov x3, x0
    cmp x3, x20
    b.hs 2f
    add x0, x19, x3
    sub x2, x20, x3
    bl copy_string_bounded
    b 1f
2:
    mov x0, #1
1:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

find_last_slash:
    mov x1, x0
    mov x2, #0
0:
    ldrb w3, [x1], #1
    cbz w3, 1f
    cmp w3, #'/'
    b.ne 0b
    sub x2, x1, #1
    b 0b
1:
    mov x0, x2
    ret

parent_path:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    bl find_last_slash
    cbz x0, 2f
    cmp x0, x19
    b.ne 1f
    mov w1, #'/'
    strb w1, [x20]
    strb wzr, [x20, #1]
    mov x0, #1
    b 3f
1:
    sub x2, x0, x19
    mov x0, x20
    mov x1, x19
    bl copy_prefix
    mov x0, #1
    b 3f
2:
    mov x0, #0
3:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

basename_copy:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    bl find_last_slash
    cbz x0, 1f
    add x1, x0, #1
    b 2f
1:
    mov x1, x19
2:
    mov x0, x20
    mov x2, #PATH_BUF_SIZE
    bl copy_string_bounded
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

resolve_path:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    bl skip_spaces
    mov x19, x0
    ldrb w0, [x19]
    cbz w0, 8f

    ldr x1, =dot_path
    mov x0, x19
    bl streq
    cbz x0, 0f
    ldr x1, =cwd_buf
    mov x0, x20
    mov x2, #PATH_BUF_SIZE
    bl copy_string_bounded
    mov x0, x20
    b 9f
0:
    ldr x1, =dotdot_path
    mov x0, x19
    bl streq
    cbz x0, 1f
    ldr x0, =cwd_buf
    mov x1, x20
    bl parent_path
    cbz x0, 8f
    mov x0, x20
    b 9f
1:
    ldrb w0, [x19]
    cmp w0, #'/'
    b.ne 2f
    mov x0, x20
    mov x1, x19
    mov x2, #PATH_BUF_SIZE
    bl copy_string_bounded
    cmp x0, #0
    b.ne 8f
    mov x0, x20
    b 9f
2:
    ldr x1, =cwd_buf
    mov x0, x20
    mov x2, #PATH_BUF_SIZE
    bl copy_string_bounded
    cmp x0, #0
    b.ne 8f
    ldr x0, =cwd_buf
    ldr x1, =root_path
    bl streq
    cbnz x0, 4f
    ldr x0, =slash_text
    mov x1, x20
    mov x2, #PATH_BUF_SIZE
    bl append_string_bounded
    cmp x0, #0
    b.ne 8f
4:
    mov x0, x20
    mov x1, x19
    mov x2, #PATH_BUF_SIZE
    bl append_string_bounded
    cmp x0, #0
    b.ne 8f
    mov x0, x20
    b 9f
8:
    mov x0, #0
9:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret

dir_exists:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    ldr x1, =root_path
    bl streq
    cbz x0, 0f
    mov x0, #1
    b 3f
0:
    ldr x20, =dir_entries
    mov x2, #MAX_DIRS
1:
    cbz x2, 2f
    ldr x3, [x20, #DIR_USED_OFFSET]
    cbz x3, 4f
    add x1, x20, #DIR_PATH_OFFSET
    mov x0, x19
    bl streq
    cbnz x0, 3f
4:
    add x20, x20, #DIR_SLOT_SIZE
    subs x2, x2, #1
    b.ne 1b
2:
    mov x0, #0
3:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

file_find:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    ldr x20, =file_entries
    mov x2, #MAX_FILES
0:
    cbz x2, 2f
    ldr x3, [x20, #FILE_USED_OFFSET]
    cbz x3, 1f
    add x1, x20, #FILE_PATH_OFFSET
    mov x0, x19
    bl streq
    cbnz x0, 3f
1:
    add x20, x20, #FILE_SLOT_SIZE
    subs x2, x2, #1
    b.ne 0b
2:
    mov x0, #0
    b 4f
3:
    mov x0, x20
4:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

file_exists:
    bl file_find
    cmp x0, #0
    cset x0, ne
    ret

fs_mkdir:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    mov x19, x0
    ldr x1, =root_path
    bl streq
    cbz x0, 0f
    mov x0, #4
    b 8f
0:
    mov x0, x19
    bl dir_exists
    cbz x0, 1f
    mov x0, #1
    b 8f
1:
    mov x0, x19
    bl file_exists
    cbz x0, 2f
    mov x0, #1
    b 8f
2:
    mov x0, x19
    ldr x1, =temp_parent_buf
    bl parent_path
    cbnz x0, 3f
    mov x0, #4
    b 8f
3:
    ldr x0, =temp_parent_buf
    bl dir_exists
    cbnz x0, 4f
    mov x0, #2
    b 8f
4:
    ldr x20, =dir_entries
    mov x21, #MAX_DIRS
5:
    cbz x21, 7f
    ldr x22, [x20, #DIR_USED_OFFSET]
    cbz x22, 6f
    add x20, x20, #DIR_SLOT_SIZE
    subs x21, x21, #1
    b.ne 5b
7:
    mov x0, #3
    b 8f
6:
    mov x0, #1
    str x0, [x20, #DIR_USED_OFFSET]
    add x0, x20, #DIR_PATH_OFFSET
    mov x1, x19
    mov x2, #PATH_BUF_SIZE
    bl copy_string_bounded
    cmp x0, #0
    cset x0, ne
8:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret

fs_write_file:
    stp x29, x30, [sp, #-64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    mov x0, x19
    bl dir_exists
    cbz x0, 0f
    mov x0, #1
    b 9f
0:
    mov x0, x19
    ldr x1, =temp_parent_buf
    bl parent_path
    cbnz x0, 1f
    mov x0, #4
    b 9f
1:
    ldr x0, =temp_parent_buf
    bl dir_exists
    cbnz x0, 2f
    mov x0, #2
    b 9f
2:
    mov x0, x19
    bl file_find
    cbz x0, 4f
    add x0, x0, #FILE_DATA_OFFSET
    mov x1, x20
    mov x2, #FILE_DATA_SIZE
    bl copy_string_bounded
    cmp x0, #0
    cset x0, ne
    b 9f
4:
    ldr x21, =file_entries
    mov x22, #MAX_FILES
5:
    cbz x22, 8f
    ldr x23, [x21, #FILE_USED_OFFSET]
    cbz x23, 6f
    add x21, x21, #FILE_SLOT_SIZE
    subs x22, x22, #1
    b.ne 5b
8:
    mov x0, #3
    b 9f
6:
    mov x24, #1
    str x24, [x21, #FILE_USED_OFFSET]
    add x0, x21, #FILE_PATH_OFFSET
    mov x1, x19
    mov x2, #PATH_BUF_SIZE
    bl copy_string_bounded
    cmp x0, #0
    b.ne 7f
    add x0, x21, #FILE_DATA_OFFSET
    mov x1, x20
    mov x2, #FILE_DATA_SIZE
    bl copy_string_bounded
    cmp x0, #0
    cset x0, ne
    b 9f
7:
    mov x0, #4
9:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x29, x30, [sp], #64
    ret

fs_touch:
    ldr x1, =empty_text
    b fs_write_file

fs_read_file:
    bl file_find
    cbz x0, 0f
    add x0, x0, #FILE_DATA_OFFSET
    ret
0:
    mov x0, #0
    ret

fs_init:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    ldr x0, =seed_dir_bin
    bl fs_mkdir
    ldr x0, =seed_dir_etc
    bl fs_mkdir
    ldr x0, =seed_dir_home
    bl fs_mkdir
    ldr x0, =seed_dir_tmp
    bl fs_mkdir

    ldr x0, =seed_file_motd_path
    ldr x1, =seed_file_motd_data
    bl fs_write_file
    ldr x0, =seed_file_weather_path
    ldr x1, =seed_file_weather_data
    bl fs_write_file
    ldr x0, =seed_file_readme_path
    ldr x1, =seed_file_readme_data
    bl fs_write_file

    ldr x0, =cwd_buf
    ldr x1, =root_path
    mov x2, #PATH_BUF_SIZE
    bl copy_string_bounded
    ldp x29, x30, [sp], #16
    ret

timer_init:
    mrs x0, cntpct_el0
    ldr x1, =timer_start
    str x0, [x1]
    mrs x0, cntfrq_el0
    ldr x1, =timer_freq
    str x0, [x1]
    ret

uptime_seconds:
    mrs x0, cntpct_el0
    ldr x1, =timer_start
    ldr x1, [x1]
    sub x0, x0, x1
    ldr x1, =timer_freq
    ldr x1, [x1]
    cbnz x1, 0f
    mov x1, #1
0:
    udiv x0, x0, x1
    ret

unix_seconds:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl uptime_seconds
    ldr x1, =unix_offset
    ldr x1, [x1]
    add x0, x0, x1
    ldp x29, x30, [sp], #16
    ret

set_unix_seconds:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x1, x0
    bl uptime_seconds
    sub x1, x1, x0
    ldr x0, =unix_offset
    str x1, [x0]
    ldr x0, =clock_synced
    mov x1, #1
    str x1, [x0]
    ldp x29, x30, [sp], #16
    ret

print_u64_ln:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl print_u64
    bl newline
    ldp x29, x30, [sp], #16
    ret

print_u64:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    mov x19, x0
    ldr x20, =num_buf_end
    mov w21, #0
    strb w21, [x20]
    sub x20, x20, #1
    cbnz x19, 1f
    mov w21, #'0'
    strb w21, [x20]
    mov x0, x20
    bl puts
    b 3f
1:
    mov x22, #10
2:
    udiv x1, x19, x22
    msub x3, x1, x22, x19
    add w3, w3, #'0'
    strb w3, [x20]
    sub x20, x20, #1
    mov x19, x1
    cbnz x19, 2b
    add x0, x20, #1
    bl puts
3:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret

parse_u64:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    bl skip_spaces
    mov x19, x0
    mov x20, #0
    mov x2, #0
0:
    ldrb w1, [x19], #1
    cbz w1, 2f
    cmp w1, #'0'
    b.lo 1f
    cmp w1, #'9'
    b.hi 1f
    mov x3, #10
    mul x20, x20, x3
    sub w1, w1, #'0'
    add x20, x20, x1
    mov x2, #1
    b 0b
1:
    cmp w1, #' '
    b.eq 0b
    cmp w1, #9
    b.eq 0b
    mov x1, #1
    mov x0, #0
    b 3f
2:
    cbnz x2, 4f
    mov x1, #1
    mov x0, #0
    b 3f
4:
    mov x0, x20
    mov x1, #0
3:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

immediate_child_name:
    stp x29, x30, [sp, #-64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x1, =root_path
    mov x0, x19
    bl streq
    cbz x0, 2f
    ldrb w0, [x20]
    cmp w0, #'/'
    b.ne 7f
    add x22, x20, #1
    ldrb w0, [x22]
    cbz w0, 7f
1:
    ldrb w0, [x22], #1
    cbz w0, 6f
    cmp w0, #'/'
    b.eq 7f
    b 1b
2:
    mov x0, x20
    mov x1, x19
    bl startswith
    cbz x0, 7f
    mov x0, x19
    bl string_length
    mov x23, x0
    add x24, x20, x23
    ldrb w0, [x24]
    cmp w0, #'/'
    b.ne 7f
    add x22, x24, #1
    ldrb w0, [x22]
    cbz w0, 7f
3:
    ldrb w0, [x22], #1
    cbz w0, 4f
    cmp w0, #'/'
    b.eq 7f
    b 3b
4:
    add x22, x24, #1
6:
    mov x0, x21
    mov x1, x22
    mov x2, #PATH_BUF_SIZE
    bl copy_string_bounded
    cmp x0, #0
    cset x0, eq
    b 8f
7:
    mov x0, #0
8:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x29, x30, [sp], #64
    ret

list_dir:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    mov x19, x0
    mov x0, x19
    bl dir_exists
    cbnz x0, 0f
    ldr x0, =msg_ls_no_dir
    bl puts_ln
    b 6f
0:
    ldr x20, =dir_entries
    mov x21, #MAX_DIRS
1:
    cbz x21, 3f
    ldr x22, [x20, #DIR_USED_OFFSET]
    cbz x22, 2f
    mov x0, x19
    add x1, x20, #DIR_PATH_OFFSET
    ldr x2, =temp_name_buf
    bl immediate_child_name
    cbz x0, 2f
    ldr x0, =temp_name_buf
    bl puts
    ldr x0, =slash_text
    bl puts
    bl newline
2:
    add x20, x20, #DIR_SLOT_SIZE
    subs x21, x21, #1
    b.ne 1b
3:
    ldr x20, =file_entries
    mov x21, #MAX_FILES
4:
    cbz x21, 6f
    ldr x22, [x20, #FILE_USED_OFFSET]
    cbz x22, 5f
    mov x0, x19
    add x1, x20, #FILE_PATH_OFFSET
    ldr x2, =temp_name_buf
    bl immediate_child_name
    cbz x0, 5f
    ldr x0, =temp_name_buf
    bl puts_ln
5:
    add x20, x20, #FILE_SLOT_SIZE
    subs x21, x21, #1
    b.ne 4b
6:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret

print_file_or_error:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    bl fs_read_file
    cbnz x0, 0f
    ldr x0, =msg_file_not_found
    bl puts_ln
    b 1f
0:
    bl puts_ln
1:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

print_fs_status:
    cmp x0, #0
    b.eq 4f
    cmp x0, #1
    b.eq 0f
    cmp x0, #2
    b.eq 1f
    cmp x0, #3
    b.eq 2f
    ldr x0, =msg_invalid_path
    b 3f
0:
    ldr x0, =msg_already_exists
    b 3f
1:
    ldr x0, =msg_parent_missing
    b 3f
2:
    ldr x0, =msg_no_space
3:
    bl puts_ln
4:
    ret

python_repl:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    ldr x0, =msg_python_banner_1
    bl puts_ln
    ldr x0, =msg_python_banner_2
    bl puts_ln
0:
    ldr x0, =python_prompt
    bl puts
    ldr x0, =python_line_buf
    mov x1, #LINE_BUF_SIZE
    bl read_line
    bl trim_in_place
    ldrb w1, [x0]
    cbz w1, 0b
    ldr x1, =cmd_exit_paren
    bl streq
    cbnz x0, 2f
    ldr x1, =cmd_quit_paren
    ldr x0, =python_line_buf
    bl trim_in_place
    bl streq
    cbnz x0, 2f
    ldr x0, =python_line_buf
    bl trim_in_place
    bl python_eval_line
    b 0b
2:
    ldr x0, =msg_python_leave
    bl puts_ln
    ldp x29, x30, [sp], #16
    ret

python_eval_line:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    mov x19, x0
    ldr x1, =cmd_print_prefix
    mov x0, x19
    bl match_prefix
    cbz x0, 4f
    mov x19, x0
    mov x0, x19
    bl string_length
    cbz x0, 7f
    add x20, x19, x0
    sub x20, x20, #1
    ldrb w1, [x20]
    cmp w1, #')'
    b.ne 7f
    strb wzr, [x20]
    ldrb w1, [x19]
    cmp w1, #'"'
    b.ne 3f
    mov x0, x19
    bl string_length
    cmp x0, #2
    b.lo 7f
    add x21, x19, x0
    sub x21, x21, #1
    ldrb w1, [x21]
    cmp w1, #'"'
    b.ne 7f
    strb wzr, [x21]
    add x0, x19, #1
    bl puts_ln
    b 8f
3:
    mov x0, x19
    bl eval_simple_expr
    cmp x1, #0
    b.ne 7f
    bl print_u64_ln
    b 8f
4:
    mov x0, x19
    bl eval_simple_expr
    cmp x1, #0
    b.ne 7f
    bl print_u64_ln
    b 8f
7:
    ldr x0, =msg_python_error
    bl puts_ln
8:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret

eval_simple_expr:
    stp x29, x30, [sp, #-64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x29, sp
    mov x19, x0
    bl skip_spaces
    mov x19, x0
    mov x0, x19
    bl parse_u64_expr_piece
    cmp x1, #0
    b.ne 9f
    mov x20, x0
    mov x19, x2
    mov x0, x19
    bl skip_spaces
    mov x19, x0
    ldrb w21, [x19]
    cbz w21, 8f
    add x19, x19, #1
    mov x0, x19
    bl parse_u64_expr_piece
    cmp x1, #0
    b.ne 9f
    mov x22, x0
    mov x19, x2
    mov x0, x19
    bl skip_spaces
    mov x19, x0
    ldrb w0, [x19]
    cbnz w0, 9f
    cmp w21, #'+'
    b.eq 0f
    cmp w21, #'-'
    b.eq 1f
    cmp w21, #'*'
    b.eq 2f
    cmp w21, #'/'
    b.eq 3f
    b 9f
0:
    add x0, x20, x22
    mov x1, #0
    b 10f
1:
    subs x0, x20, x22
    b.hs 7f
    mov x0, #0
7:
    mov x1, #0
    b 10f
2:
    mul x0, x20, x22
    mov x1, #0
    b 10f
3:
    cbz x22, 9f
    udiv x0, x20, x22
    mov x1, #0
    b 10f
8:
    mov x0, x20
    mov x1, #0
    b 10f
9:
    mov x0, #0
    mov x1, #1
10:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x29, x30, [sp], #64
    ret

parse_u64_expr_piece:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0
    bl skip_spaces
    mov x19, x0
    mov x20, #0
    mov x3, #0
0:
    ldrb w1, [x19]
    cmp w1, #'0'
    b.lo 1f
    cmp w1, #'9'
    b.hi 1f
    mov x4, #10
    mul x20, x20, x4
    sub w1, w1, #'0'
    add x20, x20, x1
    add x19, x19, #1
    mov x3, #1
    b 0b
1:
    cbnz x3, 2f
    mov x0, #0
    mov x1, #1
    mov x2, x19
    b 3f
2:
    mov x0, x20
    mov x1, #0
    mov x2, x19
3:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

banner:
    ldr x0, =banner_line_1
    bl puts_ln
    ldr x0, =banner_line_2
    bl puts_ln
    ldr x0, =banner_line_3
    bl puts_ln
    bl newline
    ret

shell_loop:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
0:
    ldr x0, =prompt_prefix
    bl puts
    ldr x0, =cwd_buf
    bl puts
    ldr x0, =prompt_suffix
    bl puts

    ldr x0, =line_buf
    mov x1, #LINE_BUF_SIZE
    bl read_line
    bl trim_in_place
    mov x19, x0
    ldrb w0, [x19]
    cbz w0, 0b

    mov x0, x19
    ldr x1, =cmd_help
    bl streq
    cbz x0, 1f
    bl show_help
    b 0b
1:
    mov x0, x19
    ldr x1, =cmd_clear
    bl streq
    cbz x0, 2f
    ldr x0, =ansi_clear
    bl puts
    b 0b
2:
    mov x0, x19
    ldr x1, =cmd_pwd
    bl streq
    cbz x0, 3f
    ldr x0, =cwd_buf
    bl puts_ln
    b 0b
3:
    mov x0, x19
    ldr x1, =cmd_python
    bl streq
    cbz x0, 4f
    bl python_repl
    b 0b
4:
    mov x0, x19
    ldr x1, =cmd_echo_prefix
    bl match_prefix
    cbz x0, 5f
    bl puts_ln
    b 0b
5:
    mov x0, x19
    ldr x1, =cmd_uname
    bl streq
    cbz x0, 6f
    ldr x0, =uname_short
    bl puts_ln
    b 0b
6:
    mov x0, x19
    ldr x1, =cmd_uname_a
    bl streq
    cbz x0, 7f
    ldr x0, =uname_long
    bl puts_ln
    b 0b
7:
    mov x0, x19
    ldr x1, =cmd_weather
    bl streq
    cbz x0, 8f
    ldr x0, =seed_file_weather_path
    bl print_file_or_error
    b 0b
8:
    mov x0, x19
    ldr x1, =cmd_weather_set_prefix
    bl match_prefix
    cbz x0, 9f
    mov x1, x0
    ldr x0, =seed_file_weather_path
    bl fs_write_file
    cmp x0, #0
    b.ne 20f
    ldr x0, =msg_weather_updated
    bl puts_ln
    b 0b
9:
    mov x0, x19
    ldr x1, =cmd_date
    bl streq
    cbz x0, 10f
    ldr x0, =msg_date_prefix
    bl puts
    bl unix_seconds
    bl print_u64
    bl newline
    ldr x0, =clock_synced
    ldr x0, [x0]
    cbnz x0, 0b
    ldr x0, =msg_clock_unsynced
    bl puts_ln
    b 0b
10:
    mov x0, x19
    ldr x1, =cmd_date_epoch
    bl streq
    cbz x0, 11f
    bl unix_seconds
    bl print_u64_ln
    b 0b
11:
    mov x0, x19
    ldr x1, =cmd_date_set_prefix
    bl match_prefix
    cbz x0, 12f
    bl parse_u64
    cmp x1, #0
    b.ne 21f
    bl set_unix_seconds
    ldr x0, =msg_clock_updated
    bl puts_ln
    b 0b
12:
    mov x0, x19
    ldr x1, =cmd_cd_prefix
    bl match_prefix
    cbz x0, 13f
    ldr x1, =temp_path_buf
    bl resolve_path
    cbz x0, 22f
    bl dir_exists
    cbz x0, 23f
    ldr x0, =cwd_buf
    ldr x1, =temp_path_buf
    mov x2, #PATH_BUF_SIZE
    bl copy_string_bounded
    b 0b
13:
    mov x0, x19
    ldr x1, =cmd_ls
    bl streq
    cbz x0, 14f
    ldr x0, =cwd_buf
    bl list_dir
    b 0b
14:
    mov x0, x19
    ldr x1, =cmd_ls_prefix
    bl match_prefix
    cbz x0, 15f
    ldr x1, =temp_path_buf
    bl resolve_path
    cbz x0, 24f
    ldr x0, =temp_path_buf
    bl file_exists
    cbz x0, ls_list_target_dir
    ldr x0, =temp_path_buf
    ldr x1, =temp_name_buf
    bl basename_copy
    ldr x0, =temp_name_buf
    bl puts_ln
    b 0b
ls_list_target_dir:
    ldr x0, =temp_path_buf
    bl list_dir
    b 0b
15:
    mov x0, x19
    ldr x1, =cmd_cat_prefix
    bl match_prefix
    cbz x0, 16f
    ldr x1, =temp_path_buf
    bl resolve_path
    cbz x0, 24f
    bl print_file_or_error
    b 0b
16:
    mov x0, x19
    ldr x1, =cmd_mkdir_prefix
    bl match_prefix
    cbz x0, 17f
    ldr x1, =temp_path_buf
    bl resolve_path
    cbz x0, 22f
    bl fs_mkdir
    cmp x0, #0
    b.ne 20f
    ldr x0, =msg_dir_created
    bl puts_ln
    b 0b
17:
    mov x0, x19
    ldr x1, =cmd_touch_prefix
    bl match_prefix
    cbz x0, 18f
    ldr x1, =temp_path_buf
    bl resolve_path
    cbz x0, 22f
    bl fs_touch
    cmp x0, #0
    b.ne 20f
    ldr x0, =msg_file_created
    bl puts_ln
    b 0b
18:
    mov x0, x19
    ldr x1, =cmd_write_prefix
    bl match_prefix
    cbz x0, 19f
    ldr x1, =temp_arg_buf
    bl split_first_word
    cbz x0, 25f
    mov x20, x0
    ldr x0, =temp_arg_buf
    ldr x1, =temp_path_buf
    bl resolve_path
    cbz x0, 22f
    ldr x0, =temp_path_buf
    mov x1, x20
    bl fs_write_file
    cmp x0, #0
    b.ne 20f
    ldr x0, =msg_file_updated
    bl puts_ln
    b 0b
19:
    ldr x0, =line_buf
    bl puts
    ldr x0, =msg_command_not_found
    bl puts_ln
    b 0b

20:
    bl print_fs_status
    b 0b
21:
    ldr x0, =msg_date_set_error
    bl puts_ln
    b 0b
22:
    ldr x0, =msg_invalid_path
    bl puts_ln
    b 0b
23:
    ldr x0, =msg_cd_no_dir
    bl puts_ln
    b 0b
24:
    ldr x0, =msg_invalid_path
    bl puts_ln
    b 0b
25:
    ldr x0, =msg_write_usage
    bl puts_ln
    b 0b

split_first_word:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    mov x0, x19
    bl skip_spaces
    mov x19, x0
    ldrb w0, [x19]
    cbz w0, 4f
    mov x21, #0
0:
    ldrb w0, [x19, x21]
    cbz w0, 4f
    cmp w0, #' '
    b.eq 1f
    add x21, x21, #1
    cmp x21, #(PATH_BUF_SIZE - 1)
    b.lo 0b
    b 4f
1:
    mov x0, x20
    mov x1, x19
    mov x2, x21
    bl copy_prefix
    add x22, x19, x21
    mov x0, x22
    bl skip_spaces
    ldrb w1, [x0]
    cbz w1, 4f
    b 3f
4:
    mov x0, #0
3:
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret

show_help:
    ldr x0, =help_1
    bl puts_ln
    ldr x0, =help_2
    bl puts_ln
    ldr x0, =help_3
    bl puts_ln
    ldr x0, =help_4
    bl puts_ln
    ldr x0, =help_5
    bl puts_ln
    ldr x0, =help_6
    bl puts_ln
    ldr x0, =help_7
    bl puts_ln
    ldr x0, =help_8
    bl puts_ln
    ldr x0, =help_9
    bl puts_ln
    ldr x0, =help_10
    bl puts_ln
    ldr x0, =help_11
    bl puts_ln
    ldr x0, =help_12
    bl puts_ln
    ldr x0, =help_13
    bl puts_ln
    ret

.section .rodata
banner_line_1:           .asciz "Osmium firmware"
banner_line_2:           .asciz "Raw AArch64 assembly for Raspberry Pi 4"
banner_line_3:           .asciz "UART shell, RAM filesystem, date, weather, and tiny python"

prompt_prefix:           .asciz "osmium:"
prompt_suffix:           .asciz "$ "
python_prompt:           .asciz ">>> "
ansi_clear:              .asciz "\033[2J\033[H"
slash_text:              .asciz "/"
root_path:               .asciz "/"
dot_path:                .asciz "."
dotdot_path:             .asciz ".."
empty_text:              .asciz ""

cmd_help:                .asciz "help"
cmd_clear:               .asciz "clear"
cmd_pwd:                 .asciz "pwd"
cmd_python:              .asciz "python"
cmd_echo_prefix:         .asciz "echo "
cmd_uname:               .asciz "uname"
cmd_uname_a:             .asciz "uname -a"
cmd_weather:             .asciz "weather"
cmd_weather_set_prefix:  .asciz "weather set "
cmd_date:                .asciz "date"
cmd_date_epoch:          .asciz "date +%s"
cmd_date_set_prefix:     .asciz "date set "
cmd_cd_prefix:           .asciz "cd "
cmd_ls:                  .asciz "ls"
cmd_ls_prefix:           .asciz "ls "
cmd_cat_prefix:          .asciz "cat "
cmd_mkdir_prefix:        .asciz "mkdir "
cmd_touch_prefix:        .asciz "touch "
cmd_write_prefix:        .asciz "write "
cmd_exit_paren:          .asciz "exit()"
cmd_quit_paren:          .asciz "quit()"
cmd_print_prefix:        .asciz "print("

uname_short:             .asciz "Osmium"
uname_long:              .asciz "Osmium pi4 aarch64 raw-firmware"

msg_weather_updated:     .asciz "weather cache updated"
msg_clock_unsynced:      .asciz "unsynced; use `date set <unix_seconds>`"
msg_date_prefix:         .asciz "unix="
msg_clock_updated:       .asciz "clock updated"
msg_date_set_error:      .asciz "date: expected unix seconds"
msg_ls_no_dir:           .asciz "ls: no such directory"
msg_file_not_found:      .asciz "cat: file not found"
msg_already_exists:      .asciz "already exists"
msg_parent_missing:      .asciz "parent directory missing"
msg_no_space:            .asciz "out of space"
msg_invalid_path:        .asciz "invalid path"
msg_cd_no_dir:           .asciz "cd: no such directory"
msg_dir_created:         .asciz "directory created"
msg_file_created:        .asciz "file created"
msg_file_updated:        .asciz "file updated"
msg_write_usage:         .asciz "write: usage: write <path> <text>"
msg_command_not_found:   .asciz ": command not found"
msg_python_banner_1:     .asciz "OsmiumPy"
msg_python_banner_2:     .asciz "Supports integers, one operator, and print(\"text\")."
msg_python_leave:        .asciz "leaving python"
msg_python_error:        .asciz "error"

help_1:                  .asciz "Available commands:"
help_2:                  .asciz "  help"
help_3:                  .asciz "  clear"
help_4:                  .asciz "  pwd | cd <path> | ls [path] | cat <file>"
help_5:                  .asciz "  mkdir <path> | touch <path> | write <path> <text>"
help_6:                  .asciz "  echo <text>"
help_7:                  .asciz "  uname | uname -a"
help_8:                  .asciz "  date"
help_9:                  .asciz "  date +%s"
help_10:                 .asciz "  date set <unix_seconds>"
help_11:                 .asciz "  weather"
help_12:                 .asciz "  weather set <text>"
help_13:                 .asciz "  python"

seed_dir_bin:            .asciz "/bin"
seed_dir_etc:            .asciz "/etc"
seed_dir_home:           .asciz "/home"
seed_dir_tmp:            .asciz "/tmp"

seed_file_motd_path:     .asciz "/etc/motd"
seed_file_motd_data:     .asciz "Welcome to Osmium raw firmware.\nMac-style command names are exposed over UART."
seed_file_weather_path:  .asciz "/etc/weather.txt"
seed_file_weather_data:  .asciz "San Francisco: 68F, clear skies (cached sample)"
seed_file_readme_path:   .asciz "/home/readme.txt"
seed_file_readme_data:   .asciz "Try: help, ls, cat /etc/motd, date, weather, python"

.section .bss
.balign 16
__bss_start:

cwd_buf:                 .space PATH_BUF_SIZE
line_buf:                .space LINE_BUF_SIZE
python_line_buf:         .space LINE_BUF_SIZE
temp_path_buf:           .space PATH_BUF_SIZE
temp_parent_buf:         .space PATH_BUF_SIZE
temp_arg_buf:            .space PATH_BUF_SIZE
temp_name_buf:           .space PATH_BUF_SIZE
num_buf:                 .space NUM_BUF_SIZE
num_buf_end:

timer_start:             .space 8
timer_freq:              .space 8
unix_offset:             .space 8
clock_synced:            .space 8

dir_entries:             .space DIR_SLOT_SIZE * MAX_DIRS
file_entries:            .space FILE_SLOT_SIZE * MAX_FILES

__bss_end:
