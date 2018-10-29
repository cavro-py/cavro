
cdef class MapType(AvroType):
    type_name = "map"

    cdef StringType key_type
    cdef readonly AvroType value_type

    def __init__(self, schema, source, namespace):
        self.key_type = StringType(schema, 'string', namespace)
        self.value_type = AvroType.for_source(schema, source['values'], namespace)

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if hasattr(value, 'items'):
            value = value.items()
        zigzag_encode_long(buffer, len(value))
        if value:
            for key, item_value in value:
                self.key_type.binary_buffer_encode(buffer, key)
                self.value_type.binary_buffer_encode(buffer, item_value)
            zigzag_encode_long(buffer, 0)

    cdef binary_buffer_decode(self, Reader buffer):
        cdef dict out = {}
        cdef size_t length
        cdef str key
        while True:
            length = zigzag_decode_long(buffer)
            if length == 0:
                return out
            while length:
                key = self.key_type.binary_buffer_decode(buffer)
                value = self.value_type.binary_buffer_decode(buffer)
                out[key] = value
                length -= 1

    cdef int get_value_fitness(self, value) except -1:
        cdef int level = FIT_OK
        if isinstance(value, dict):
            level = FIT_EXACT
        if hasattr(value, 'items'):
            value = value.items()
        try:
            it = iter(value)
        except TypeError:
            return False
        for item in it:
            try:
                
                key, item_value = item
            except (TypeError, ValueError):
                return FIT_NONE
            level = min(self.key_type.get_value_fitness(key), level)
            level = min(self.value_type.get_value_fitness(item_value), level)
            if level <= FIT_NONE:
                break
        return level