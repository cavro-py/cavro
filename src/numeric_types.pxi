from libc.float cimport FLT_MAX, DBL_MAX
from cpython cimport bool as py_bool
from numpy import bool_

from math import isnan, isinf

cdef float FLOAT_INT_THRESHOLD = 0.001

cdef class BoolType(AvroType):
    type_name = "boolean"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        if value:
            buffer.write_u8(1)
        else:
            buffer.write_u8(0)

    cdef object binary_buffer_decode(self, Reader buffer):
        return py_bool(buffer.read_u8())

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, (py_bool, bool_)):
            return FIT_EXACT
        else:
            return FIT_POOR

    cpdef object _convert_value(self, object value):
        return py_bool(value)

    def json_format(self, value):
        return py_bool(value)

    def json_decode(self, value):
        cdef py_bool decoded = value
        return decoded

    cdef str canonical_form(self):
        return '"boolean"'


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

    cpdef object _convert_value(self, object value):
        return int(value)

    def json_format(self,int32_t value):
        return value

    def json_decode(self, value):
        cdef int32_t decoded = value
        return decoded

    cdef str canonical_form(self):
        return '"int"'


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

    cpdef object _convert_value(self, object value):
        return int(value)

    def json_format(self,int64_t value):
        return value

    cdef str canonical_form(self):
        return '"long"'


cdef class FloatType(AvroType):
    type_name = "float"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef float float_val = value
        cdef uint8_t *int_val = <uint8_t*>&float_val
        buffer.write_n(4, int_val)

    cdef binary_buffer_decode(self, Reader buffer):
        cdef const uint8_t[:] val = buffer.read_n(4)
        return (<float*>(&val[0]))[0]

    cdef int get_value_fitness(self, value) except -1:
        cdef int level
        if isinstance(value, float):
            level = FIT_EXACT
        elif isinstance(value, py_bool):
            return FIT_POOR
        elif isinstance(value, int):
            try:
                value = float(value)
            except OverflowError:
                return FIT_NONE
            level = FIT_OK
        else:
            return FIT_NONE
        if value >= -FLT_MAX and value <= FLT_MAX or isnan(value) or isinf(value):
            return level
        else:
            return FIT_NONE

    cpdef object _convert_value(self, object value):
        return float(value)

    def json_format(self, value):
        return float(value)

    cdef str canonical_form(self):
        return '"float"'


cdef class DoubleType(AvroType):
    type_name = "double"

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef double float_val = value
        cdef uint8_t *int_val = <uint8_t*>&float_val
        buffer.write_n(8, int_val)

    cdef binary_buffer_decode(self, Reader buffer):
        cdef const uint8_t[:] val = buffer.read_n(8)
        return (<double*>(&val[0]))[0]

    cdef int get_value_fitness(self, value) except -1:
        cdef int level
        if isinstance(value, float):
            return FIT_EXACT
        elif isinstance(value, py_bool):
            return FIT_POOR
        elif isinstance(value, int):
            # This could overflow here int(1e1000), but there is no
            # data type in avro that can store 1e1000 numerically,
            # so accepting this value, and then raising on encoding
            # seems reasonable
            return FIT_OK
        else:
            level = FIT_NONE

    cpdef object _convert_value(self, object value):
        return float(value)

    def json_format(self, value):
        return float(value)

    cdef str canonical_form(self):
        return '"double"'

