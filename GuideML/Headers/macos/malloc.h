#pragma once

#include <stdlib.h>

static inline void *memalign(size_t alignment, size_t size) {
    void *pointer = NULL;
    if (posix_memalign(&pointer, alignment, size) != 0) {
        return NULL;
    }
    return pointer;
}
