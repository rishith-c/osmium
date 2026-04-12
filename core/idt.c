/* ===========================================================================
 * idt.c - Interrupt Descriptor Table Implementation
 * ===========================================================================
 * Sets up the IDT with handlers for CPU exceptions (0-31) and hardware
 * IRQs (32-47). Also remaps the PIC so IRQs don't conflict with CPU
 * exception vectors.
 * =========================================================================== */

#include "idt.h"
#include "isr.h"
#include "ports.h"

/* The actual IDT - 256 entries, each 8 bytes */
static idt_entry_t idt[IDT_ENTRIES];

/* IDT pointer for LIDT instruction */
static idt_ptr_t idt_ptr;

/* ---------------------------------------------------------------------------
 * idt_set_gate - Configure a single IDT entry
 * ---------------------------------------------------------------------------
 * Parameters:
 *   num:      Interrupt vector number (0-255)
 *   handler:  Address of the interrupt handler function
 *   selector: Code segment selector (0x08 for our kernel code segment)
 *   flags:    Type/attribute byte
 *             0x8E = present, ring 0, 32-bit interrupt gate
 *             0xEE = present, ring 3, 32-bit interrupt gate (for syscalls)
 * --------------------------------------------------------------------------- */
void idt_set_gate(int num, unsigned int handler, unsigned short selector,
                  unsigned char flags)
{
    idt[num].offset_low  = handler & 0xFFFF;
    idt[num].selector    = selector;
    idt[num].zero        = 0;
    idt[num].type_attr   = flags;
    idt[num].offset_high = (handler >> 16) & 0xFFFF;
}

/* ---------------------------------------------------------------------------
 * pic_remap - Remap the Programmable Interrupt Controller
 * ---------------------------------------------------------------------------
 * By default, IRQ 0-7 map to interrupt vectors 8-15, which overlap with
 * CPU exceptions. We remap them:
 *   IRQ 0-7  -> vectors 32-39 (master PIC)
 *   IRQ 8-15 -> vectors 40-47 (slave PIC)
 *
 * PIC ports:
 *   Master: command=0x20, data=0x21
 *   Slave:  command=0xA0, data=0xA1
 * --------------------------------------------------------------------------- */
static void pic_remap(void)
{
    /* Save current masks */
    unsigned char mask1 = inb(0x21);
    unsigned char mask2 = inb(0xA1);

    /* ICW1: Initialize + expect ICW4 */
    outb(0x20, 0x11);
    io_wait();
    outb(0xA0, 0x11);
    io_wait();

    /* ICW2: Vector offset (where IRQs start in the IDT) */
    outb(0x21, 0x20);  /* Master: IRQ 0-7  -> IDT 32-39 */
    io_wait();
    outb(0xA1, 0x28);  /* Slave:  IRQ 8-15 -> IDT 40-47 */
    io_wait();

    /* ICW3: Master/slave wiring */
    outb(0x21, 0x04);  /* Master: slave on IRQ2 */
    io_wait();
    outb(0xA1, 0x02);  /* Slave: cascade identity */
    io_wait();

    /* ICW4: 8086 mode */
    outb(0x21, 0x01);
    io_wait();
    outb(0xA1, 0x01);
    io_wait();

    /* Restore saved masks */
    outb(0x21, mask1);
    outb(0xA1, mask2);
}

/* ---------------------------------------------------------------------------
 * idt_init - Initialize the Interrupt Descriptor Table
 * ---------------------------------------------------------------------------
 * Steps:
 *   1. Remap PIC to avoid IRQ/exception conflicts
 *   2. Zero out all IDT entries
 *   3. Install ISR handlers for CPU exceptions (0-31)
 *   4. Install IRQ handlers for hardware interrupts (32-47)
 *   5. Load the IDT using the LIDT instruction
 *   6. Enable interrupts (STI)
 * --------------------------------------------------------------------------- */
void idt_init(void)
{
    /* Set up IDT pointer */
    idt_ptr.limit = sizeof(idt) - 1;
    idt_ptr.base  = (unsigned int)&idt;

    /* Zero all entries */
    memset(&idt, 0, sizeof(idt));

    /* Remap PIC */
    pic_remap();

    /* CPU exceptions (0-31) - 0x08 = kernel code selector, 0x8E = interrupt gate */
    idt_set_gate(0,  (unsigned int)isr0,  0x08, 0x8E);
    idt_set_gate(1,  (unsigned int)isr1,  0x08, 0x8E);
    idt_set_gate(2,  (unsigned int)isr2,  0x08, 0x8E);
    idt_set_gate(3,  (unsigned int)isr3,  0x08, 0x8E);
    idt_set_gate(4,  (unsigned int)isr4,  0x08, 0x8E);
    idt_set_gate(5,  (unsigned int)isr5,  0x08, 0x8E);
    idt_set_gate(6,  (unsigned int)isr6,  0x08, 0x8E);
    idt_set_gate(7,  (unsigned int)isr7,  0x08, 0x8E);
    idt_set_gate(8,  (unsigned int)isr8,  0x08, 0x8E);
    idt_set_gate(9,  (unsigned int)isr9,  0x08, 0x8E);
    idt_set_gate(10, (unsigned int)isr10, 0x08, 0x8E);
    idt_set_gate(11, (unsigned int)isr11, 0x08, 0x8E);
    idt_set_gate(12, (unsigned int)isr12, 0x08, 0x8E);
    idt_set_gate(13, (unsigned int)isr13, 0x08, 0x8E);
    idt_set_gate(14, (unsigned int)isr14, 0x08, 0x8E);
    idt_set_gate(15, (unsigned int)isr15, 0x08, 0x8E);
    idt_set_gate(16, (unsigned int)isr16, 0x08, 0x8E);
    idt_set_gate(17, (unsigned int)isr17, 0x08, 0x8E);
    idt_set_gate(18, (unsigned int)isr18, 0x08, 0x8E);
    idt_set_gate(19, (unsigned int)isr19, 0x08, 0x8E);
    idt_set_gate(20, (unsigned int)isr20, 0x08, 0x8E);
    idt_set_gate(21, (unsigned int)isr21, 0x08, 0x8E);
    idt_set_gate(22, (unsigned int)isr22, 0x08, 0x8E);
    idt_set_gate(23, (unsigned int)isr23, 0x08, 0x8E);
    idt_set_gate(24, (unsigned int)isr24, 0x08, 0x8E);
    idt_set_gate(25, (unsigned int)isr25, 0x08, 0x8E);
    idt_set_gate(26, (unsigned int)isr26, 0x08, 0x8E);
    idt_set_gate(27, (unsigned int)isr27, 0x08, 0x8E);
    idt_set_gate(28, (unsigned int)isr28, 0x08, 0x8E);
    idt_set_gate(29, (unsigned int)isr29, 0x08, 0x8E);
    idt_set_gate(30, (unsigned int)isr30, 0x08, 0x8E);
    idt_set_gate(31, (unsigned int)isr31, 0x08, 0x8E);

    /* Hardware IRQs (32-47) */
    idt_set_gate(32, (unsigned int)irq0,  0x08, 0x8E);
    idt_set_gate(33, (unsigned int)irq1,  0x08, 0x8E);
    idt_set_gate(34, (unsigned int)irq2,  0x08, 0x8E);
    idt_set_gate(35, (unsigned int)irq3,  0x08, 0x8E);
    idt_set_gate(36, (unsigned int)irq4,  0x08, 0x8E);
    idt_set_gate(37, (unsigned int)irq5,  0x08, 0x8E);
    idt_set_gate(38, (unsigned int)irq6,  0x08, 0x8E);
    idt_set_gate(39, (unsigned int)irq7,  0x08, 0x8E);
    idt_set_gate(40, (unsigned int)irq8,  0x08, 0x8E);
    idt_set_gate(41, (unsigned int)irq9,  0x08, 0x8E);
    idt_set_gate(42, (unsigned int)irq10, 0x08, 0x8E);
    idt_set_gate(43, (unsigned int)irq11, 0x08, 0x8E);
    idt_set_gate(44, (unsigned int)irq12, 0x08, 0x8E);
    idt_set_gate(45, (unsigned int)irq13, 0x08, 0x8E);
    idt_set_gate(46, (unsigned int)irq14, 0x08, 0x8E);
    idt_set_gate(47, (unsigned int)irq15, 0x08, 0x8E);

    /* Load IDT */
    __asm__ __volatile__("lidt (%0)" : : "r"(&idt_ptr));

    /* Enable interrupts */
    __asm__ __volatile__("sti");
}
