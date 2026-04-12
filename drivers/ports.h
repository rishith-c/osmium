/* ===========================================================================
 * ports.h - x86 I/O Port Access
 * ===========================================================================
 * Inline functions for reading/writing to hardware I/O ports.
 * Used by all hardware drivers (screen, keyboard, PIC, PIT, RTC, etc.).
 *
 * x86 CPUs have a separate I/O address space (0x0000-0xFFFF) accessed
 * with the IN and OUT instructions, distinct from memory addresses.
 * =========================================================================== */

#ifndef PORTS_H
#define PORTS_H

/* Read a byte from an I/O port */
static inline unsigned char inb(unsigned short port)
{
    unsigned char result;
    __asm__ __volatile__("inb %1, %0" : "=a"(result) : "Nd"(port));
    return result;
}

/* Write a byte to an I/O port */
static inline void outb(unsigned short port, unsigned char data)
{
    __asm__ __volatile__("outb %0, %1" : : "a"(data), "Nd"(port));
}

/* Read a 16-bit word from an I/O port */
static inline unsigned short inw(unsigned short port)
{
    unsigned short result;
    __asm__ __volatile__("inw %1, %0" : "=a"(result) : "Nd"(port));
    return result;
}

/* Small delay by writing to unused port (for hardware timing requirements) */
static inline void io_wait(void)
{
    outb(0x80, 0);
}

#endif /* PORTS_H */
