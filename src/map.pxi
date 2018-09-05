
cdef class MapType(AvroType):

    cdef StringType key_type
    cdef AvroType value_type

    def __init__(self, schema, source, namespace):
        self.key_type = StringType(schema, 'string', namespace)
        self.value_type = AvroType.for_source(schema, source['values'], namespace)

    cdef int binary_buffer_encode(self, MemoryWriter buffer, value) except -1:
        if hasattr(value, 'items'):
            value = value.items()
        zigzag_encode_long(buffer, len(value))
        if value:
            for key, item_value in value:
                self.key_type.binary_buffer_encode(buffer, key)
                self.value_type.binary_buffer_encode(buffer, item_value)
            zigzag_encode_long(buffer, 0)

    cdef bint is_value_valid(self, value):
        if hasattr(value, 'items'):
            value = value.items()
        try:
            it = iter(value)
        except TypeError:
            return False
        for item in it:
            try:
                key, item_value = item
            except TypeError:
                return False
            if not isinstance(key, str):
                return False
            if not self.value_type.is_value_valid(item_value):
                return False
        return True