/* ===========================================================================
 * memory.h - Basic Memory Operations
 * ===========================================================================
 * Minimal memory utilities needed by the kernel since we can't use libc.
 * =========================================================================== */

#ifndef MEMORY_H
#define MEMORY_H

typedef unsigned int size_t;

/* Fill memory with a byte value */
void *memset(void *dest, int val, size_t count);

/* Copy memory from source to destination */
void *memcpy(void *dest, const void *src, size_t count);

#endif /* MEMORY_H */
