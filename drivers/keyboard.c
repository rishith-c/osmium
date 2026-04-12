/* ===========================================================================
 * keyboard.c - PS/2 Keyboard Driver Implementation
 * ===========================================================================
 * The keyboard controller sends scancodes via IRQ 1. We read the scancode
 * from I/O port 0x60, convert it to ASCII using a lookup table, and store
 * the result in a ring buffer.
 *
 * Scancode Set 1 (default on most PCs):
 *   "Make" codes are sent on key press (0x01 - 0x58)
 *   "Break" codes are sent on key release (make code | 0x80)
 *
 * We track modifier key state (Shift, Caps Lock) for proper character mapping.
 * =========================================================================== */

#include "keyboard.h"
#include "ports.h"
#include "isr.h"

/* Keyboard data port */
#define KB_DATA_PORT 0x60

/* Ring buffer for typed characters */
#define KB_BUFFER_SIZE 256
static char kb_buffer[KB_BUFFER_SIZE];
static volatile int kb_read_pos  = 0;
static volatile int kb_write_pos = 0;

/* Modifier state */
static int shift_held = 0;
static int caps_lock  = 0;

/* ---------------------------------------------------------------------------
 * Scancode-to-ASCII lookup tables (US QWERTY layout)
 * ---------------------------------------------------------------------------
 * Index = scancode, value = ASCII character (0 = no mapping)
 * --------------------------------------------------------------------------- */

/* Normal (unshifted) characters */
static const char scancode_to_ascii[128] = {
    0,  27, '1','2','3','4','5','6','7','8','9','0','-','=', '\b',
    '\t','q','w','e','r','t','y','u','i','o','p','[',']','\n',
    0,  'a','s','d','f','g','h','j','k','l',';','\'','`',
    0,  '\\','z','x','c','v','b','n','m',',','.','/',  0,
    '*', 0, ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,  0,  0, '-', 0,  0,  0, '+', 0, 0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0
};

/* Shifted characters */
static const char scancode_to_ascii_shift[128] = {
    0,  27, '!','@','#','$','%','^','&','*','(',')','_','+', '\b',
    '\t','Q','W','E','R','T','Y','U','I','O','P','{','}','\n',
    0,  'A','S','D','F','G','H','J','K','L',':','"','~',
    0,  '|','Z','X','C','V','B','N','M','<','>','?',  0,
    '*', 0, ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,  0,  0, '-', 0,  0,  0, '+', 0, 0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0
};

/* Scancode constants for modifier keys */
#define SC_LSHIFT_PRESS   0x2A
#define SC_LSHIFT_RELEASE 0xAA
#define SC_RSHIFT_PRESS   0x36
#define SC_RSHIFT_RELEASE 0xB6
#define SC_CAPSLOCK       0x3A

/* ---------------------------------------------------------------------------
 * kb_buffer_put - Add a character to the ring buffer
 * --------------------------------------------------------------------------- */
static void kb_buffer_put(char c)
{
    int next = (kb_write_pos + 1) % KB_BUFFER_SIZE;
    if (next != kb_read_pos) {
        kb_buffer[kb_write_pos] = c;
        kb_write_pos = next;
    }
    /* If buffer is full, character is dropped */
}

/* ---------------------------------------------------------------------------
 * keyboard_callback - IRQ 1 handler
 * ---------------------------------------------------------------------------
 * Called every time a key is pressed or released. Reads the scancode,
 * updates modifier state, and converts to ASCII for the ring buffer.
 * --------------------------------------------------------------------------- */
static void keyboard_callback(registers_t *regs)
{
    (void)regs;

    unsigned char scancode = inb(KB_DATA_PORT);

    /* Handle modifier keys */
    switch (scancode) {
        case SC_LSHIFT_PRESS:
        case SC_RSHIFT_PRESS:
            shift_held = 1;
            return;

        case SC_LSHIFT_RELEASE:
        case SC_RSHIFT_RELEASE:
            shift_held = 0;
            return;

        case SC_CAPSLOCK:
            caps_lock = !caps_lock;
            return;
    }

    /* Ignore break codes (key release) for non-modifier keys */
    if (scancode & 0x80) {
        return;
    }

    /* Look up the ASCII character */
    char c;
    if (shift_held) {
        c = scancode_to_ascii_shift[scancode];
    } else {
        c = scancode_to_ascii[scancode];
    }

    /* Apply caps lock to letters */
    if (caps_lock && c >= 'a' && c <= 'z') {
        c -= 32;  /* To uppercase */
    } else if (caps_lock && c >= 'A' && c <= 'Z' && shift_held) {
        c += 32;  /* Shift + Caps Lock = lowercase */
    }

    /* Store valid characters in the buffer */
    if (c != 0) {
        kb_buffer_put(c);
    }
}

/* ---------------------------------------------------------------------------
 * keyboard_getchar - Read a character (blocks until available)
 * ---------------------------------------------------------------------------
 * Uses HLT instruction to sleep between interrupt checks, saving CPU.
 * --------------------------------------------------------------------------- */
char keyboard_getchar(void)
{
    while (kb_read_pos == kb_write_pos) {
        __asm__ __volatile__("hlt");
    }

    char c = kb_buffer[kb_read_pos];
    kb_read_pos = (kb_read_pos + 1) % KB_BUFFER_SIZE;
    return c;
}

/* ---------------------------------------------------------------------------
 * keyboard_has_char - Check if input is available
 * --------------------------------------------------------------------------- */
int keyboard_has_char(void)
{
    return kb_read_pos != kb_write_pos;
}

/* ---------------------------------------------------------------------------
 * keyboard_peek - Look at the next character without consuming it
 * --------------------------------------------------------------------------- */
char keyboard_peek(void)
{
    if (kb_read_pos == kb_write_pos) {
        return 0;
    }
    return kb_buffer[kb_read_pos];
}

/* ---------------------------------------------------------------------------
 * keyboard_init - Install the keyboard IRQ handler
 * --------------------------------------------------------------------------- */
void keyboard_init(void)
{
    irq_install_handler(1, keyboard_callback);
}
