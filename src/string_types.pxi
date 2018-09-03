
cdef class BytesType(AvroType):
    type_name = "bytes"

    pass


cdef class StringType(AvroType):
    type_name = "string"

    cdef binary_buffer_encode(self, MemoryBuffer buffer, value):
        if isinstance(value, str):
            value = value.encode('utf-8')
        cdef size_t length = len(value)
        zigzag_encode_long(buffer, length)
        if length:
            buffer.writeN(length, value)


cdef class FixedType(AvroType):
    type_name = "fixed"
    