cimport cython
from cpython.object cimport Py_SIZE
from libc.stdint cimport *

from cpython cimport array
import array

from libc.string cimport memcpy

include "tests/test_buffer.pxi"

cdef array.array byte_buffer_template = array.array('B', [])

@cython.final
cdef class MemoryWriter:

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

    cdef void writeN(self, size_t num, char *bytes):
        if self.buffer.ob_size - self.cur_pos < num:
            array.resize_smart(self.buffer, self.cur_pos + num)
        memcpy(self.buffer.data.as_chars + self.cur_pos, bytes, num)
        self.cur_pos += num


@cython.final
cdef class MemoryReader:

    cdef bytes data
    cdef const uint8_t[:] data_view
    cdef size_t length
    cdef size_t cur_pos

    def __init__(self, bytes data):
        self.data = data
        self.data_view = data
        self.length = len(self.data_view)
        self.cur_pos = 0

    cdef inline int ensure(self, size_t num) except -1:
        if self.length - self.cur_pos < num:
            raise ValueError("Not enough input data to read value")

    cdef uint8_t read8(self) except? 255:
        self.ensure(1)
        cdef uint8_t value = self.data[self.cur_pos]
        self.cur_pos += 1
        return value

    cdef uint32_t read_to32(self)  except? 0xfffffffe:
        cdef uint32_t result
        cdef size_t remaining = self.length - self.cur_pos
        if remaining == 0:
            raise ValueError("Not enough input data to read value")
        elif remaining == 1:
            result = self.data_view[self.cur_pos]
            self.cur_pos += 1
        elif remaining == 2:
            result = (
                self.data_view[self.cur_pos]
                | (self.data_view[self.cur_pos + 1] << 8)
            )
            self.cur_pos += 2
        elif remaining == 3:
            result = (
                self.data_view[self.cur_pos]
                | (self.data_view[self.cur_pos + 1] << 8)
                | (self.data_view[self.cur_pos + 2] << 16)
            )
            self.cur_pos += 3
        else:
            result = (
                self.data_view[self.cur_pos]
                | (self.data_view[self.cur_pos + 1] << 8)
                | (self.data_view[self.cur_pos + 2] << 16)
                | (self.data_view[self.cur_pos + 3] << 24)
            )
            self.cur_pos += 4
        return result

    cdef const uint8_t[:] read_n(self, size_t n):
        self.ensure(n)
        cdef const uint8_t[:] val = self.data_view[self.cur_pos:self.cur_pos + n]
        self.cur_pos += n
        return val
