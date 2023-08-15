
cdef class NullType(AvroType):
    type_name = "null"

    def __init__(self, schema, source, namespace):
        super().__init__(schema, source, namespace)

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {'type'})

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if value is None or (self.options.allow_false_values_for_null and not value):
            return 0
        raise ValueError(f'{repr(value)} not compatible with NullType')

    cdef binary_buffer_decode(self, Reader buffer):
        return None

    cdef int get_value_fitness(self, value) except -1:
        if value is None:
            return FIT_EXACT
        if not value and self.options.allow_false_values_for_null:
            return FIT_POOR
        return FIT_NONE

    def json_format(self, value):
        return None

    def json_decode(self, value):
        return None

    cpdef object _convert_value(self, object value):
        return None

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"null"')