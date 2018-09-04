
cdef class BytesType(AvroType):
    type_name = "bytes"

    cdef void binary_buffer_encode(self, MemoryWriter buffer, value):
        if isinstance(value, str):
            value = value.encode('utf-8')
        cdef size_t length = len(value)
        zigzag_encode_long(buffer, length)
        if length:
            buffer.writeN(length, value)


cdef class StringType(AvroType):
    type_name = "string"

    cdef void binary_buffer_encode(self, MemoryWriter buffer, value):
        if isinstance(value, str):
            value = value.encode('utf-8')
        cdef size_t length = len(value)
        zigzag_encode_long(buffer, length)
        if length:
            buffer.writeN(length, value)


cdef class FixedType(NamedType):
    type_name = "fixed"

    cdef size_t size

    def __init__(self, schema, source, namespace):
        NamedType.__init__(schema, source, namespace)
        self.size = source['size']

    cdef void binary_buffer_encode(self, MemoryWriter buffer, value):
        if isinstance(value, str):
            value = value.encode('utf-8')
        cdef size_t length = len(value)
        if length != self.size:
            raise ValueError(f"Invalid length for fixed field: {length} != {self.size}")
        buffer.writeN(length, value)