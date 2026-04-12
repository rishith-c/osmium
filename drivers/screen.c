/* ===========================================================================
 * screen.c - VGA Text Mode Screen Driver Implementation
 * ===========================================================================
 * Writes directly to VGA text buffer at 0xB8000.
 * Includes hardware cursor, backspace, scrolling, and color support.
 * =========================================================================== */

#include "screen.h"
#include "ports.h"

static volatile char *const VIDEO_MEMORY = (volatile char *)0xB8000;

#define VGA_SIZE (VGA_WIDTH * VGA_HEIGHT)

static int cursor_x = 0;
static int cursor_y = 0;
static unsigned char current_color = 0x0F;  /* White on black */

/* ---------------------------------------------------------------------------
 * update_hw_cursor - Sync the hardware blinking cursor with our position
 * ---------------------------------------------------------------------------
 * The VGA controller has its own cursor that blinks independently.
 * We write to CRT controller registers via I/O ports 0x3D4/0x3D5.
 * --------------------------------------------------------------------------- */
static void update_hw_cursor(void)
{
    unsigned short pos = (unsigned short)(cursor_y * VGA_WIDTH + cursor_x);

    /* Cursor position low byte (register 0x0F) */
    outb(0x3D4, 0x0F);
    outb(0x3D5, (unsigned char)(pos & 0xFF));

    /* Cursor position high byte (register 0x0E) */
    outb(0x3D4, 0x0E);
    outb(0x3D5, (unsigned char)((pos >> 8) & 0xFF));
}

/* ---------------------------------------------------------------------------
 * scroll - Scroll screen up by one line when cursor exceeds screen bounds
 * --------------------------------------------------------------------------- */
static void scroll(void)
{
    if (cursor_y < VGA_HEIGHT) {
        return;
    }

    int i;
    for (i = 0; i < (VGA_HEIGHT - 1) * VGA_WIDTH; i++) {
        VIDEO_MEMORY[i * 2]     = VIDEO_MEMORY[(i + VGA_WIDTH) * 2];
        VIDEO_MEMORY[i * 2 + 1] = VIDEO_MEMORY[(i + VGA_WIDTH) * 2 + 1];
    }

    for (i = (VGA_HEIGHT - 1) * VGA_WIDTH; i < VGA_SIZE; i++) {
        VIDEO_MEMORY[i * 2]     = ' ';
        VIDEO_MEMORY[i * 2 + 1] = current_color;
    }

    cursor_y = VGA_HEIGHT - 1;
}

void print_char(char c)
{
    if (c == '\n') {
        cursor_x = 0;
        cursor_y++;
    } else if (c == '\r') {
        cursor_x = 0;
    } else if (c == '\t') {
        cursor_x = (cursor_x + 8) & ~7;
        if (cursor_x >= VGA_WIDTH) {
            cursor_x = 0;
            cursor_y++;
        }
    } else if (c == '\b') {
        /* Backspace: move cursor back and erase character */
        if (cursor_x > 0) {
            cursor_x--;
        } else if (cursor_y > 0) {
            cursor_y--;
            cursor_x = VGA_WIDTH - 1;
        }
        int offset = (cursor_y * VGA_WIDTH + cursor_x) * 2;
        VIDEO_MEMORY[offset]     = ' ';
        VIDEO_MEMORY[offset + 1] = current_color;
    } else {
        int offset = (cursor_y * VGA_WIDTH + cursor_x) * 2;
        VIDEO_MEMORY[offset]     = c;
        VIDEO_MEMORY[offset + 1] = current_color;

        cursor_x++;
        if (cursor_x >= VGA_WIDTH) {
            cursor_x = 0;
            cursor_y++;
        }
    }

    scroll();
    update_hw_cursor();
}

void print_string(const char *str)
{
    int i;
    for (i = 0; str[i] != '\0'; i++) {
        print_char(str[i]);
    }
}

void print_string_color(const char *str, unsigned char color)
{
    unsigned char saved = current_color;
    current_color = color;
    print_string(str);
    current_color = saved;
}

void screen_clear(void)
{
    int i;
    for (i = 0; i < VGA_SIZE; i++) {
        VIDEO_MEMORY[i * 2]     = ' ';
        VIDEO_MEMORY[i * 2 + 1] = current_color;
    }
    cursor_x = 0;
    cursor_y = 0;
    update_hw_cursor();
}

void screen_set_color(unsigned char color)
{
    current_color = color;
}

unsigned char screen_get_color(void)
{
    return current_color;
}

int screen_get_cursor_x(void)
{
    return cursor_x;
}

int screen_get_cursor_y(void)
{
    return cursor_y;
}

void screen_set_cursor(int x, int y)
{
    cursor_x = x;
    cursor_y = y;
    update_hw_cursor();
}
