
cdef class BytesType(AvroType):
    type_name = "bytes"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if isinstance(value, str):
            value = value.encode('utf-8')
        cdef Py_ssize_t length = len(value)
        zigzag_encode_long(buffer, length)
        if length:
            buffer.write_n(length, value)

    cdef binary_buffer_decode(self, Reader buffer):
        cdef uint64_t length = zigzag_decode_long(buffer)
        return buffer.read_bytes(length)

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, bytes):
            return FIT_EXACT
        if isinstance(value, str):
            return FIT_POOR
        return FIT_NONE

    def json_format(self, value):
        if isinstance(value, bytes):
            value = value.decode('latin-1')
        return value

    cpdef object _convert_value(self, object value):
        if isinstance(value, str):
            value = value.encode('latin-1')
        return value

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"bytes"')


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
        return buffer.read_bytes(length).decode('utf-8')

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, str):
            return FIT_EXACT
        if isinstance(value, (bytes, int, float)):
            return FIT_POOR
        return FIT_NONE

    def json_format(self, value):
        if isinstance(value, bytes):
            value = value.decode('utf-8')
        return value

    cpdef object _convert_value(self, object value):
        if isinstance(value, str):
            return value
        if isinstance(value, bytes):
            return value.decode('utf-8')
        return str(value)

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"string"')


cdef class FixedType(NamedType):
    type_name = "fixed"

    cdef readonly Py_ssize_t size

    def __init__(self, schema, source, namespace):
        super().__init__(schema, source, namespace)
        self.size = source['size']

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if isinstance(value, str):
            value = value.encode('utf-8')
        cdef Py_ssize_t length = len(value)
        if length != self.size:
            raise ValueError(f"Invalid length for fixed field: {length} != {self.size}")
        buffer.write_n(length, value)

    cdef binary_buffer_decode(self, Reader buffer):
        return bytes(buffer.read_n(self.size))

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, bytes) and len(value) == self.size:
            return FIT_EXACT
        return FIT_NONE

    def json_format(self, value):
        if isinstance(value, str):
            value = value.encode('utf-8')
        if len(value) != self.size:
            raise ValueError(f"Value is not correct length for fixed type: {value}")
        return value

    cpdef object _convert_value(self, object value):
        return value

    cdef CanonicalForm canonical_form(self, set created):
        if self in created:
            return self.get_type_name()
        created.add(self)
        return dict_to_canonical({
            'type': 'fixed',
            'name': self.get_type_name(),
            'size': self.size
        })