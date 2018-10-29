
cdef class UnionType(AvroType):
    type_name = "union"

    cdef readonly tuple union_types
    cdef Schema schema

    def __init__(self, schema, source, namespace):
        self.schema = schema
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

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef int threshold = FIT_POOR if self.schema.permissive else FIT_OK
        cdef size_t i = 0
        cdef AvroType union_type
        cdef AvroType best_fit
        cdef size_t best_index
        cdef int cur_fit = FIT_NONE
        cdef int type_fitness
        for union_type in self.union_types:
            type_fitness = union_type.get_value_fitness(value)
            if type_fitness > cur_fit:
                best_fit = union_type
                cur_fit = type_fitness
                best_index = i
                if type_fitness == FIT_EXACT:
                    break
            i += 1
        if cur_fit < threshold:
            raise ValueError(f"Value '{value}' not valid for UnionType")
        zigzag_encode_long(buffer, best_index)
        best_fit.binary_buffer_encode(buffer, value)
        return 0

    cdef binary_buffer_decode(self, Reader buffer):
        cdef size_t index = zigzag_decode_long(buffer)
        cdef AvroType item = self.union_types[index]
        return item.binary_buffer_decode(buffer)

    cdef int get_value_fitness(self, value) except -1:
        cdef AvroType union_type
        cdef int level = FIT_NONE
        for union_type in self.union_types:
            level = max(level, union_type.get_value_fitness(value))
            if level == FIT_EXACT:
                return level
        return level
