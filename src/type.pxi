
cdef int FIT_NONE = 0
cdef int FIT_POOR = 1
cdef int FIT_OK = 2
cdef int FIT_EXACT = 3

cdef class AvroType:
    type_name = NotImplemented

    @classmethod
    def for_source(cls, schema, source, namespace=None):
        if isinstance(source, (list, tuple)):
            return UnionType(schema, source, namespace)
        if isinstance(source, str):
            if source in PRIMITIVE_TYPES:
                return PRIMITIVE_TYPES[source](schema, source, namespace)
            return schema.find_type(namespace, source)
        type_name = source['type']
        return TYPES_BY_NAME[type_name](schema, source, namespace)

    @classmethod
    def for_schema(cls, schema):
        return AvroType.for_source(schema, schema.source)

    def __init__(self, schema, source, namespace):
        pass

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement binary_buffer_encode")

    cdef binary_buffer_decode(self, Reader buffer):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement binary_buffer_decode")

    cdef int get_value_fitness(self, value) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement get_value_fitness")

    def binary_encode(self, value):
        cdef MemoryWriter buffer = MemoryWriter()
        self.binary_buffer_encode(buffer, value)
        return buffer.bytes()

    def binary_decode(self, bytes value):
        cdef MemoryReader buffer = MemoryReader(value)
        return self.binary_buffer_decode(buffer)

    def json_encode(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement json_encode")

    def json_decode(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement json_encode")


cdef class NamedType(AvroType):

    cdef readonly str name
    cdef readonly str namespace
    cdef readonly frozenset aliases

    def __init__(self, schema, source, namespace):
        cdef Schema schema_t = schema
        cdef str name = source['name']
        if not schema.permissive:
            if name in PRIMITIVE_TYPES:
                raise ValueError(f"'{name}' is not allowed as a name")
        self.name = name
        self.namespace = source.get('namespace')
        self.aliases = frozenset(source.get('aliases', []))
        schema_t.register_type(self.namespace, self.name, self)


PRIMITIVE_TYPES = {
    'null': NullType,
    'bool': BoolType,
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
