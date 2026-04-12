/* ===========================================================================
 * timer.h - Programmable Interval Timer (PIT) Driver
 * ===========================================================================
 * The PIT (Intel 8253/8254) generates periodic interrupts (IRQ 0).
 * We configure it to fire at 100 Hz (every 10ms) for timekeeping.
 * =========================================================================== */

#ifndef TIMER_H
#define TIMER_H

/* Get the number of ticks since boot (each tick = 10ms at 100 Hz) */
unsigned int timer_get_ticks(void);

/* Get uptime in seconds */
unsigned int timer_get_uptime(void);

/* Initialize the PIT at the given frequency (Hz) */
void timer_init(unsigned int frequency);

#endif /* TIMER_H */
