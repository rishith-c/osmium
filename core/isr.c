/* ===========================================================================
 * isr.c - Interrupt Service Routines (C Handlers)
 * ===========================================================================
 * These are the C-language handlers called by the assembly stubs in
 * isr_stubs.asm after the register state has been saved.
 * =========================================================================== */

#include "isr.h"
#include "ports.h"
#include "screen.h"
#include "string.h"

/* Exception names for debugging */
static const char *EXCEPTION_NAMES[] = {
    "Division By Zero",
    "Debug",
    "Non Maskable Interrupt",
    "Breakpoint",
    "Overflow",
    "Bound Range Exceeded",
    "Invalid Opcode",
    "Device Not Available",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Invalid TSS",
    "Segment Not Present",
    "Stack-Segment Fault",
    "General Protection Fault",
    "Page Fault",
    "Reserved",
    "x87 Floating-Point",
    "Alignment Check",
    "Machine Check",
    "SIMD Floating-Point",
    "Virtualization",
    "Control Protection",
    "Reserved", "Reserved", "Reserved", "Reserved",
    "Reserved", "Reserved", "Reserved", "Reserved",
    "Reserved", "Reserved"
};

/* Table of registered IRQ handlers (one per IRQ, 0-15) */
static irq_handler_t irq_handlers[16] = { 0 };

/* ---------------------------------------------------------------------------
 * irq_install_handler - Register a C function to handle a specific IRQ
 * --------------------------------------------------------------------------- */
void irq_install_handler(int irq, irq_handler_t handler)
{
    if (irq >= 0 && irq < 16) {
        irq_handlers[irq] = handler;
    }
}

/* ---------------------------------------------------------------------------
 * irq_uninstall_handler - Remove the handler for a specific IRQ
 * --------------------------------------------------------------------------- */
void irq_uninstall_handler(int irq)
{
    if (irq >= 0 && irq < 16) {
        irq_handlers[irq] = 0;
    }
}

/* ---------------------------------------------------------------------------
 * isr_handler - Called by assembly stub for CPU exceptions (vectors 0-31)
 * ---------------------------------------------------------------------------
 * For this skeleton, we just print the exception name and halt.
 * A real OS would handle recoverable exceptions (e.g., page faults).
 * --------------------------------------------------------------------------- */
void isr_handler(registers_t *regs)
{
    if (regs->int_no < 32) {
        char buf[12];
        print_string_color("\n!!! CPU EXCEPTION: ", (COLOR_RED << 4) | COLOR_WHITE);
        print_string_color(EXCEPTION_NAMES[regs->int_no],
                          (COLOR_RED << 4) | COLOR_WHITE);
        print_string(" (int ");
        itoa((int)regs->int_no, buf);
        print_string(buf);
        print_string(", err=");
        itoa((int)regs->err_code, buf);
        print_string(buf);
        print_string(")\n");

        print_string("EIP=0x");
        /* Simple hex print for EIP */
        {
            unsigned int val = regs->eip;
            char hex[9];
            int i;
            for (i = 7; i >= 0; i--) {
                int nibble = val & 0xF;
                hex[i] = nibble < 10 ? '0' + nibble : 'A' + nibble - 10;
                val >>= 4;
            }
            hex[8] = '\0';
            print_string(hex);
        }
        print_string("\nSystem halted.\n");

        /* Halt - unrecoverable */
        __asm__ __volatile__("cli; hlt");
    }
}

/* ---------------------------------------------------------------------------
 * irq_handler - Called by assembly stub for hardware IRQs (vectors 32-47)
 * ---------------------------------------------------------------------------
 * Dispatches to the registered handler (if any), then sends End-Of-Interrupt
 * (EOI) to the PIC so it knows we're done processing.
 * --------------------------------------------------------------------------- */
void irq_handler(registers_t *regs)
{
    int irq_num = (int)(regs->int_no - 32);

    /* Call the registered handler if one exists */
    if (irq_num >= 0 && irq_num < 16 && irq_handlers[irq_num]) {
        irq_handlers[irq_num](regs);
    }

    /* Send EOI (End Of Interrupt) to PIC */
    if (regs->int_no >= 40) {
        /* IRQ came from slave PIC - send EOI to both */
        outb(0xA0, 0x20);
    }
    /* Always send EOI to master PIC */
    outb(0x20, 0x20);
}
