/* ===========================================================================
 * string.c - String Utilities Implementation
 * =========================================================================== */

#include "string.h"

int strlen(const char *str)
{
    int len = 0;
    while (str[len] != '\0') {
        len++;
    }
    return len;
}

int strcmp(const char *a, const char *b)
{
    while (*a && *a == *b) {
        a++;
        b++;
    }
    return *(unsigned char *)a - *(unsigned char *)b;
}

int strncmp(const char *a, const char *b, int n)
{
    int i;
    for (i = 0; i < n; i++) {
        if (a[i] != b[i] || a[i] == '\0') {
            return (unsigned char)a[i] - (unsigned char)b[i];
        }
    }
    return 0;
}

char *strcpy(char *dest, const char *src)
{
    char *d = dest;
    while (*src) {
        *d++ = *src++;
    }
    *d = '\0';
    return dest;
}

char *strncpy(char *dest, const char *src, int n)
{
    int i;
    for (i = 0; i < n - 1 && src[i] != '\0'; i++) {
        dest[i] = src[i];
    }
    dest[i] = '\0';
    return dest;
}

char *strchr(const char *str, int c)
{
    while (*str) {
        if (*str == (char)c) {
            return (char *)str;
        }
        str++;
    }
    if (c == '\0') {
        return (char *)str;
    }
    return 0;
}

char *itoa(int value, char *buf)
{
    char tmp[12];
    int i = 0;
    int negative = 0;

    if (value == 0) {
        buf[0] = '0';
        buf[1] = '\0';
        return buf;
    }

    if (value < 0) {
        negative = 1;
        value = -value;
    }

    while (value > 0) {
        tmp[i++] = '0' + (value % 10);
        value /= 10;
    }

    int j = 0;
    if (negative) {
        buf[j++] = '-';
    }

    /* Reverse the digits */
    while (i > 0) {
        buf[j++] = tmp[--i];
    }
    buf[j] = '\0';

    return buf;
}

int atoi(const char *str)
{
    int result = 0;
    int negative = 0;

    /* Skip whitespace */
    while (is_space(*str)) {
        str++;
    }

    /* Handle sign */
    if (*str == '-') {
        negative = 1;
        str++;
    } else if (*str == '+') {
        str++;
    }

    /* Convert digits */
    while (is_digit(*str)) {
        result = result * 10 + (*str - '0');
        str++;
    }

    return negative ? -result : result;
}

int is_digit(char c)
{
    return c >= '0' && c <= '9';
}

int is_alpha(char c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

int is_space(char c)
{
    return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

char to_upper(char c)
{
    if (c >= 'a' && c <= 'z') {
        return c - 32;
    }
    return c;
}
