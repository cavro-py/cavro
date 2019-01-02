
cdef class UnionType(AvroType):
    type_name = "union"

    cdef readonly tuple union_types
    cdef Schema schema

    def __init__(self, schema, source, namespace):
        super().__init__(schema, source, namespace)
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

    cdef Py_ssize_t resolve_from_value(self, object value) except -1:
        cdef int threshold = FIT_POOR if self.schema.permissive else FIT_OK
        cdef AvroType candidate
        cdef int type_fitness
        cdef int cur_fit = FIT_NONE
        cdef Py_ssize_t i = 0
        cdef Py_ssize_t best_index = -1
        for candidate in self.union_types:
            type_fitness = candidate.get_value_fitness(value)
            if type_fitness > cur_fit:
                best_index = i
                if type_fitness == FIT_EXACT:
                    return i
                cur_fit = type_fitness
            i += 1
        if cur_fit < threshold or best_index < 0:
            raise ValueError(f"Value '{value}' not valid for UnionType")
        return best_index

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef size_t type_index = self.resolve_from_value(value)
        cdef AvroType encode_type = self.union_types[type_index]
        zigzag_encode_long(buffer, type_index)
        encode_type.binary_buffer_encode(buffer, value)
        return 0

    cdef binary_buffer_decode(self, Reader buffer):
        cdef Py_ssize_t index = zigzag_decode_long(buffer)
        if index < 0 or index > len(self.union_types):
            raise ValueError(f"Value {index} is not valid for a union of {len(self.union_types)} items")
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

    def json_format(self, value):
        cdef size_t type_index = self.resolve_from_value(value)
        cdef AvroType union_type = self.union_types[type_index]
        if isinstance(union_type, NullType):
            return None
        return {union_type.get_type_name(): union_type.json_format(value)}

    cpdef object convert_value(self, object value):
        cdef Py_ssize_t index = self.resolve_from_value(value)
        return self.union_types[index].convert_value(value)

    cdef str canonical_form(self):
        cdef list parts = []
        cdef AvroType avro_type
        for avro_type in self.union_types:
            parts.append(avro_type.canonical_form())
        return '[' + ','.join(parts) + ']'

