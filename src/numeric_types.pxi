from libc.float cimport FLT_MIN, FLT_MAX

cdef class IntType(AvroType):
    type_name = "int"

    cdef void binary_buffer_encode(self, MemoryWriter buffer, value):
        zigzag_encode_int(buffer, value)

    cdef object binary_buffer_decode(self, MemoryReader buffer):
        return zigzag_decode_int(buffer)

    cdef bint is_value_valid(self, value):
        if not isinstance(value, int):
            return False
        return value >= INT32_MIN and value <= INT32_MAX

    def json_encode(self,int32_t value):
        return value

    def json_decode(self, value):
        cdef int32_t decoded = value
        return decoded


cdef class LongType(AvroType):
    type_name = "long"

    cdef void binary_buffer_encode(self, MemoryWriter buffer, value):
        zigzag_encode_long(buffer, value)

    cdef object binary_buffer_decode(self, MemoryReader buffer):
        return zigzag_decode_long(buffer)

    cdef bint is_value_valid(self, value):
        if not isinstance(value, int):
            return False
        return value >= INT64_MIN and value <= INT64_MAX

    def json_encode(self,int64_t value):
        return value


cdef class FloatType(AvroType):
    type_name = "float"

    cdef void binary_buffer_encode(self, MemoryWriter buffer, value):
        cdef float float_val = value
        cdef uint32_t *int_val = <uint32_t*>&float_val
        buffer.write32(int_val[0])

    cdef bint is_value_valid(self, value):
        try:
            float_val = float(value)
        except TypeError:
            return False
        return float_val > FLT_MIN and float_val < FLT_MAX

    def json_encode(self, value):
        return float(value)


cdef class DoubleType(AvroType):
    type_name = "double"

    cdef void binary_buffer_encode(self, MemoryWriter buffer, value):
        cdef double float_val = value
        cdef uint64_t *int_val = <uint64_t*>&float_val
        buffer.write64(int_val[0])

    cdef bint is_value_valid(self, value):
        try:
            float_val = float(value)
        except TypeError:
            return False
        return True

    def json_encode(self, value):
        return float(value)

