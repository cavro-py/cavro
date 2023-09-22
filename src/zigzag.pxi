from libc.stdint cimport *

cdef uint32_t read_varint(Reader buf) except? 0xfffffbad:
    cdef uint32_t cur
    cdef uint32_t shift = 0
    cdef uint32_t value = 0
    while True:
        cur = buf.read_u8()
        value |= (cur & 0b01111111) << shift
        shift += 7
        if not cur & 0b10000000:
            return value


cdef uint64_t read_varlong(Reader buf) except? 0xfffffffffffffbadull:
    cdef uint64_t cur
    cdef uint64_t shift = 0
    cdef uint64_t value = 0
    while True:
        cur = buf.read_u8()
        value |= (cur & 0b01111111) << shift
        shift += 7
        if not cur & 0b10000000:
            return value


cdef int32_t zigzag_decode_int(Reader buf) except? 0x7ffffbadu:
    cdef uint32_t value = read_varint(buf)
    return (value >> 1) ^ (-(value & 1))


cdef int64_t zigzag_decode_long(Reader buf) except? 0x7ffffffffffffbadull:
    cdef uint64_t value = read_varlong(buf)
    return (value >> 1) ^ (-(value & 1ull))

@cython.cdivision(True)
cdef int zigzag_encode_int(Writer buf, int32_t value) except -1:
    cdef uint32_t zz = (value << 1) ^ (value >> 31)
    cdef uint8_t cur
    if zz == 0:
        buf.write_u8(0)
    while zz:
        cur = zz & 0x7f
        zz >>= 7
        if zz:
            cur |= 0x80
        buf.write_u8(cur)

@cython.cdivision(True)
cdef int zigzag_encode_long(Writer buf, int64_t value) except -1:
    cdef uint64_t zz = (value << 1) ^ (value >> 63)
    cdef uint8_t cur
    if zz == 0:
        buf.write_u8(0)
    while zz:
        cur = zz & 0b01111111
        zz >>= 7
        if zz:
            cur |= 0b10000000
        buf.write_u8(cur)
