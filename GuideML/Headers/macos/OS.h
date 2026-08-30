#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <limits.h>

typedef uintptr_t addr_t;
typedef int32_t int32;
typedef uint32_t uint32;
typedef int64_t int64;
typedef uint64_t uint64;
typedef int16_t int16;
typedef uint16_t uint16;
typedef int8_t int8;
typedef uint8_t uint8;
typedef int32_t status_t;

#ifndef B_PAGE_SIZE
#define B_PAGE_SIZE 4096
#endif
#ifndef B_FULL_LOCK
#define B_FULL_LOCK 1
#endif

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

#ifndef B_OK
#define B_OK 0
#define B_ERROR (-1)
#define B_BAD_TYPE EINVAL
#define B_BAD_DATA EIO
#define B_BAD_INDEX EINVAL
#define B_NAME_NOT_FOUND ENOENT
#define B_BAD_VALUE EINVAL
#endif

#ifndef B_LENDIAN_TO_HOST_INT32
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#define B_LENDIAN_TO_HOST_INT32(x) (x)
#define B_BENDIAN_TO_HOST_INT32(x) __builtin_bswap32(x)
#define B_BENDIAN_TO_HOST_INT16(x) __builtin_bswap16(x)
#else
#define B_LENDIAN_TO_HOST_INT32(x) __builtin_bswap32(x)
#define B_BENDIAN_TO_HOST_INT32(x) (x)
#define B_BENDIAN_TO_HOST_INT16(x) (x)
#endif
#endif
