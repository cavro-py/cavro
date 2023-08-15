from libc.float cimport FLT_MAX, DBL_MAX
from cpython cimport bool as py_bool
from numpy import bool_, integer

from math import isnan, isinf

cdef float FLOAT_INT_THRESHOLD = 0.001

cdef class BoolType(AvroType):
    type_name = "boolean"

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {'type'})

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef bint bool_val = self._convert_value(value)
        buffer.write_u8(bool_val)

    cdef object binary_buffer_decode(self, Reader buffer):
        return py_bool(buffer.read_u8())

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, (py_bool, bool_)):
            return FIT_EXACT
        if self.options.coerce_values_to_boolean:
            try:
                py_bool(value)
            except (ValueError, TypeError):
                return FIT_NONE
            return FIT_POOR
        return FIT_NONE

    cpdef object _convert_value(self, object value):
        if isinstance(value, (py_bool, bool_)):
            return value
        if self.options.coerce_values_to_boolean:
            return py_bool(value)
        raise ValueError(f"Invalid value for boolean: {value}")

    def json_format(self, value):
        return self._convert_value(value)

    def json_decode(self, value):
        cdef py_bool decoded = value
        return decoded

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"boolean"')


cdef class IntType(AvroType):
    type_name = "int"

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {'type'})

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        value = self._convert_value(value)
        zigzag_encode_int(buffer, value)

    cdef binary_buffer_decode(self, Reader buffer):
        return zigzag_decode_int(buffer)

    cdef int get_value_fitness(self, value) except -1:
        max_fit = FIT_EXACT
        if not isinstance(value, (int, integer)):
            if not self.options.coerce_values_to_int:
                return FIT_NONE
            try:
                new_value = int(value)
                max_fit = FIT_OK if new_value == value else FIT_POOR
            except (ValueError, TypeError):
                return FIT_NONE
            value = new_value

        if value > INT32_MAX or value < INT32_MIN:
            return FIT_POOR if self.options.clamp_int_overflow else FIT_NONE

        return max_fit
        
    cpdef object _convert_value(self, object value):
        if not isinstance(value, int):
            if self.options.coerce_values_to_int or isinstance(value, integer):
                value = int(value)
            else:
                raise ValueError(f"Invalid value for int: {value}")
        if value > INT32_MAX:
            if self.options.clamp_int_overflow:
                return INT32_MAX 
        elif value < INT32_MIN:
            if self.options.clamp_int_overflow:
                return INT32_MIN
        else:
            return value
        raise OverflowError(f"Value {value} out of range for int")

    def json_format(self,object value):
        return self._convert_value(value)

    def json_decode(self, value):
        cdef int32_t decoded = value
        return decoded

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"int"')


cdef class LongType(AvroType):
    type_name = "long"

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {'type'})

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        value = self._convert_value(value)
        zigzag_encode_long(buffer, value)

    cdef binary_buffer_decode(self, Reader buffer):
        return zigzag_decode_long(buffer)

    cdef int get_value_fitness(self, value) except -1:
        max_fit = FIT_EXACT
        if not isinstance(value, (int, integer)):
            if not self.options.coerce_values_to_int:
                return FIT_NONE
            try:
                new_value = int(value)
                max_fit = FIT_OK if new_value == value else FIT_POOR
            except (ValueError, TypeError):
                return FIT_NONE
            value = new_value

        if value > INT64_MAX or value < INT64_MIN:
            return FIT_POOR if self.options.clamp_int_overflow else FIT_NONE

        return max_fit
        
    cpdef object _convert_value(self, object value):
        if not isinstance(value, int):
            if self.options.coerce_values_to_int or isinstance(value, integer):
                value = int(value)
            else:
                raise ValueError(f"Invalid value for long: {value}")
        if value > INT64_MAX:
            if self.options.clamp_int_overflow:
                return INT64_MAX 
        elif value < INT64_MIN:
            if self.options.clamp_int_overflow:
                return INT64_MIN
        else:
            return value
        raise OverflowError(f"Value {value} out of range for long")

    def json_format(self, object value):
        return self._convert_value(value)

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"long"')


cdef class FloatType(AvroType):
    type_name = "float"

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {'type'})

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef float float_val = self._convert_value(value)
        cdef uint8_t *int_val = <uint8_t*>&float_val
        buffer.write_n(int_val[:4])

    cdef binary_buffer_decode(self, Reader buffer):
        cdef const uint8_t[:] val = buffer.read_n(4)
        return (<float*>(&val[0]))[0]

    cdef int get_value_fitness(self, value) except -1:
        max_fit = FIT_EXACT
        if not isinstance(value, float):
            max_fit = FIT_OK
            if isinstance(value, (int, integer)) and self.options.coerce_int_to_float and not isinstance(value, (py_bool, bool_)):
                try:
                    value = float(value)
                except OverflowError:
                    return FIT_POOR if self.options.clamp_float_overflow else FIT_NONE
            else:
                max_fit = FIT_POOR
                if not self.options.coerce_values_to_float:
                    return FIT_NONE
                try:
                    value = float(value)
                except (ValueError, TypeError, OverflowError):
                    return FIT_NONE
        
        if self.options.truncate_float:
            return max_fit

        if value >= -FLT_MAX and value <= FLT_MAX or isnan(value) or isinf(value):
            return max_fit
        return FIT_NONE

    cpdef object _convert_value(self, object value):
        if not isinstance(value, float):
            if isinstance(value, (int, integer)) and self.options.coerce_int_to_float and not isinstance(value, (py_bool, bool_)):
                value = float(value)
            else:
                if self.options.coerce_values_to_float:
                    try:
                        value = float(value)
                    except OverflowError:
                        if self.options.clamp_float_overflow:
                            return FLT_MAX
                        else:
                            raise
                else:
                    raise ValueError(f"Invalid value for float: '{value}'")
        if value < -FLT_MAX:
            if self.options.clamp_float_overflow:
                return -FLT_MAX
        elif value > FLT_MAX:
            if self.options.clamp_float_overflow:
                return FLT_MAX
        elif isnan(value):
            if self.options.clamp_float_overflow:
                return 0.0
        elif isinf(value):
            if self.options.clamp_float_overflow:
                return FLT_MAX
        else:
            return value
        raise OverflowError(f"Value {value} out of range for float")

    def json_format(self, value):
        return self._convert_value(value)

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"float"')


cdef class DoubleType(AvroType):
    type_name = "double"

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {'type'})

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef double float_val = self._convert_value(value)
        cdef uint8_t *int_val = <uint8_t*>&float_val
        buffer.write_n(int_val[:8])

    cdef binary_buffer_decode(self, Reader buffer):
        cdef const uint8_t[:] val = buffer.read_n(8)
        return (<double*>(&val[0]))[0]

    cdef int get_value_fitness(self, value) except -1:
        max_fit = FIT_EXACT
        if not isinstance(value, float):
            max_fit = FIT_OK
            if isinstance(value, (int, integer)) and self.options.coerce_int_to_float and not isinstance(value, (py_bool, bool_)):
                try:
                    value = float(value)
                except OverflowError:
                    return FIT_POOR if self.options.clamp_float_overflow else FIT_NONE
            else:
                max_fit = FIT_POOR
                if not self.options.coerce_values_to_float:
                    return FIT_NONE
                try:
                    value = float(value)
                except (ValueError, TypeError, OverflowError):
                    return FIT_NONE
        
        return max_fit

    cpdef object _convert_value(self, object value):
        if not isinstance(value, float):
            if isinstance(value, (int, integer)) and self.options.coerce_int_to_float and not isinstance(value, (py_bool, bool_)):
                value = float(value)
            else:
                if self.options.coerce_values_to_float:
                    try:
                        value = float(value)
                    except OverflowError:
                        if self.options.clamp_float_overflow:
                            return FLT_MAX
                        else:
                            raise
                else:
                    raise ValueError(f"Invalid value for float: '{value}'")
        if isnan(value):
            if self.options.clamp_float_overflow:
                return 0.0
        elif isinf(value):
            if self.options.clamp_float_overflow:
                return FLT_MAX
        else:
            return value
        raise OverflowError(f"Value {value} out of range for float")

    def json_format(self, value):
        return self._convert_value(value)

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"double"')

