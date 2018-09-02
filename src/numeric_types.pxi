

cdef class IntType(AvroType):
    type_name = "int"

    cdef binary_buffer_encode(self, MemoryBuffer buffer, value):
        zigzag_encode_int(buffer, value)

    cdef bint is_value_valid(self, value):
        if not isinstance(value, int):
            return False
        return value >= INT32_MIN and value <= INT32_MAX

cdef class LongType(AvroType):
    type_name = "long"

    cdef binary_buffer_encode(self, MemoryBuffer buffer, value):
        zigzag_encode_long(buffer, value)

    cdef bint is_value_valid(self, value):
        if not isinstance(value, int):
            return False
        return value >= INT64_MIN and value <= INT64_MAX


cdef class FloatType(AvroType):

    pass


cdef class DoubleType(AvroType):

    pass