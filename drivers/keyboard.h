/* ===========================================================================
 * keyboard.h - PS/2 Keyboard Driver
 * ===========================================================================
 * Handles keyboard input via IRQ 1. Converts scancodes to ASCII and
 * stores them in a ring buffer for the shell to read.
 * =========================================================================== */

#ifndef KEYBOARD_H
#define KEYBOARD_H

/* Initialize the keyboard driver (installs IRQ 1 handler) */
void keyboard_init(void);

/* Read a single character (blocks until a key is pressed) */
char keyboard_getchar(void);

/* Check if a character is available without blocking */
int keyboard_has_char(void);

/* Peek at the next character without consuming it */
char keyboard_peek(void);

#endif /* KEYBOARD_H */
