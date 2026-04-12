/* ===========================================================================
 * linker.ld - Kernel Linker Script
 * ===========================================================================
 * Controls the memory layout of the kernel binary.
 *
 * The bootloader loads the kernel at physical address 0x1000 and jumps
 * there after switching to 32-bit protected mode. This script ensures
 * that the kernel binary is laid out correctly starting at that address.
 *
 * Section order:
 *   .text   - Executable code (kernel_entry.asm first!)
 *   .rodata - Read-only data (string literals, constants)
 *   .data   - Initialized global/static variables
 *   .bss    - Uninitialized global/static variables (zeroed at startup)
 *
 * The _start symbol (from kernel_entry.asm) MUST be at 0x1000 because
 * the bootloader does `call 0x1000`.
 * =========================================================================== */

ENTRY(_start)
OUTPUT_FORMAT(elf32-i386)

SECTIONS
{
    /* Start the kernel at the address where the bootloader loads it */
    . = 0x1000;

    /* --- Code Section --- */
    .text ALIGN(4) :
    {
        /* kernel_entry.o MUST come first so _start is at 0x1000 */
        *kernel_entry.o(.text)

        /* All other code */
        *(.text)
        *(.text.*)
    }

    /* --- Read-Only Data --- */
    .rodata ALIGN(4) :
    {
        *(.rodata)
        *(.rodata.*)
    }

    /* --- Initialized Data --- */
    .data ALIGN(4) :
    {
        *(.data)
        *(.data.*)
    }

    /* --- Uninitialized Data (BSS) --- */
    /* BSS is not stored in the binary file; it's zeroed at runtime.
     * We record its start and end addresses so the kernel can zero it
     * during initialization (not yet implemented in this skeleton). */
    .bss ALIGN(4) :
    {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        _bss_end = .;
    }

    /* Record total kernel size for reference */
    _kernel_end = .;

    /* Discard unnecessary sections to keep binary small */
    /DISCARD/ :
    {
        *(.comment)
        *(.note.*)
        *(.eh_frame)
    }
}
