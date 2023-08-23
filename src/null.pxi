
cdef class NullType(AvroType):
    type_name = "null"

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {'type'})

    cpdef dict _get_schema_extra(self, set created):
        return {}

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        if value is None or (self.options.allow_false_values_for_null and not value):
            return 0
        raise ValueError(f'{repr(value)} not compatible with NullType')

    cdef _binary_buffer_decode(self, Reader buffer):
        return None

    cdef int _get_value_fitness(self, value) except -1:
        if value is None:
            return FIT_EXACT
        if not value and self.options.allow_false_values_for_null:
            return FIT_POOR
        return FIT_NONE

    cdef json_format(self, value):
        return None

    cdef json_decode(self, value):
        if value is not None:
            raise ValueError(f'Expected null, got {repr(value)}')
        return None

    cpdef object _convert_value(self, object value):
        return None

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"null"')
