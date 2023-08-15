
cdef int FIT_NONE = 0  # Value is never valid for type
cdef int FIT_POOR = 1  # Value may be valid depending on the schema options
cdef int FIT_OK = 2    # Value can be converted to the correct type
cdef int FIT_EXACT = 3 # Value is the exact type and needs no further conversion


CANONICAL_FORM_KEYS = ('name', 'type', 'fields', 'symbols', 'items', 'values', 'size')

cdef class CanonicalForm(str):
    pass

cdef CanonicalForm dict_to_canonical(data):
    if isinstance(data, dict):
        pairs=[]
        for key in CANONICAL_FORM_KEYS:
            if key in data:
                pairs.append((f'"{key}"', dict_to_canonical(data[key])))
        pair_str = ','.join(':'.join(p) for p in pairs)
        return CanonicalForm('{' + pair_str + '}')
    elif isinstance(data, (tuple, list)):
        values = ','.join([dict_to_canonical(v) for v in data])
        return CanonicalForm('[' + values + ']')
    elif isinstance(data, CanonicalForm):
        return data
    else:
        return CanonicalForm(json.dumps(data, ensure_ascii=False))


cdef dict _strip_keys(dict source, set keys):
    return {k: v for k, v in source.items() if k not in keys}


cdef class AvroType:
    type_name = NotImplemented

    cdef readonly Options options
    cdef readonly dict metadata

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
        if type_name in schema.named_types:
            return schema.named_types[type_name]
        raise ValueError(f"Unknown type: {type_name}")

    @classmethod
    def for_schema(cls, schema):
        return AvroType.for_source(schema, schema.source)

    def __init__(self, schema, source, namespace):
        self.options = schema.options
        self.metadata = self._extract_metadata(source)

    cpdef str get_type_name(self):
        return self.type_name

    cdef dict _extract_metadata(self, source):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement _extract_metadata")

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
        if fitness <= FIT_NONE:
            raise ValueError(f"'{value}' not valid for {type(self).__name__}")

    def json_format(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement json_format")

    def json_decode(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement json_format")

    cdef CanonicalForm canonical_form(self, set created):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement canonical_form")


cdef class NamedType(AvroType):

    cdef readonly str name
    cdef readonly str namespace
    cdef readonly str effective_namespace
    cdef readonly frozenset aliases

    def __init__(self, schema, source, namespace):
        cdef Schema schema_t = schema
        super().__init__(schema, source, namespace)
        cdef str name = source['name']
        if not schema.options.allow_primitive_name_collision:
            if name in PRIMITIVE_TYPES:
                raise ValueError(f"'{name}' is not allowed as a name")
        self.name = name
        self.namespace = source.get('namespace')
        self.effective_namespace = namespace if self.namespace is None else self.namespace
        self.aliases = frozenset(source.get('aliases', []))
        schema_t.register_type(self.effective_namespace, self.name, self)

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
