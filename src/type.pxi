
cdef int FIT_NONE = 0  # Value is never valid for type
cdef int FIT_POOR = 1  # Value may be valid in permissive mode, as last-resort
cdef int FIT_OK = 2    # Value can be converted to the correct type
cdef int FIT_EXACT = 3 # Value is the exact type and needs no further conversion


CANONICAL_FORM_KEYS = ('name', 'type', 'fields', 'symbols', 'items', 'values', 'size')
cdef str dict_to_canonical(data):
    if isinstance(data, dict):
        pairs=[]
        for key in CANONICAL_FORM_KEYS:
            if key in data:
                pairs.append((f'"{key}"', dict_to_canonical(data[key])))
        pair_str = ','.join(':'.join(p) for p in pairs)
        return '{' + pair_str + '}'
    elif isinstance(data, tuple):
        values = ','.join([dict_to_canonical(v) for v in data])
        return '[' + values + ']'
    else:
        return json.dumps(data, ensure_ascii=False)


cdef class AvroType:
    type_name = NotImplemented

    cdef readonly bool permissive

    @classmethod
    def for_source(cls, schema, source, namespace=None):
        if isinstance(source, (list, tuple)):
            return UnionType(schema, source, namespace)
        if isinstance(source, str):
            source = {'type': source}
        try:
            type_name = source['type']
        except (TypeError, KeyError) as e:
            raise ValueError(f"Could not find key 'type' in schema definition: {repr(source)}")
        if type_name in TYPES_BY_NAME:
            return TYPES_BY_NAME[type_name](schema, source, namespace)
        namespaced = resolve_namespaced_name(namespace, type_name)
        if namespaced in schema.named_types:
            return schema.named_types[namespaced]
        raise ValueError(f"Unknown type: {type_name}")

    @classmethod
    def for_schema(cls, schema):
        return AvroType.for_source(schema, schema.source)

    def __init__(self, schema, source, namespace):
        self.permissive = schema.permissive

    cpdef str get_type_name(self):
        return self.type_name

    cpdef object _convert_value(self, object value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement convert_value")

    cpdef object convert_value(self, object value):
        self.assert_value(value)
        return self._convert_value(value)

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement binary_buffer_encode")

    cdef binary_buffer_decode(self, Reader buffer):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement binary_buffer_decode")

    cdef int get_value_fitness(self, value) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement get_value_fitness")

    cdef int assert_value(self, object value) except -1:
        cdef int fitness = self.get_value_fitness(value)
        cdef int threshold = FIT_POOR if self.permissive else FIT_OK
        if fitness < threshold:
            raise ValueError(f"'{value}' not valid for {type(self).__name__}")

    def json_format(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement json_format")

    def json_decode(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement json_format")

    cdef str canonical_form(self):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement canonical_form")


cdef class NamedType(AvroType):

    cdef readonly str name
    cdef readonly str namespace
    cdef readonly frozenset aliases

    def __init__(self, schema, source, namespace):
        cdef Schema schema_t = schema
        super().__init__(schema, source, namespace)
        cdef str name = source['name']
        if not schema.permissive:
            if name in PRIMITIVE_TYPES:
                raise ValueError(f"'{name}' is not allowed as a name")
        self.name = name
        self.namespace = source.get('namespace')
        self.aliases = frozenset(source.get('aliases', []))
        schema_t.register_type(self.namespace, self.name, self)

    cpdef str get_type_name(self):
        return resolve_namespaced_name(self.namespace, self.name)


PRIMITIVE_TYPES = {
    'null': NullType,
    'boolean': BoolType,
    'int': IntType,
    'long': LongType,
    'float': FloatType,
    'double': DoubleType,
    'bytes': BytesType,
    'string': StringType,
}

TYPES_BY_NAME = dict(
    PRIMITIVE_TYPES,
    map=MapType,
    enum=EnumType,
    record=RecordType,
    fixed=FixedType,
    array=ArrayType,
)
