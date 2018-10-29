from libc.stdint cimport *

cdef extern from "bmi.h":
    uint32_t _pdep_pack_7_8u(uint32_t, uint8_t)
    uint32_t _sw_pack_7_8u(uint32_t, uint8_t)

    uint32_t pack_7_8u(uint32_t, uint8_t)

    uint64_t _pdep_pack_7_8ull(uint64_t, uint8_t)
    uint64_t _sw_pack_7_8ull(uint64_t, uint8_t)

    uint64_t pack_7_8ull(uint64_t, uint8_t)

    int count_pack_bits(uint32_t)
    int count_pack_bits_ull(uint64_t)
    void bmi2_detect()

bmi2_detect()

cdef extern from 'stdlib.h':
    long llabs(long)
    int abs(int)

    int __builtin_clz(uint32_t)
    int __builtin_clzll(uint64_t)

cdef uint32_t read_varint(MemoryReader buf) except? 0xfffffbad:
    cdef uint32_t start = buf.read_to32()
    cdef int n_bytes = count_pack_bits(start)
    cdef uint32_t value
    cdef uint8_t rest
    if n_bytes < 5:
        buf.advance(n_bytes)
        return pack_7_8u(start, n_bytes)
    else:
        buf.advance(4)
        rest = buf.read8()
        return pack_7_8u(start, n_bytes) | ((rest & 0x0f) << 28)


cdef uint64_t read_varlong(MemoryReader buf) except? 0xfffffffffffffbadull:
    cdef uint64_t start = buf.read_to64()
    cdef uint64_t rest
    cdef int n_bytes = count_pack_bits_ull(start)
    cdef uint64_t value
    if n_bytes < 9:
        buf.advance(n_bytes)
        return pack_7_8ull(start, n_bytes)
    else:
        buf.advance(8)
        rest = buf.read_to16()
        buf.advance(2 if rest & 0x80 else 1)
        return pack_7_8ull(start, n_bytes) | ((rest & 0xFF) << 56)


cdef int32_t zigzag_decode_int(MemoryReader buf) except? 0x7ffffbadu:
    cdef uint32_t value = read_varint(buf)
    return (value >> 1) ^ (-(value & 1))


cdef int64_t zigzag_decode_long(MemoryReader buf) except? 0x7ffffffffffffbadull:
    cdef uint64_t value = read_varlong(buf)
    return (value >> 1) ^ (-(value & 1ull))

@cython.cdivision(True)
cdef int zigzag_encode_int(MemoryWriter buf, int32_t value) except -1:
    cdef bint negative = value < 0
    cdef uint32_t raw = abs(value)
    raw = (raw << 1) - negative
    if raw < 0x80:
        return buf.write8(raw)
    cdef int n_continuations = (32 - __builtin_clz(raw)) // 7
    cdef int n_bytes = n_continuations + 1
    cdef uint64_t mask = ~(1ull << (n_bytes * 4) << ((n_bytes * 4) - 1ul))
    buf.write_to64(
        (0x80808080ull
        | raw & 0x7f
        | ((raw & 0x3f80) << 1)
        | ((raw & 0x1fc000) << 2)
        | ((raw & 0xfe00000) << 3)
        | ((raw & 0xf0000000ull) << 4)
        ) & mask,
        n_continuations+1
    )

@cython.cdivision(True)
cdef int zigzag_encode_long(MemoryWriter buf, long value) except -1:
    cdef bint negative = value < 0
    cdef unsigned long raw = llabs(value)
    raw = (raw << 1) - negative
    if raw < 0x80:
        return buf.write8(raw)
    cdef int n_continuations = (63 - __builtin_clzll(raw)) // 7
    cdef int n_bytes = n_continuations + 1
    cdef uint64_t mask = ~(1ull << (n_bytes * 4) << ((n_bytes * 4) - 1ul))
    buf.write_to64(
        (0x8080808080808080ull
        | raw & 0x7f
        | ((raw & 0x3f80) << 1)
        | ((raw & 0x1fc000) << 2)
        | ((raw & 0xfe00000) << 3)
        | ((raw & 0x7f0000000ull) << 4)
        | ((raw & 0x3f800000000ull) << 5)
        | ((raw & 0x1fc0000000000ull) << 6)
        | ((raw & 0xfe000000000000ull) << 7)
        ) & mask,
        min(n_bytes, 8)
    )
    if n_continuations == 8:
        buf.write_to64(
            ((raw & 0x7f00000000000000ull) >> 56),
            1
        )
    elif n_continuations == 9:
        buf.write_to64(
            0x80ull
            | ((raw & 0x7f00000000000000ull) >> 56)
            | ((raw & 0x8000000000000000ull) >> 55),
            2
        )
