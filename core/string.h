/* ===========================================================================
 * string.h - String Utilities
 * ===========================================================================
 * Basic string functions since we can't use libc's <string.h>.
 * =========================================================================== */

#ifndef STRING_H
#define STRING_H

#include "memory.h"

/* Get length of null-terminated string */
int strlen(const char *str);

/* Compare two strings. Returns 0 if equal. */
int strcmp(const char *a, const char *b);

/* Compare first n characters. Returns 0 if equal. */
int strncmp(const char *a, const char *b, int n);

/* Copy src into dest. Returns dest. */
char *strcpy(char *dest, const char *src);

/* Copy up to n characters. Always null-terminates. */
char *strncpy(char *dest, const char *src, int n);

/* Find first occurrence of character. Returns pointer or 0. */
char *strchr(const char *str, int c);

/* Convert integer to decimal string. Returns dest. */
char *itoa(int value, char *buf);

/* Convert string to integer */
int atoi(const char *str);

/* Check if character is a digit */
int is_digit(char c);

/* Check if character is a letter */
int is_alpha(char c);

/* Check if character is whitespace */
int is_space(char c);

/* Convert character to uppercase */
char to_upper(char c);

#endif /* STRING_H */
