/* ===========================================================================
 * screen.h - VGA Text Mode Screen Driver
 * ===========================================================================
 * Interface for writing to the VGA text buffer at 0xB8000.
 * Now includes hardware cursor support and backspace handling.
 * =========================================================================== */

#ifndef SCREEN_H
#define SCREEN_H

/* Screen dimensions */
#define VGA_WIDTH  80
#define VGA_HEIGHT 25

/* Color constants (4-bit values) */
#define COLOR_BLACK         0x0
#define COLOR_BLUE          0x1
#define COLOR_GREEN         0x2
#define COLOR_CYAN          0x3
#define COLOR_RED           0x4
#define COLOR_MAGENTA       0x5
#define COLOR_BROWN         0x6
#define COLOR_LIGHT_GREY    0x7
#define COLOR_DARK_GREY     0x8
#define COLOR_LIGHT_BLUE    0x9
#define COLOR_LIGHT_GREEN   0xA
#define COLOR_LIGHT_CYAN    0xB
#define COLOR_LIGHT_RED     0xC
#define COLOR_LIGHT_MAGENTA 0xD
#define COLOR_YELLOW        0xE
#define COLOR_WHITE         0xF

/* Make a color attribute byte: (bg << 4) | fg */
#define MAKE_COLOR(fg, bg) (((bg) << 4) | (fg))

/* Clear the screen and reset cursor */
void screen_clear(void);

/* Print a single character (handles \n, \r, \t, \b) */
void print_char(char c);

/* Print a null-terminated string */
void print_string(const char *str);

/* Print a string with a specific color */
void print_string_color(const char *str, unsigned char color);

/* Set the default color */
void screen_set_color(unsigned char color);

/* Get the current default color */
unsigned char screen_get_color(void);

/* Get the current cursor column (0-79) */
int screen_get_cursor_x(void);

/* Get the current cursor row (0-24) */
int screen_get_cursor_y(void);

/* Set cursor position */
void screen_set_cursor(int x, int y);

#endif /* SCREEN_H */
