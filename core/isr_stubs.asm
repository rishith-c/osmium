; =============================================================================
; isr_stubs.asm - Assembly ISR/IRQ Entry Points
; =============================================================================
; These stubs are the raw interrupt entry points. When an interrupt fires,
; the CPU jumps to one of these stubs. Each stub:
;   1. Pushes a dummy error code (if CPU didn't push one)
;   2. Pushes the interrupt number
;   3. Jumps to a common handler that saves all registers and calls C code
;
; The C handlers are isr_handler() and irq_handler() in isr.c.
; =============================================================================

[bits 32]

; Import C handler functions
[extern isr_handler]
[extern irq_handler]

; =============================================================================
; Macros for generating ISR stubs
; =============================================================================

; ISR with no error code (CPU doesn't push one)
%macro ISR_NOERRCODE 1
global isr%1
isr%1:
    push dword 0            ; Push dummy error code
    push dword %1           ; Push interrupt number
    jmp isr_common_stub
%endmacro

; ISR with error code (CPU already pushed it)
%macro ISR_ERRCODE 1
global isr%1
isr%1:
    push dword %1           ; Push interrupt number (error code already on stack)
    jmp isr_common_stub
%endmacro

; IRQ handler
%macro IRQ 2
global irq%1
irq%1:
    push dword 0            ; Dummy error code
    push dword %2           ; Interrupt number (32 + IRQ number)
    jmp irq_common_stub
%endmacro

; =============================================================================
; CPU Exception Handlers (ISR 0-31)
; =============================================================================
; Exceptions that push an error code: 8, 10, 11, 12, 13, 14, 17, 21, 29, 30
; All others need a dummy error code pushed.
; =============================================================================

ISR_NOERRCODE 0             ; #DE - Division Error
ISR_NOERRCODE 1             ; #DB - Debug
ISR_NOERRCODE 2             ; NMI - Non-Maskable Interrupt
ISR_NOERRCODE 3             ; #BP - Breakpoint
ISR_NOERRCODE 4             ; #OF - Overflow
ISR_NOERRCODE 5             ; #BR - Bound Range Exceeded
ISR_NOERRCODE 6             ; #UD - Invalid Opcode
ISR_NOERRCODE 7             ; #NM - Device Not Available
ISR_ERRCODE   8             ; #DF - Double Fault
ISR_NOERRCODE 9             ; Coprocessor Segment Overrun (legacy)
ISR_ERRCODE   10            ; #TS - Invalid TSS
ISR_ERRCODE   11            ; #NP - Segment Not Present
ISR_ERRCODE   12            ; #SS - Stack-Segment Fault
ISR_ERRCODE   13            ; #GP - General Protection Fault
ISR_ERRCODE   14            ; #PF - Page Fault
ISR_NOERRCODE 15            ; Reserved
ISR_NOERRCODE 16            ; #MF - x87 Floating-Point Exception
ISR_ERRCODE   17            ; #AC - Alignment Check
ISR_NOERRCODE 18            ; #MC - Machine Check
ISR_NOERRCODE 19            ; #XM - SIMD Floating-Point Exception
ISR_NOERRCODE 20            ; #VE - Virtualization Exception
ISR_ERRCODE   21            ; #CP - Control Protection Exception
ISR_NOERRCODE 22            ; Reserved
ISR_NOERRCODE 23            ; Reserved
ISR_NOERRCODE 24            ; Reserved
ISR_NOERRCODE 25            ; Reserved
ISR_NOERRCODE 26            ; Reserved
ISR_NOERRCODE 27            ; Reserved
ISR_NOERRCODE 28            ; Reserved
ISR_NOERRCODE 29            ; Reserved
ISR_NOERRCODE 30            ; Reserved
ISR_NOERRCODE 31            ; Reserved

; =============================================================================
; Hardware IRQ Handlers (IRQ 0-15 -> ISR 32-47)
; =============================================================================

IRQ  0, 32                  ; PIT Timer
IRQ  1, 33                  ; Keyboard
IRQ  2, 34                  ; Cascade (master-slave PIC link)
IRQ  3, 35                  ; COM2 / COM4
IRQ  4, 36                  ; COM1 / COM3
IRQ  5, 37                  ; LPT2 / Sound card
IRQ  6, 38                  ; Floppy disk
IRQ  7, 39                  ; LPT1 / Spurious
IRQ  8, 40                  ; RTC (Real-Time Clock)
IRQ  9, 41                  ; ACPI / Available
IRQ 10, 42                  ; Available
IRQ 11, 43                  ; Available
IRQ 12, 44                  ; PS/2 Mouse
IRQ 13, 45                  ; FPU / Coprocessor
IRQ 14, 46                  ; Primary ATA
IRQ 15, 47                  ; Secondary ATA

; =============================================================================
; Common ISR Stub - Saves state, calls C handler, restores state
; =============================================================================
; Stack at entry (top to bottom):
;   SS, ESP, EFLAGS, CS, EIP  (pushed by CPU)
;   error_code                 (pushed by CPU or our dummy)
;   int_no                     (pushed by our stub)
;
; We then push all segment registers and general registers to create a
; complete registers_t structure that we pass to the C handler.
; =============================================================================

isr_common_stub:
    pusha                       ; Push EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI

    ; Save segment registers
    push ds
    push es
    push fs
    push gs

    ; Load kernel data segment
    mov ax, 0x10                ; 0x10 = kernel data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Call C handler with pointer to register struct
    push esp                    ; Pass pointer to registers_t
    call isr_handler
    add esp, 4                  ; Clean up parameter

    ; Restore segment registers
    pop gs
    pop fs
    pop es
    pop ds

    popa                        ; Restore general registers
    add esp, 8                  ; Remove error code and interrupt number
    iret                        ; Return from interrupt

; =============================================================================
; Common IRQ Stub - Same as ISR but also sends EOI to PIC
; =============================================================================

irq_common_stub:
    pusha

    push ds
    push es
    push fs
    push gs

    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    push esp
    call irq_handler
    add esp, 4

    pop gs
    pop fs
    pop es
    pop ds

    popa
    add esp, 8
    iret
