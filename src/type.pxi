
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
    cdef readonly object metadata
    cdef readonly tuple[ValueAdapter] value_adapters

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
        namespaced = resolve_namespaced_name(namespace, type_name)
        if namespaced in schema.named_types:
            return schema.named_types[namespaced]
        if type_name in schema.named_types:
            return schema.named_types[type_name]
        if type_name in TYPES_BY_NAME:
            return TYPES_BY_NAME[type_name](schema, source, namespace)
        if type_name == 'error' and schema.options.allow_error_type:
            return RecordType(schema, source, namespace)
        raise ValueError(f"Unknown type: {type_name}")

    @classmethod
    def for_schema(cls, schema):
        return AvroType.for_source(schema, schema.source)

    def __init__(self, schema, source, namespace, value_adapters=tuple()):
        cdef ValueAdapter logical
        self.options = schema.options
        self.metadata = PyDictProxy_New(self._extract_metadata(source))
        
        logical = self._make_logical(schema, source)
        if logical is not None:
            self.value_adapters = value_adapters + (logical,)
        else:
            self.value_adapters = value_adapters

    cdef AvroType clone_base(self):
        cdef AvroType clone = self.__class__.__new__(self.__class__)
        clone.options = self.options
        clone.metadata = self.metadata
        clone.value_adapters = self.value_adapters
        return clone

    cdef _make_logical(self, schema, source):
        cdef str logical_type_name = source.get('logicalType')
        if logical_type_name is None:
            return
        logical_type_classes = schema.logical_types.get(logical_type_name, [])
        for cls in logical_type_classes:
            inst = cls.for_type(self)
            if inst is not None:
                return inst

    property type:
        def __get__(self):
            return self.type_name

    cdef dict _extract_metadata(self, source):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement _extract_metadata")

    cpdef object _convert_value(self, object value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement convert_value")

    cpdef object convert_value(self, object value, check_value=False):
        if check_value:
            self.assert_value(value)
        return self._convert_value(value)

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef ValueAdapter adapter
        for adapter in self.value_adapters:
            value = adapter.encode_value(value)
        return self._binary_buffer_encode(buffer, value)

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement _binary_buffer_encode")

    cdef binary_buffer_decode(self, Reader buffer):
        cdef ValueAdapter adapter
        value = self._binary_buffer_decode(buffer)
        for adapter in reversed(self.value_adapters):
            value = adapter.decode_value(value)
        return value

    cdef _binary_buffer_decode(self, Reader buffer):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement binary_buffer_decode")

    cdef int get_value_fitness(self, value) except -1:
        cdef ValueAdapter adapter
        for adapter in self.value_adapters:
            try:
                value = adapter.encode_value(value)
            except (ValueError, TypeError, InvalidValue):
                return FIT_NONE
        return self._get_value_fitness(value)

    cdef int _get_value_fitness(self, value) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement _get_value_fitness")

    cdef int assert_value(self, object value) except -1:
        cdef int fitness = self.get_value_fitness(value)
        if fitness == FIT_NONE:
            raise ValueError(f"'{value}' not valid for {type(self).__name__}")

    cdef json_format(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement json_format")

    cdef json_decode(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement json_decode")

    cdef CanonicalForm canonical_form(self, set created):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement canonical_form")

    cpdef dict _get_schema_extra(self, set created):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement _get_schema_extra")

    cdef AvroType for_writer(self, AvroType writer):
        if self.canonical_form(set()) == writer.canonical_form(set()):
            return writer
        promoted = self._for_writer(writer)
        if promoted is None:
            raise CannotPromoteError(self, writer)
        return promoted

    cdef AvroType _for_writer(self, AvroType writer):
        pass

    def walk_types(self, visited):
        if self in visited:
            return
        visited.add(self)
        yield self

    cpdef get_schema(self, created=None):
        if created is None:
            created = set()
        if isinstance(self, NamedType):
            type_name = self.type
            if type_name in created:
                return type_name
            else:
                created.add(type_name)

        extra = self._get_schema_extra(created)
        if self.metadata:
            extra.update(self.metadata)
        if extra:
            extra['type'] = self.type_name
            return extra
        else:
            return self.type_name

    def __str__(self):
        if self.options.types_str_to_schema:
            return json.dumps(self.get_schema())
        else:
            return super().__str__()





cdef class NamedType(AvroType):

    cdef readonly str name
    cdef readonly str namespace
    cdef readonly str effective_namespace
    cdef readonly frozenset aliases

    def __init__(self, schema, source, parse_namespace):
        cdef Schema schema_t = schema
        cdef str effective_namespace = None
        super().__init__(schema, source, parse_namespace)
        cdef str name = source['name']
        if '.' in name:
            effective_namespace, name = name.rsplit('.', 1)

        if not schema.options.allow_leading_dot_in_names:
            if effective_namespace == '':
                raise InvalidName(f"The null namespace cannot be specified in name fields")

        name_pattern = schema.options.name_pattern
        if schema.options.enforce_type_name_rules:    
            if not name_pattern.fullmatch(name):
                raise InvalidName(f"Type name '{name}' is not valid")
        
        self.name = name
        self.namespace = source.get('namespace')
        if effective_namespace is None:
            effective_namespace = self.namespace
            if effective_namespace is None:
                effective_namespace = parse_namespace

        self.effective_namespace = effective_namespace or None

        if self.effective_namespace is not None and schema.options.enforce_namespace_name_rules:
            namespace_parts = self.effective_namespace.split('.')
            for part in namespace_parts:
                if not part or not name_pattern.fullmatch(part):
                    raise InvalidName(f"Namespace '{self.effective_namespace}' is not valid")

        if not schema.options.allow_primitive_name_collision:
            if name in PRIMITIVE_TYPES:
                if schema.options.allow_primitive_names_in_namespaces and self.effective_namespace is not None:
                    pass
                else:
                    raise ValueError(f"'{name}' is not allowed as a name")

        self.aliases = frozenset(source.get('aliases', []))
        schema_t.register_type(self.effective_namespace, self.name, self)

    property type:
        def __get__(self):
            return resolve_namespaced_name(self.effective_namespace, self.name)

    cpdef dict _get_schema_extra(self, set created):
        schema = {
            'name': self.name,
        }
        if self.effective_namespace:
            schema['namespace'] = self.effective_namespace
        if self.aliases:
            schema['aliases'] = list(self.aliases)
        return schema

    cdef AvroType clone_base(self):
        cdef NamedType inst = AvroType.clone_base(self)
        inst.name = self.name
        inst.namespace = self.namespace
        inst.effective_namespace = self.effective_namespace
        inst.aliases = self.aliases
        return inst

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {
            'type', 
            'name', 
            'namespace', 
            'aliases', 
        })


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