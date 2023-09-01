
cdef class NullType(AvroType):
    type_name = "null"

    cpdef AvroType copy(self):
        return self.clone_base()

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type'})

    cpdef dict _get_schema_extra(self, set created):
        return {}

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        if value is None or value is MISSING_VALUE or (self.options.allow_false_values_for_null and not value):
            return 0
        raise ValueError(f'{repr(value)} not compatible with NullType')

    cdef _binary_buffer_decode(self, Reader buffer):
        return None

    cdef int _get_value_fitness(self, value) except -1:
        if value is None:
            return FIT_EXACT
        if self.options.allow_false_values_for_null and not value:
            return FIT_POOR
        if self.options.missing_values_can_be_null and value is MISSING_VALUE:
            return FIT_OK
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

    cdef bint accepts_missing_value(self):
        if self.options.missing_values_can_be_null:
            return True

    cdef object resolve_default_value(self, object schema_default, str field):
        if schema_default is NO_DEFAULT:  # Null fields always have default NULL
            return MISSING_VALUE 
        return AvroType.resolve_default_value(self, schema_default, field)