/* ===========================================================================
 * timer.c - PIT Timer Driver Implementation
 * ===========================================================================
 * Configures the Programmable Interval Timer (PIT) channel 0 to generate
 * periodic interrupts. The PIT oscillates at 1,193,182 Hz. We divide this
 * by our desired frequency to get the reload value.
 *
 * PIT ports:
 *   0x40 - Channel 0 data (connected to IRQ 0)
 *   0x43 - Command register
 * =========================================================================== */

#include "timer.h"
#include "ports.h"
#include "isr.h"

/* PIT base frequency */
#define PIT_FREQUENCY 1193182

/* Tick counter (incremented every IRQ 0) */
static volatile unsigned int ticks = 0;

/* Configured frequency for uptime calculation */
static unsigned int timer_freq = 100;

/* ---------------------------------------------------------------------------
 * timer_callback - IRQ 0 handler, called every tick
 * --------------------------------------------------------------------------- */
static void timer_callback(registers_t *regs)
{
    (void)regs;  /* Unused */
    ticks++;
}

unsigned int timer_get_ticks(void)
{
    return ticks;
}

unsigned int timer_get_uptime(void)
{
    return ticks / timer_freq;
}

/* ---------------------------------------------------------------------------
 * timer_init - Configure the PIT and install the IRQ handler
 * ---------------------------------------------------------------------------
 * frequency: desired tick rate in Hz (e.g., 100 for 10ms ticks)
 * --------------------------------------------------------------------------- */
void timer_init(unsigned int frequency)
{
    timer_freq = frequency;

    /* Calculate divisor */
    unsigned int divisor = PIT_FREQUENCY / frequency;

    /* Command: channel 0, lobyte/hibyte access, rate generator, binary */
    outb(0x43, 0x36);

    /* Send divisor (low byte first, then high byte) */
    outb(0x40, (unsigned char)(divisor & 0xFF));
    outb(0x40, (unsigned char)((divisor >> 8) & 0xFF));

    /* Register our callback for IRQ 0 */
    irq_install_handler(0, timer_callback);
}
