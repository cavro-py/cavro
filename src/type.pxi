
cdef class AvroType:

    @classmethod
    def for_source(cls, schema, source, namespace=None):
        if isinstance(source, (list, tuple)):
            return UnionType(schema, source, namespace)
        if isinstance(source, str):
            if source in PRIMITIVE_TYPES:
                return PRIMITIVE_TYPES[source](schema, source, namespace)
            return schema.find_type(namespace, source)
        type_name = source['type']

    @classmethod
    def for_schema(cls, schema):
        return AvroType.for_source(schema, schema.source)

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


include "numeric_types.pxi"
include "string_types.pxi"
include "union.pxi"


PRIMITIVE_TYPES = {
    'int': IntType,
    'long': LongType,
    'float': FloatType,
    'double': DoubleType,
    'bytes': BytesType,
    'string': StringType,
}