
from libc.stdint cimport *

cdef extern from 'stdlib.h':
    long llabs(long)
    int abs(int)

    int __builtin_clz(uint32_t)
    int __builtin_clzll(uint64_t)

cdef void zigzag_encode_int(MemoryBuffer buf, int32_t value):
    if value == 0:
        buf.write8(0)
        return
    cdef bint negative = value < 0
    cdef uint32_t raw = abs(value)
    raw = (raw << 1) - negative
    cdef int bit_pos = 32 - __builtin_clz(raw)
    if bit_pos < 8:
        buf.write8(raw)
    elif bit_pos < 15:
        buf.write16(0x80 | (raw & 0x7f) | ((raw & 0x3f80) << 1))
    elif bit_pos < 22:
        buf.write24(
            0x8080
            | (raw & 0x7f)
            | ((raw & 0x3f80) << 1)
            | ((raw & 0x1FC000) << 2)
        )
    elif bit_pos < 29:
        buf.write32(
            0x808080
            | (raw & 0x7f)
            | ((raw & 0x3f80) << 1)
            | ((raw & 0x1FC000) << 2)
            | ((raw & 0xFE00000) << 3)
        )
    else:
        buf.write40(
            0x80808080ul
            | (raw & 0x7F)
            | ((raw & 0x3F80) << 1)
            | ((raw & 0x1FC000) << 2)
            | ((raw & 0xFE00000) << 3)
            | ((raw & 0x7f0000000ul) << 4)
        )

cdef void zigzag_encode_long(MemoryBuffer buf, long value):
    if value == 0:
        buf.write8(0)
        return
    cdef bint negative = value < 0
    cdef unsigned long raw = llabs(value)
    raw = (raw << 1) - negative
    cdef int bit_pos = 64 - __builtin_clzll(raw)
    if bit_pos < 8:
        buf.write8(raw & 0x7f)
    elif bit_pos < 15:
        buf.write16(
            0x80ul
            | raw & 0x7f
            | ((raw & 0x3f80) << 1)
        )
    elif bit_pos < 22:
        buf.write24(
            0x8080ul
            | raw & 0x7f
            | ((raw & 0x3f80) << 1)
            | ((raw & 0x1fc000) << 2)
        )
    elif bit_pos < 29:
        buf.write32(
            0x808080ul
            | raw & 0x7f
            | ((raw & 0x3f80) << 1)
            | ((raw & 0x1fc000) << 2)
            | ((raw & 0xfe00000) << 3)
        )
    elif bit_pos < 36:
        buf.write40(
            0x80808080ul
            | raw & 0x7f
            | ((raw & 0x3f80) << 1)
            | ((raw & 0x1fc000) << 2)
            | ((raw & 0xfe00000) << 3)
            | ((raw & 0x7f0000000ull) << 4)
        )
    elif bit_pos < 43:
        buf.write48(
            0x8080808080ul
            | raw & 0x7f
            | ((raw & 0x3f80) << 1)
            | ((raw & 0x1fc000) << 2)
            | ((raw & 0xfe00000) << 3)
            | ((raw & 0x7f0000000ull) << 4)
            | ((raw & 0x3f800000000ull) << 5)
        )
    elif bit_pos < 50:
        buf.write56(
            0x808080808080ul
            | raw & 0x7f
            | ((raw & 0x3f80) << 1)
            | ((raw & 0x1fc000) << 2)
            | ((raw & 0xfe00000) << 3)
            | ((raw & 0x7f0000000ull) << 4)
            | ((raw & 0x3f800000000ull) << 5)
            | ((raw & 0x1fc0000000000ull) << 6)
        )
    elif bit_pos < 57:
        buf.write64(
            0x80808080808080ul
            | raw & 0x7f
            | ((raw & 0x3f80) << 1)
            | ((raw & 0x1fc000) << 2)
            | ((raw & 0xfe00000) << 3)
            | ((raw & 0x7f0000000ull) << 4)
            | ((raw & 0x3f800000000ull) << 5)
            | ((raw & 0x1fc0000000000ull) << 6)
            | ((raw & 0xfe000000000000ull) << 7)
        )
    elif bit_pos < 64:
        buf.write64(
            0x8080808080808080ul
            | raw & 0x7f
            | ((raw & 0x3f80) << 1)
            | ((raw & 0x1fc000) << 2)
            | ((raw & 0xfe00000) << 3)
            | ((raw & 0x7f0000000ull) << 4)
            | ((raw & 0x3f800000000ull) << 5)
            | ((raw & 0x1fc0000000000ull) << 6)
            | ((raw & 0xfe000000000000ull) << 7)
        )
        buf.write8(
            ((raw & 0x7f00000000000000ull) >> 56)
        )
    else:
        buf.write64(
            0x8080808080808080ul
            | raw & 0x7f
            | ((raw & 0x3f80) << 1)
            | ((raw & 0x1fc000) << 2)
            | ((raw & 0xfe00000) << 3)
            | ((raw & 0x7f0000000ull) << 4)
            | ((raw & 0x3f800000000ull) << 5)
            | ((raw & 0x1fc0000000000ull) << 6)
            | ((raw & 0xfe000000000000ull) << 7)
        )
        buf.write16(
            0x80ull
            | ((raw & 0x7f00000000000000ull) >> 56)
            | ((raw & 0x8000000000000000ull) >> 55)
        )
