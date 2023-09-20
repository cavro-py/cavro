import numpy
import collections

@cython.final
cdef class ArrayType(AvroType):
    type_name = "array"

    cdef readonly AvroType item_type

    def __init__(self, schema, source, namespace):
        super().__init__(schema, source, namespace)
        self.item_type = AvroType.for_source(schema, source['items'], namespace)

    cpdef AvroType copy(self):
        cdef ArrayType new_inst = self.clone_base()
        new_inst.item_type = self.item_type
        return new_inst

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type', 'items'})

    def walk_types(self, visited):
        if self in visited:
            return
        yield from super().walk_types(visited)
        yield from self.item_type.walk_types(visited)

    cpdef dict _get_schema_extra(self, set created):
        return {'items': self.item_type.get_schema(created)}

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef size_t idx = 0
        if len(value):
            zigzag_encode_long(buffer, len(value))
            for item in value:
                try:
                    self.item_type.binary_buffer_encode(buffer, item)
                except InvalidValue as e:
                    if self.options.invalid_value_include_array_index:
                        e.schema_path = (idx, ) + e.schema_path
                    raise
                idx += 1
        zigzag_encode_long(buffer, 0)

    cdef _binary_buffer_decode(self, Reader buffer):
        cdef list out = []
        cdef size_t length
        cdef str key
        while True:
            length = zigzag_decode_long(buffer)
            if length == 0:
                return out
            while length:
                value = self.item_type.binary_buffer_decode(buffer)
                out.append(value)
                length -= 1

    cdef _json_format(self, value):
        return [self.item_type.json_format(item) for item in value]

    cdef _json_decode(self, value):
        return [self.item_type.json_decode(item) for item in value]

    cdef int _get_value_fitness(self, value) except -1:
        cdef int level = FIT_OK
        if isinstance(value, (list, tuple, numpy.ndarray)):
            level = FIT_EXACT
        elif isinstance(value, dict):
            level = FIT_POOR
        elif self.options.missing_values_can_be_empty_container and value is MISSING_VALUE:
            return FIT_POOR
        elif isinstance(value, (bytes, str)) or not isinstance(value, collections.abc.Iterable):
            return FIT_NONE
        try:
            it = iter(value)
        except TypeError:
            return FIT_NONE
        for item in it:
            level = min(self.item_type.get_value_fitness(item), level)
            if level <= FIT_NONE:
                break
        return level

    cdef list _make_converted_list(self, value):
        cdef AvroType item_type = self.item_type
        cdef list out = []
        for item in value:
            out.append(item_type.convert_value(item))
        return out

    cpdef object convert_value(self, object value, check_value=True):
        cdef int item_fitness
        cdef AvroType item_type = self.item_type

        if self.options.missing_values_can_be_empty_container and value is MISSING_VALUE:
            return []

        it = iter(value)
        for item in it:
            item_fitness = item_type.get_value_fitness(item)
            if item_fitness == FIT_NONE:
                raise ValueError(f"'{item}' is not a valid value for array")
            elif item_fitness < FIT_EXACT:
                return self._make_converted_list(iter(value))
        return value

    cdef CanonicalForm canonical_form(self, set created):
        return dict_to_canonical({
            'type': 'array',
            'items': self.item_type.canonical_form(created)
        })

    cdef AvroType _for_writer(self, AvroType writer):
        cdef ArrayType cloned
        if isinstance(writer, ArrayType):
            promoted_item = self.item_type._for_writer(writer.item_type)
            if promoted_item is not None:
                cloned = self.clone_base()
                cloned.item_type = promoted_item
                return cloned

    cdef bint accepts_missing_value(self):
        if self.options.missing_values_can_be_empty_container:
            return True