cimport cython
from cpython.object cimport Py_SIZE
from libc.stdint cimport *

from cpython cimport array
import array


cdef array.array byte_buffer_template = array.array('B', [])

@cython.final
cdef class MemoryBuffer:

    cdef readonly array.array buffer
    cdef size_t cur_pos
    cdef int leased

    def __init__(self, initial_size=4096):
        self.buffer = array.clone(byte_buffer_template, initial_size, zero=True)
        self.cur_pos = 0
        self.leased = False

    cdef bytes bytes(self):
        return self.buffer.data.as_chars[:self.cur_pos]

    cdef reset(self):
        self.cur_pos = 0

    cdef void write8(self, uint8_t val):
        if self.buffer.ob_size - self.cur_pos < 1:
            array.resize_smart(self.buffer, self.cur_pos + 1)
        self.buffer.data.as_uchars[self.cur_pos] = val
        self.cur_pos += 1

    cdef void write16(self, uint16_t val):
        if self.buffer.ob_size - self.cur_pos < 2:
            array.resize_smart(self.buffer, self.cur_pos + 2)
        cdef uint16_t *dest = <uint16_t*>&self.buffer.data.as_uchars[self.cur_pos]
        dest[0] = val
        self.cur_pos += 2

    cdef void write24(self, uint32_t val):
        if self.buffer.ob_size - self.cur_pos < 4:
            array.resize_smart(self.buffer, self.cur_pos + 4)
        cdef uint32_t *dest = <uint32_t*>&self.buffer.data.as_uchars[self.cur_pos]
        dest[0] = val
        self.cur_pos += 3

    cdef void write32(self, uint32_t val):
        if self.buffer.ob_size - self.cur_pos < 4:
            array.resize_smart(self.buffer, self.cur_pos + 4)
        cdef uint32_t *dest = <uint32_t*>&self.buffer.data.as_uchars[self.cur_pos]
        dest[0] = val
        self.cur_pos += 4

    cdef void write40(self, uint64_t val):
        if self.buffer.ob_size - self.cur_pos < 8:
            array.resize_smart(self.buffer, self.cur_pos + 8)
        cdef uint64_t *dest = <uint64_t*>&self.buffer.data.as_uchars[self.cur_pos]
        dest[0] = val
        self.cur_pos += 5

    cdef void write48(self, uint64_t val):
        if self.buffer.ob_size - self.cur_pos < 8:
            array.resize_smart(self.buffer, self.cur_pos + 8)
        cdef uint64_t *dest = <uint64_t*>&self.buffer.data.as_uchars[self.cur_pos]
        dest[0] = val
        self.cur_pos += 6

    cdef void write56(self, uint64_t val):
        if self.buffer.ob_size - self.cur_pos < 8:
            array.resize_smart(self.buffer, self.cur_pos + 8)
        cdef uint64_t *dest = <uint64_t*>&self.buffer.data.as_uchars[self.cur_pos]
        dest[0] = val
        self.cur_pos += 7

    cdef void write64(self, uint64_t val):
        if self.buffer.ob_size - self.cur_pos < 8:
            array.resize_smart(self.buffer, self.cur_pos + 8)
        cdef uint64_t *dest = <uint64_t*>&self.buffer.data.as_uchars[self.cur_pos]
        dest[0] = val
        self.cur_pos += 8