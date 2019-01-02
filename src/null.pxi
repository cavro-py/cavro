
cdef class NullType(AvroType):
    type_name = "null"
    cdef Schema schema

    def __init__(self, schema, source, namespace):
        super().__init__(schema, source, namespace)
        self.schema = schema

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if value is None or (self.schema.permissive and not value):
            return 0
        raise ValueError(f'{repr(value)} not compatible with NullType')

    cdef binary_buffer_decode(self, Reader buffer):
        return None

    cdef int get_value_fitness(self, value) except -1:
        if value is None:
            return FIT_EXACT
        if not value:
            return FIT_POOR
        return FIT_NONE

    def json_format(self, value):
        return None

    def json_decode(self, value):
        return None

    cpdef object _convert_value(self, object value):
        return None

    cdef str canonical_form(self):
        return '"null"'