
cdef class NullType(AvroType):
    type_name = "null"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        pass

    cdef binary_buffer_decode(self, Reader buffer):
        return None

    cdef int get_value_fitness(self, value) except -1:
        if value is None:
            return FIT_EXACT
        if not value:
            return FIT_POOR
        return FIT_NONE

    def json_encode(self, value):
        return None

    def json_decode(self, value):
        return value
