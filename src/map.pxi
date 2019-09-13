
cdef class MapType(AvroType):
    type_name = "map"

    cdef StringType key_type
    cdef readonly AvroType value_type

    def __init__(self, schema, source, namespace):
        super().__init__(schema, source, namespace)
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
        except (TypeError, KeyError):
            return False
        while True:
            try:
                item = next(it)
            except StopIteration:
                break
            except:
                return FIT_NONE
            try:
                key, item_value = item
            except (TypeError, ValueError, IndexError, KeyError):
                return FIT_NONE
            level = min(self.key_type.get_value_fitness(key), level)
            level = min(self.value_type.get_value_fitness(item_value), level)
            if level <= FIT_NONE:
                break
        return level

    cdef dict _make_converted_map(self, value):
        cdef AvroType key_type = self.key_type
        cdef AvroType value_type = self.value_type
        cdef dict out = {}
        for item in value:
            try:
                key, item_value = item
            except (TypeError, ValueError, IndexError):
                raise ValueError(f"'{value}' is not a mapping")
            out[key_type.convert_value(key)] = value_type.convert_value(item_value)
        return out

    cpdef object convert_value(self, object orig_value):
        cdef int threshold = FIT_POOR if self.permissive else FIT_OK
        cdef int key_fitness
        cdef int value_fitness
        cdef AvroType key_type = self.key_type
        cdef AvroType value_type = self.value_type

        if isinstance(orig_value, dict):
            value = orig_value.items()
        else:
            value = orig_value

        it = iter(value)
        for item in it:
            try:
                key, item_value = item
            except (TypeError, ValueError, IndexError):
                raise ValueError(f"'{value}' is not a mapping")
            key_fitness = key_type.get_value_fitness(key)
            if key_fitness < threshold:
                raise ValueError(f"'{key}' is not a valid key for map type")
            elif key_fitness < FIT_EXACT:
                return self._make_converted_map(iter(value))

            value_fitness = value_type.get_value_fitness(item_value)
            if value_fitness < threshold:
                raise ValueError(f"'{item_value}' is not a valid value for map type: {type(self.value_type).__name__}")
            elif value_fitness < FIT_EXACT:
                return self._make_converted_map(iter(value))
        return orig_value

    cdef CanonicalForm canonical_form(self, set created):
        return dict_to_canonical({
            'type': 'map',
            'values': self.value_type.canonical_form(created)
        })
