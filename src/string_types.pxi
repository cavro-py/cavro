
cdef class BytesType(AvroType):
    type_name = "bytes"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if isinstance(value, str):
            value = value.encode('utf-8')
        cdef size_t length = len(value)
        zigzag_encode_long(buffer, length)
        if length:
            buffer.write_n(length, value)

    cdef binary_buffer_decode(self, Reader buffer):
        cdef uint64_t length = zigzag_decode_long(buffer)
        return bytes(buffer.read_n(length))

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, bytes):
            return FIT_EXACT
        if isinstance(value, str):
            return FIT_POOR
        return FIT_NONE

cdef class StringType(AvroType):
    type_name = "string"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if isinstance(value, str):
            value = value.encode('utf-8')
        cdef size_t length = len(value)
        zigzag_encode_long(buffer, length)
        if length:
            buffer.write_n(length, value)

    cdef binary_buffer_decode(self, Reader buffer):
        cdef uint64_t length = zigzag_decode_long(buffer)
        return bytes(buffer.read_n(length)).decode('utf-8')

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, bytes):
            return FIT_POOR
        if isinstance(value, str):
            return FIT_EXACT
        return FIT_NONE


cdef class FixedType(NamedType):
    type_name = "fixed"

    cdef readonly size_t size

    def __init__(self, schema, source, namespace):
        NamedType.__init__(self, schema, source, namespace)
        self.size = source['size']

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if isinstance(value, str):
            value = value.encode('utf-8')
        cdef size_t length = len(value)
        if length != self.size:
            raise ValueError(f"Invalid length for fixed field: {length} != {self.size}")
        buffer.write_n(length, value)

    cdef binary_buffer_decode(self, Reader buffer):
        return bytes(buffer.read_n(self.size))

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, bytes) and len(value) == self.size:
            return FIT_EXACT
        return FIT_NONE
