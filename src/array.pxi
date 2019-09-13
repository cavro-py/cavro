import numpy
import collections

@cython.final
cdef class ArrayType(AvroType):
    type_name = "array"

    cdef readonly AvroType item_type

    def __init__(self, schema, source, namespace):
        super().__init__(schema, source, namespace)
        self.item_type = AvroType.for_source(schema, source['items'], namespace)

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if len(value):
            zigzag_encode_long(buffer, len(value))
            for item in value:
                self.item_type.binary_buffer_encode(buffer, item)
        zigzag_encode_long(buffer, 0)

    cdef binary_buffer_decode(self, Reader buffer):
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

    cdef int get_value_fitness(self, value) except -1:
        cdef int level = FIT_OK
        if isinstance(value, (list, tuple, numpy.ndarray)):
            level = FIT_EXACT
        elif isinstance(value, dict):
            level = FIT_POOR
        elif isinstance(value, (bytes, str)) or not isinstance(value, collections.Iterable):
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

    cdef dict _make_converted_list(self, value):
        cdef AvroType item_type = self.item_type
        cdef list out = []
        for item in value:
            out.append(item_type.convert_value(item))
        return out

    cpdef object convert_value(self, object value):
        cdef int threshold = FIT_POOR if self.permissive else FIT_OK
        cdef int item_fitness
        cdef AvroType item_type = self.item_type

        it = iter(value)
        for item in it:
            item_fitness = item_type.get_value_fitness(item)
            if item_fitness < threshold:
                raise ValueError(f"'{item}' is not a valid value for array")
            elif item_fitness < FIT_EXACT:
                return self._make_converted_list(iter(value))
        return value

    cdef CanonicalForm canonical_form(self, set created):
        return dict_to_canonical({
            'type': 'array',
            'items': self.item_type.canonical_form(created)
        })