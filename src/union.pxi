
cdef class UnionType(AvroType):
    type_name = "union"

    cdef readonly tuple union_types

    def __init__(self, schema, source, namespace):
        self.union_types = tuple(AvroType.for_source(schema, s, namespace) for s in source)
        if not schema.permissive:
            if len(self.union_types) == 0:
                raise ValueError("Unions must contain at least one member type")
            seen_types = set()
            for member in self.union_types:
                if isinstance(member, UnionType):
                    raise ValueError("Unions may not immediately contain other unions")
                if not isinstance(member, (RecordType, FixedType, EnumType)):
                    member_type = type(member)
                    if member_type in seen_types:
                        raise ValueError(f"Unions may not have more than one member of type '{ member_type.type_name }'")
                    seen_types.add(member_type)

    cdef int binary_buffer_encode(self, MemoryWriter buffer, value) except -1:
        cdef size_t i = 0
        cdef AvroType union_type
        for union_type in self.union_types:
            if union_type.is_value_valid(value):
                zigzag_encode_long(buffer, i)
                union_type.binary_buffer_encode(buffer, value)
                return 0
            i += 1
        raise ValueError(f"Value '{value}' not valid for UnionType")

    cdef bint is_value_valid(self, value):
        for union_type in self.union_types:
            if union_type.is_value_valid(value):
                return True
        return False
