
cdef class MapType(AvroType):
    type_name = "map"

    cdef StringType key_type
    cdef readonly AvroType value_type

    def __init__(self, schema, source, namespace):
        super().__init__(schema, source, namespace)
        self.key_type = StringType(schema, {'type': 'string'}, namespace) # This way we pick up options
        self.value_type = AvroType.for_source(schema, source['values'], namespace)

    cpdef AvroType copy(self):
        cdef MapType new_inst = self.clone_base()
        new_inst.key_type = self.key_type
        new_inst.value_type = self.value_type
        return new_inst

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type', 'values'})

    def walk_types(self, visited):
        if self in visited:
            return
        yield from super().walk_types(visited)
        yield from self.value_type.walk_types(visited)

    cpdef dict _get_schema_extra(self, set created):
        return {'values': self.value_type.get_schema(created)}

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        if hasattr(value, 'items'):
            value = value.items()
        zigzag_encode_long(buffer, len(value))
        if value:
            for key, item_value in value:
                self.key_type.binary_buffer_encode(buffer, key)
                try:
                    self.value_type.binary_buffer_encode(buffer, item_value)
                except InvalidValue as e:
                    e.schema_path = (key, ) + e.schema_path
                    raise
            zigzag_encode_long(buffer, 0)
        return 0

    cdef _binary_buffer_decode(self, Reader buffer):
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

    cdef json_format(self, value):
        cdef str key
        cdef dict out = {}
        if hasattr(value, 'items'):
            value = value.items()
        for key, item_value in value:
            out[key] = self.value_type.json_format(item_value)
        return out

    cdef json_decode(self, value):
        cdef dict inp = value
        cdef dict out = {}
        cdef str key
        for key, val in inp.items():
            out[key] = self.value_type.json_decode(val)
        return out

    cdef int _get_value_fitness(self, value) except -1:
        cdef int level = FIT_OK
        if isinstance(value, dict):
            level = FIT_EXACT
        
        elif self.options.missing_values_can_be_empty_container and value is MISSING_VALUE:
            return FIT_POOR
            
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
            out[key_type._convert_value(key)] = value_type._convert_value(item_value)
        return out

    cpdef object convert_value(self, object orig_value, check_value=True):
        cdef int key_fitness
        cdef int value_fitness
        cdef AvroType key_type = self.key_type
        cdef AvroType value_type = self.value_type

        if isinstance(orig_value, dict):
            value = orig_value.items()
        else:
            value = orig_value

        if self.options.missing_values_can_be_empty_container and value is MISSING_VALUE:
            return {}

        it = iter(value)
        for item in it:
            try:
                key, item_value = item
            except (TypeError, ValueError, IndexError):
                raise ValueError(f"'{value}' is not a mapping")
            key_fitness = key_type.get_value_fitness(key)
            if key_fitness == FIT_NONE:
                raise ValueError(f"'{key}' is not a valid key for map type")
            elif key_fitness < FIT_EXACT:
                return self._make_converted_map(iter(value))

            value_fitness = value_type.get_value_fitness(item_value)
            if value_fitness == FIT_NONE:
                raise ValueError(f"'{item_value}' is not a valid value for map type: {type(self.value_type).__name__}")
            elif value_fitness < FIT_EXACT:
                return self._make_converted_map(iter(value))
        return orig_value

    cdef CanonicalForm canonical_form(self, set created):
        return dict_to_canonical({
            'type': 'map',
            'values': self.value_type.canonical_form(created)
        })

    cdef AvroType _for_writer(self, AvroType writer):
        cdef MapType cloned
        cdef MapType writer_map
        if isinstance(writer, MapType):
            writer_map = writer
            promoted_value = self.value_type._for_writer(writer.value_type)
            if promoted_value is not None:
                cloned = self.clone_base()
                cloned.key_type = writer_map.key_type
                cloned.value_type = promoted_value
                return cloned

    cdef bint accepts_missing_value(self):
        if self.options .missing_values_can_be_empty_container:
            return True