/* ===========================================================================
 * memory.c - Basic Memory Operations Implementation
 * =========================================================================== */

#include "memory.h"

void *memset(void *dest, int val, size_t count)
{
    unsigned char *d = (unsigned char *)dest;
    size_t i;
    for (i = 0; i < count; i++) {
        d[i] = (unsigned char)val;
    }
    return dest;
}

void *memcpy(void *dest, const void *src, size_t count)
{
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    size_t i;
    for (i = 0; i < count; i++) {
        d[i] = s[i];
    }
    return dest;
}
