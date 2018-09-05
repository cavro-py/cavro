
cdef class NullType(AvroType):
    type_name = "null"

    cdef int binary_buffer_encode(self, MemoryWriter buffer, value) except -1:
        return
