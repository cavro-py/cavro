
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

    cdef binary_buffer_encode(self, MemoryBuffer buffer, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement binary_buffer_encode")

    cdef bint is_value_valid(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement is_value_valid")

    def binary_encode(self, value):
        cdef MemoryBuffer buffer = MemoryBuffer()
        self.binary_buffer_encode(buffer, value)
        return buffer.bytes()

    def json_encode(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement json_encode")


cdef class NamedType(AvroType):

    cdef str name
    cdef str namespace
    cdef list aliases

    def __init__(self, schema, source, namespace):
        cdef Schema schema_t = schema
        self.name = source['name']
        self.namespace = source.get('namespace')
        self.aliases = source.get('aliases')
        schema_t.register_type(self.namespace, self.name, self)


include "numeric_types.pxi"
include "string_types.pxi"
include "union.pxi"
include "enum.pxi"
include "map.pxi"
include "record.pxi"


PRIMITIVE_TYPES = {
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
    enum=EnumType
)
