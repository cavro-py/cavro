
cdef class NullType(AvroType):
    type_name = "null"

    cdef binary_buffer_encode(self, MemoryBuffer buffer, value):
        return
