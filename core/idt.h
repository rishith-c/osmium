/* ===========================================================================
 * idt.h - Interrupt Descriptor Table
 * ===========================================================================
 * The IDT tells the CPU where to find handler functions for each interrupt.
 * There are 256 possible interrupt vectors (0-255):
 *   0-31:   CPU exceptions (divide by zero, page fault, etc.)
 *   32-47:  Hardware IRQs (remapped from 0-15 by PIC initialization)
 *   48-255: Software interrupts (available for system calls, etc.)
 * =========================================================================== */

#ifndef IDT_H
#define IDT_H

#include "memory.h"

/* IDT entry (gate descriptor) - 8 bytes each */
typedef struct {
    unsigned short offset_low;   /* Lower 16 bits of handler address */
    unsigned short selector;     /* Kernel code segment selector (0x08) */
    unsigned char  zero;         /* Always 0 */
    unsigned char  type_attr;    /* Type and attributes (P, DPL, gate type) */
    unsigned short offset_high;  /* Upper 16 bits of handler address */
} __attribute__((packed)) idt_entry_t;

/* IDT pointer structure (loaded by LIDT instruction) */
typedef struct {
    unsigned short limit;        /* Size of IDT minus 1 */
    unsigned int   base;         /* Base address of IDT */
} __attribute__((packed)) idt_ptr_t;

/* Total number of IDT entries */
#define IDT_ENTRIES 256

/* Set a single IDT entry */
void idt_set_gate(int num, unsigned int handler, unsigned short selector,
                  unsigned char flags);

/* Initialize the IDT and load it */
void idt_init(void);

#endif /* IDT_H */
