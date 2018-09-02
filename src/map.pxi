
cdef class MapType(AvroType):

    cdef AvroType value_type

    def __init__(self, schema, source, namespace):
        self.union_types = tuple(AvroType.for_source(schema, s, namespace) for s in source)
        if not schema.permissive:
            for union_type in self.union_types:
                if isinstance(union_type, UnionType):
                    raise ValueError("Unions may not directly contain other unions")

    cdef binary_buffer_encode(self, MemoryBuffer buffer, value):
        cdef size_t i = 0
        cdef AvroType union_type
        for union_type in self.union_types:
            if union_type.is_value_valid(value):
                zigzag_encode_int(buffer, i)
                union_type.binary_buffer_encode(buffer, value)
                return
            i += 1
        raise ValueError(f"Value '{value}' not valid for UnionType")

    cdef bint is_value_valid(self, value):
        for union_type in self.union_types:
            if union_type.is_value_valid(value):
                return True
        return False
