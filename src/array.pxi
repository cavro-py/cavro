
import collections

cdef class ArrayType(AvroType):
    type_name = "array"

    cdef readonly AvroType item_type

    def __init__(self, schema, source, namespace):
        self.item_type = AvroType.for_source(schema, source['items'], namespace)

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if value:
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
        if isinstance(value, (list, tuple)):
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