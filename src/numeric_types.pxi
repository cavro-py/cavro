from libc.float cimport FLT_MAX
from cpython cimport bool as py_bool

from math import isnan, isinf

cdef float FLOAT_INT_THRESHOLD = 0.001

cdef class BoolType(AvroType):
    type_name = "bool"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if value:
            buffer.write_u8(1)
        else:
            buffer.write_u8(0)

    cdef object binary_buffer_decode(self, Reader buffer):
        return bool(buffer.read_u8())

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, bool):
            return FIT_EXACT
        else:
            return FIT_POOR

    def json_encode(self,py_bool value):
        return value

    def json_decode(self, value):
        cdef py_bool decoded = value
        return decoded


cdef class IntType(AvroType):
    type_name = "int"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        zigzag_encode_int(buffer, value)

    cdef binary_buffer_decode(self, Reader buffer):
        return zigzag_decode_int(buffer)

    cdef int get_value_fitness(self, value) except -1:
        cdef int level
        if isinstance(value, int):
            level = FIT_EXACT
        elif isinstance(value, float):
            if isnan(value) or isinf(value):
                return FIT_NONE
            elif value == int(value):
                level = FIT_OK
            elif value - int(value) < FLOAT_INT_THRESHOLD:
                level = FIT_POOR
            else:
                return FIT_NONE
        else:
            return FIT_NONE
        if value >= INT32_MIN and value <= INT32_MAX:
            return level
        return FIT_NONE

    def json_encode(self,int32_t value):
        return value

    def json_decode(self, value):
        cdef int32_t decoded = value
        return decoded


cdef class LongType(AvroType):
    type_name = "long"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        zigzag_encode_long(buffer, value)

    cdef binary_buffer_decode(self, Reader buffer):
        return zigzag_decode_long(buffer)

    cdef int get_value_fitness(self, value) except -1:
        cdef int level
        if isinstance(value, int):
            level = FIT_EXACT
        elif isinstance(value, float):
            if isnan(value) or isinf(value):
                return FIT_NONE
            elif value == int(value):
                level = FIT_OK
            else:
                return FIT_POOR
        else:
            return FIT_NONE
        if value >= INT64_MIN and value <= INT64_MAX:
            return level
        return FIT_NONE

    def json_encode(self,int64_t value):
        return value


cdef class FloatType(AvroType):
    type_name = "float"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef float float_val = value
        cdef uint32_t *int_val = <uint32_t*>&float_val
        buffer.write_to64(int_val[0], 4)

    cdef binary_buffer_decode(self, Reader buffer):
        cdef uint32_t val = buffer.read_to_u32(4).u32
        return (<float*>(&val))[0]

    cdef int get_value_fitness(self, value) except -1:
        cdef int level
        if isinstance(value, (float, int)):
            level = FIT_OK
        else:
            return FIT_NONE
        if value >= -FLT_MAX and value <= FLT_MAX or isnan(value) or isinf(value):
            return level

    def json_encode(self, value):
        return float(value)


cdef class DoubleType(AvroType):
    type_name = "double"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef double float_val = value
        cdef uint64_t *int_val = <uint64_t*>&float_val
        buffer.write_to64(int_val[0], 8)

    cdef binary_buffer_decode(self, Reader buffer):
        cdef uint64_t val = buffer.read_to64(8).u64
        return (<double*>(&val))[0]

    cdef int get_value_fitness(self, value) except -1:
        cdef int level
        if isinstance(value, float):
            return FIT_EXACT
        elif isinstance(value, int):
            return FIT_OK
        else:
            return FIT_NONE

    def json_encode(self, value):
        return float(value)

