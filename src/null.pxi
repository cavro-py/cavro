
cdef class NullType(AvroType):
    type_name = "null"

    cdef void binary_buffer_encode(self, MemoryWriter buffer, value):
        return
