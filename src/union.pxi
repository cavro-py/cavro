
AMBIGUOUS_TYPES = [
    {RecordType, MapType},
    {EnumType, StringType},
    {LongType, IntType},
]

cdef bint are_union_values_ambiguous(sub_types):
    cdef AvroType sub_type
    cdef Py_ssize_t i
    seen_classes = set()

    for sub_type in sub_types:
        i = 0
        for bucket in AMBIGUOUS_TYPES:
            if type(sub_type) in bucket:
                if i in seen_classes:
                    return True
            seen_classes.add(i)
            i += 1
    return False


@cython.final
cdef class UnionType(AvroType):
    type_name = "union"

    cdef readonly tuple union_types
    cdef readonly dict by_name_map
    cdef readonly tuple return_type_tuple

    def __init__(self, schema, source, namespace):
        super().__init__(schema, source, namespace)
        self.union_types = tuple(AvroType.for_source(schema, s, namespace) for s in source)
        if len(self.union_types) == 0 and not self.options.allow_empty_unions:
            raise ValueError("Unions must contain at least one member type")

        if not (self.options.allow_duplicate_union_types and self.options.allow_nested_unions):
            self._populate_name_map()

        decode_option = self.options.union_decodes_to
        if decode_option == UnionDecodeOption.RAW_VALUES:
            self.return_type_tuple = tuple(False for _ in self.union_types)
        elif decode_option == UnionDecodeOption.TYPE_TUPLE_IF_AMBIGUOUS:
            is_amibiguous = are_union_values_ambiguous(self.union_types)
            self.return_type_tuple = tuple(is_amibiguous for _ in self.union_types)
        elif decode_option == UnionDecodeOption.TYPE_TUPLE_IF_RECORD_AMBIGUOUS:
            is_ambiguous = sum(1 for t in self.union_types if isinstance(t, (RecordType, MapType))) > 1
            self.return_type_tuple = tuple(is_ambiguous and isinstance(ty, RecordType) for ty in self.union_types)
        elif decode_option == UnionDecodeOption.TYPE_TUPLE_IF_RECORD:
            self.return_type_tuple = tuple(isinstance(ty, RecordType) for ty in self.union_types)
        elif decode_option == UnionDecodeOption.TYPE_TUPLE_ALWAYS:
            self.return_type_tuple = tuple(True for _ in self.union_types)
        else:
            raise ValueError(f"Invalid union_decodes_to option: {decode_option}")
        
    cdef _populate_name_map(self):
        seen_types = set()
        self.by_name_map = {}
        for member in self.union_types:
            if isinstance(member, NamedType):
                self.by_name_map[member.name] = member
                self.by_name_map[member.type] = member
            else:
                self.by_name_map[member.type_name] = member

            if not self.options.allow_nested_unions and isinstance(member, UnionType):
                raise ValueError("Unions may not immediately contain other unions")
            if not self.options.allow_duplicate_union_types:  
                if not isinstance(member, (RecordType, FixedType, EnumType)):
                    member_type = type(member)
                    if member_type in seen_types:
                        raise ValueError(f"Unions may not have more than one member of type '{ member_type.type_name }'")
                    seen_types.add(member_type)

    cpdef AvroType copy(self):
        cdef UnionType new_inst = self.clone_base()
        new_inst.union_types = self.union_types
        new_inst.by_name_map = self.by_name_map.copy()
        new_inst.return_type_tuple = self.return_type_tuple
        return new_inst

    cdef _make_logical(self, schema, source):
        return

    cdef dict _extract_metadata(self, source):
        return dict()

    def walk_types(self, visited):
        if self in visited:
            return
        yield from super().walk_types(visited)
        for t in self.union_types:
            yield from t.walk_types(visited)

    cpdef get_schema(self, created=None):
        if created is None:
            created = set()
        return [t.get_schema(created) for t in self.union_types]

    cdef Py_ssize_t resolve_from_value(self, object value) except -1:
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
        if cur_fit == FIT_NONE or best_index < 0:
            raise InvalidValue(value, self)
        return best_index

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef size_t type_index = self.resolve_from_value(value)
        cdef AvroType encode_type = self.union_types[type_index]
        zigzag_encode_long(buffer, type_index)
        encode_type.binary_buffer_encode(buffer, value)
        return 0

    cdef _binary_buffer_decode(self, Reader buffer):
        cdef Py_ssize_t index = zigzag_decode_long(buffer)
        if index < 0 or index >= len(self.union_types):
            raise ValueError(f"Value {index} is not valid for a union of {len(self.union_types)} items")
        cdef AvroType item = self.union_types[index]
        decoded = item.binary_buffer_decode(buffer)
        if self.return_type_tuple[index]:
            return (item.type, decoded)
        return decoded

    cdef int _get_value_fitness(self, value) except -1:
        cdef AvroType union_type
        cdef int level = FIT_NONE
        for union_type in self.union_types:
            level = max(level, union_type.get_value_fitness(value))
            if level == FIT_EXACT:
                return level
        return level

    cdef json_format(self, value):
        cdef size_t type_index = self.resolve_from_value(value)
        cdef AvroType union_type = self.union_types[type_index]
        if isinstance(union_type, NullType):
            return None
        return {union_type.type: union_type.json_format(value)}

    cdef json_decode(self, value):
        cdef dict value_dict = value
        if len(value) > 1:
            raise ValueError(f"Value {value} is not a valid union value (expect exactly one item)")
        cdef AvroType item_type
        (type_name, item_value), = value_dict.items()
        try:
            item_type = self.by_name_map[type_name]
        except KeyError:
            raise ValueError(f"Value {value} is not a valid union value (unknown type '{type_name}')")
        return item_type.json_decode(item_value)

    cpdef object convert_value(self, object value, check_value=True):
        cdef Py_ssize_t index = self.resolve_from_value(value)
        return self.union_types[index].convert_value(value)

    cdef CanonicalForm canonical_form(self, set created):
        cdef list parts = []
        cdef AvroType avro_type
        for avro_type in self.union_types:
            parts.append(avro_type.canonical_form(created))
        return CanonicalForm('[' + ','.join(parts) + ']')

    cdef AvroType _for_writer(self, AvroType writer):
        cdef AvroType sub_type
        cdef UnionType writer_union
        cdef bint got_one = False

        if not isinstance(writer, UnionType):
            for sub_type in self.union_types:
                try:
                    return sub_type.for_writer(writer, False)
                except CannotPromoteError:
                    pass
            return
        writer_union = writer
        return writer_union.for_reader(self)

    cdef AvroType for_reader(self, AvroType reader):
        cdef AvroType sub_type
        cdef UnionType new_writer
        cdef bint got_one = False
        new_sub_types = []
        for sub_type in self.union_types:
            try:
                sub_adapted = reader.for_writer(sub_type, False)
            except CannotPromoteError:
                sub_adapted = sub_type.copy()
                sub_adapted.value_adapters = (CannotPromote(reader, sub_type), ) + sub_adapted.value_adapters
            else:
                got_one = True
            new_sub_types.append(sub_adapted)
        if not got_one:
            return
        new_writer = self.clone_base()
        new_writer.union_types = tuple(new_sub_types)
        new_writer.return_type_tuple = self.return_type_tuple
        new_writer._populate_name_map()
        return new_writer

    cdef bint accepts_missing_value(self):
        cdef AvroType union_type
        for union_type in self.union_types:
            if union_type.accepts_missing_value():
                return True
        return False

    cdef object resolve_default_value(self, object schema_default, str field):
        cdef AvroType sub_type
        if schema_default is NO_DEFAULT:
            for sub_type in self.union_types:
                if sub_type.accepts_missing_value():
                    return MISSING_VALUE
        sub_type = self.union_types[0]
        try:
            return sub_type.resolve_default_value(schema_default, field)
        except TypeError as e:
            raise TypeError(f"Default value {schema_default!r} for field {field} is not valid for union with first type: {sub_type.type_name}") from e
