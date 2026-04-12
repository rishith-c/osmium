; =============================================================================
; boot.asm - Dual-State OS Bootloader
; =============================================================================
; This is a 16-bit real mode bootloader that:
;   1. Sets up the stack and segments
;   2. Loads the kernel from disk into memory at KERNEL_OFFSET
;   3. Enables the A20 address line (access memory beyond 1MB)
;   4. Sets up the Global Descriptor Table (GDT) for protected mode
;   5. Switches the CPU from 16-bit real mode to 32-bit protected mode
;   6. Jumps to the kernel entry point
;
; Memory layout:
;   0x0000 - 0x0FFF : Reserved (IVT, BIOS data)
;   0x1000 - 0x????  : Kernel loaded here
;   0x7C00 - 0x7DFF : This boot sector (512 bytes)
;   0x90000          : Stack top (grows downward)
; =============================================================================

[org 0x7c00]                    ; BIOS loads boot sector at this address
[bits 16]                       ; Start in 16-bit real mode

KERNEL_OFFSET equ 0x1000       ; Memory address where we load the kernel

; =============================================================================
; Entry Point
; =============================================================================
boot_start:
    ; --- Set up segment registers ---
    ; In real mode, segments are used for memory addressing.
    ; We zero them out so addresses are flat (segment:offset = 0:offset).
    xor ax, ax
    mov ds, ax                  ; Data segment = 0
    mov es, ax                  ; Extra segment = 0
    mov ss, ax                  ; Stack segment = 0
    mov sp, 0x7c00              ; Stack pointer just below boot sector (grows down)

    ; BIOS passes the boot drive number in DL. Save it for later.
    mov [BOOT_DRIVE], dl

    ; --- Print real mode banner ---
    mov si, MSG_BOOT
    call print_string_rm

    ; --- Load kernel from disk ---
    call load_kernel

    ; --- Switch to 32-bit protected mode ---
    call switch_to_pm

    ; We should never reach here. Infinite loop as safety net.
    jmp $

; =============================================================================
; print_string_rm - Print a null-terminated string in 16-bit real mode
; =============================================================================
; Uses BIOS interrupt 0x10, function 0x0E (teletype output).
; Input: SI = pointer to null-terminated string
; =============================================================================
print_string_rm:
    pusha                       ; Save all general-purpose registers
.loop:
    lodsb                       ; Load byte at [SI] into AL, increment SI
    or al, al                   ; Check if AL is zero (null terminator)
    jz .done
    mov ah, 0x0e                ; BIOS teletype function
    int 0x10                    ; Call BIOS video interrupt
    jmp .loop
.done:
    popa                        ; Restore registers
    ret

; =============================================================================
; load_kernel - Load kernel sectors from disk into memory
; =============================================================================
; Uses BIOS interrupt 0x13 (disk services) to read sectors.
;
; Disk layout:
;   Sector 1:     Boot sector (this file)
;   Sectors 2-16: Kernel binary
;
; The kernel is loaded to KERNEL_OFFSET (0x1000).
; We read 15 sectors (~7.5 KB), which is plenty for our skeleton kernel.
; =============================================================================
load_kernel:
    mov si, MSG_LOAD
    call print_string_rm

    ; Set up parameters for BIOS disk read (INT 0x13, AH=0x02)
    mov ah, 0x02                ; Function: read sectors
    mov al, 48                  ; Number of sectors to read (~24KB, room for growth)
    mov ch, 0                   ; Cylinder 0
    mov cl, 2                   ; Start from sector 2 (sector 1 is boot sector)
    mov dh, 0                   ; Head 0
    mov dl, [BOOT_DRIVE]        ; Drive number (saved earlier)
    mov bx, KERNEL_OFFSET       ; Buffer address (ES:BX = 0x0000:0x1000)

    int 0x13                    ; Call BIOS disk interrupt
    jc .disk_error              ; Jump if carry flag set (error)

    ; Verify we read the correct number of sectors
    cmp al, 48
    jne .disk_error

    mov si, MSG_LOAD_OK
    call print_string_rm
    ret

.disk_error:
    mov si, MSG_DISK_ERR
    call print_string_rm
    jmp $                       ; Halt on disk error

; =============================================================================
; GDT - Global Descriptor Table
; =============================================================================
; The GDT defines memory segments for protected mode. Each entry is 8 bytes.
;
; We define three segments:
;   1. Null descriptor (required by CPU, must be all zeros)
;   2. Code segment (executable, readable)
;   3. Data segment (writable)
;
; Both code and data segments span the entire 4GB address space (flat model).
; This means segmentation is effectively disabled, and we use paging later
; for memory protection (not implemented in this skeleton).
;
; Descriptor format (8 bytes):
;   Bytes 0-1: Limit bits 0-15
;   Bytes 2-3: Base bits 0-15
;   Byte 4:    Base bits 16-23
;   Byte 5:    Access byte (present, ring, type, etc.)
;   Byte 6:    Flags (granularity, size) + Limit bits 16-19
;   Byte 7:    Base bits 24-31
; =============================================================================
gdt_start:

gdt_null:                       ; Null descriptor - mandatory first entry
    dd 0x0
    dd 0x0

gdt_code:                       ; Code segment descriptor
    dw 0xffff                   ; Limit 0-15:  0xFFFFF (full 4GB with granularity)
    dw 0x0                      ; Base 0-15:   0x0
    db 0x0                      ; Base 16-23:  0x0
    db 10011010b                ; Access byte: Present=1, Ring=00, S=1, Exec=1, DC=0, RW=1, A=0
    db 11001111b                ; Flags: Gran=1, Size=1, L=0, AVL=0 | Limit 16-19: 0xF
    db 0x0                      ; Base 24-31:  0x0

gdt_data:                       ; Data segment descriptor
    dw 0xffff                   ; Limit 0-15:  0xFFFFF
    dw 0x0                      ; Base 0-15:   0x0
    db 0x0                      ; Base 16-23:  0x0
    db 10010010b                ; Access byte: Present=1, Ring=00, S=1, Exec=0, DC=0, RW=1, A=0
    db 11001111b                ; Flags: Gran=1, Size=1, L=0, AVL=0 | Limit 16-19: 0xF
    db 0x0                      ; Base 24-31:  0x0

gdt_end:

; GDT descriptor (loaded by LGDT instruction)
; Contains the size (limit) and starting address of the GDT.
gdt_descriptor:
    dw gdt_end - gdt_start - 1 ; Size of GDT minus 1
    dd gdt_start                ; Linear address of GDT

; Segment selector constants (byte offset into GDT)
CODE_SEG equ gdt_code - gdt_start  ; = 0x08
DATA_SEG equ gdt_data - gdt_start  ; = 0x10

; =============================================================================
; switch_to_pm - Switch CPU from 16-bit real mode to 32-bit protected mode
; =============================================================================
; Steps:
;   1. Disable interrupts (real mode ISRs are invalid in protected mode)
;   2. Load the GDT
;   3. Enable A20 line (allows addressing beyond 1MB)
;   4. Set bit 0 of CR0 (Protection Enable bit)
;   5. Far jump to flush the CPU pipeline and load CS with code segment
; =============================================================================
[bits 16]
switch_to_pm:
    cli                         ; Disable interrupts

    lgdt [gdt_descriptor]       ; Load GDT register with our descriptor

    ; --- Enable A20 line ---
    ; The A20 line is a legacy holdover from the 8086. When disabled,
    ; address line 20 is forced to zero, limiting memory to 1MB.
    ; We use the "fast A20" method via I/O port 0x92.
    in al, 0x92
    or al, 0x02                 ; Set bit 1 (A20 enable)
    and al, 0xfe                ; Clear bit 0 (avoid system reset)
    out 0x92, al

    ; --- Enable protected mode ---
    mov eax, cr0
    or eax, 0x1                 ; Set PE (Protection Enable) bit
    mov cr0, eax

    ; --- Far jump to 32-bit code ---
    ; This jump does two things:
    ;   1. Flushes the CPU prefetch pipeline (it may contain 16-bit instructions)
    ;   2. Sets CS to our code segment selector (0x08)
    jmp CODE_SEG:init_pm

; =============================================================================
; 32-bit Protected Mode Initialization
; =============================================================================
[bits 32]
init_pm:
    ; Set all data segment registers to our data segment selector
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Set up a new stack at 0x90000
    ; This gives us plenty of stack space below the kernel.
    mov ebp, 0x90000
    mov esp, ebp

    ; --- Jump to kernel entry point ---
    ; The kernel was loaded at KERNEL_OFFSET (0x1000).
    ; kernel_entry.asm is linked at this address and calls kernel_main().
    call KERNEL_OFFSET

    ; If kernel_main() ever returns, halt the CPU
    cli
    hlt
    jmp $                       ; Safety: infinite loop

; =============================================================================
; Data Section
; =============================================================================
BOOT_DRIVE:     db 0            ; Stored boot drive number
MSG_BOOT:       db "[BOOT] Dual-State OS Bootloader v0.1", 13, 10, 0
MSG_LOAD:       db "[BOOT] Loading kernel from disk...", 13, 10, 0
MSG_LOAD_OK:    db "[BOOT] Kernel loaded successfully.", 13, 10, 0
MSG_DISK_ERR:   db "[BOOT] FATAL: Disk read error!", 13, 10, 0

; =============================================================================
; Boot Sector Padding and Magic Number
; =============================================================================
; The boot sector must be exactly 512 bytes. The last two bytes must be
; 0x55AA (the boot signature). BIOS checks for this to identify bootable media.
; =============================================================================
times 510 - ($ - $$) db 0      ; Pad with zeros to 510 bytes
dw 0xAA55                      ; Boot signature
