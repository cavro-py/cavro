cimport cython
from libc.stdint cimport *

cdef int64_t RABIN_EMPTY = 0xc15d213aa4d7a795L

cdef int64_t RABIN_TABLE[256]
cdef bint RABIN_TABLE_CONFIGURED = 0


cdef init_rabin_table():
    global RABIN_TABLE_CONFIGURED
    cdef size_t i, j
    cdef int64_t mask;
    cdef int64_t value
    for i in range(256):
        value = i
        for j in range(8):
            mask = -(value & 0x1);
            value = <int64_t>((<uint64_t>value >> 1) ^ (RABIN_EMPTY & mask));
        RABIN_TABLE[i] = value
    RABIN_TABLE_CONFIGURED = 1


@cython.final
cdef class Rabin:

    """
    An implementation of the 64-bit Rabin hash function  as described in the avro specification.

    The interface in this class roughly approximates the `hashlib.hash` objects.
    """

    name = 'rabin'
    digest_size = 8
    block_size = 8

    cdef readonly int64_t value

    def __init__(self, value=RABIN_EMPTY):
        if not RABIN_TABLE_CONFIGURED:
            init_rabin_table()
        self.value = value
    
    cpdef update(self, bytes data):
        cdef int64_t swizzle
        cdef int64_t shifted
        for char in data:
            swizzle = RABIN_TABLE[(self.value ^ char) & 0xff]
            shifted = <int64_t>(<uint64_t>self.value >> 8)
            self.value = shifted ^ swizzle

    def digest(self):
        cdef uint64_t value = self.value
        return int(value).to_bytes(8, 'little', signed=False)

    def hexdigest(self):
        return self.digest().hex()

    def copy(self):
        new_ver = Rabin()
        new_ver.value = self.value
        return new_ver
