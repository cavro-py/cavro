
cdef array.array byte_buffer_template = array.array('B', [])

@cython.final
cdef class MemoryWriter(Writer):

    cdef readonly array.array buffer
    cdef size_t cur_pos

    def __init__(self, initial_size=4096):
        self.buffer = array.clone(byte_buffer_template, initial_size, zero=True)
        self.cur_pos = 0

    cdef bytes bytes(self):
        return self.buffer.data.as_chars[:self.cur_pos]

    cdef reset(self):
        self.cur_pos = 0

    cdef int write_u8(self, uint8_t val) except -1:
        if self.buffer.ob_size - self.cur_pos < 1:
            array.resize_smart(self.buffer, self.cur_pos + 1)
        self.buffer.data.as_uchars[self.cur_pos] = val
        self.cur_pos += 1

    cdef int write_n(self, size_t num, uint8_t *bytes) except -1:
        if self.buffer.ob_size - self.cur_pos < num:
            array.resize_smart(self.buffer, self.cur_pos + num)
        memcpy(self.buffer.data.as_chars + self.cur_pos, bytes, num)
        self.cur_pos += num


cdef bytes empty_buffer = b"\x00"


cdef class MemoryReader(Reader):

    cdef const uint8_t[:] data
    cdef const uint8_t* ptr
    cdef const uint8_t *end_ptr

    def __init__(self, data):
        self._reset_to(data)

    cdef void _reset_to(self, const uint8_t[:] data):
        if len(data):
            self.data = data
        else:
            self.data = empty_buffer

        self.ptr = &self.data[0]
        self.end_ptr = self.ptr + len(data)

    cdef const uint8_t *advance(self, size_t num) except <uint8_t*>0:
        cdef const uint8_t *ptr = self.ptr
        if <size_t>(self.end_ptr - self.ptr) < num:
            raise EOFError("Not enough input data to read value")
        self.ptr += num
        return ptr

    cdef inline int ensure(self, size_t num) except -1:
        if <size_t>(self.end_ptr - self.ptr) < num:
            raise EOFError("Not enough input data to read value")

    cdef uint8_t read_u8(self) except? 0xba:
        return self.advance(1)[0]

    cdef const uint8_t[:] read_n(self, Py_ssize_t n):
        cdef const uint8_t* ptr = self.ptr
        self.advance(n)
        return ptr[:n]

    cdef bytes read_bytes(self, Py_ssize_t n):
        cdef const uint8_t* ptr = self.ptr
        self.advance(n)
        return ptr[:n]
