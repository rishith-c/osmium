; =============================================================================
; kernel_entry.asm - Kernel Entry Point (Assembly Stub)
; =============================================================================
; This is the very first code that runs when the bootloader jumps to the
; kernel. It exists because the bootloader does `call KERNEL_OFFSET`, and
; we need a known entry point at that exact address.
;
; This file is linked FIRST in the kernel binary, so it sits at offset 0x1000
; in memory (matching KERNEL_OFFSET in boot.asm).
;
; All it does is call the C function kernel_main() and then halt.
; =============================================================================

[bits 32]                       ; We're in 32-bit protected mode
[extern kernel_main]            ; Defined in kernel/kernel.c

section .text

global _start
_start:
    call kernel_main            ; Jump into C land

    ; kernel_main() should never return, but if it does:
    cli                         ; Disable interrupts
    hlt                         ; Halt the CPU
    jmp $                       ; Infinite loop (safety net)
