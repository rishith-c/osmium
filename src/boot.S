.section .text._start
.globl _start

_start:
    mrs x1, mpidr_el1
    and x1, x1, #0b11
    cbz x1, 2f

1:
    wfe
    b 1b

2:
    ldr x1, =__boot_stack_top
    mov sp, x1
    bl kernel_init

3:
    wfe
    b 3b

