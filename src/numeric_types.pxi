from libc.float cimport FLT_MAX, DBL_MAX
from cpython cimport bool as py_bool
from numpy import bool_, integer, float16 as np_f16, float32 as np_f32, float64 as np_f64
import numpy as np

from math import isnan, isinf

cdef float FLOAT_INT_THRESHOLD = 0.001

@cython.final
cdef class BoolType(AvroType):
    """The avro boolean type."""
    type_name = "boolean"

    cpdef AvroType copy(self):
        return self.clone_base()

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type'})

    cpdef dict _get_schema_extra(self, set created):
        return {}

    cdef int _binary_buffer_encode(self, _Writer buffer, value) except -1:
        cdef bint bool_val = self._convert_value(value)
        buffer.write_u8(bool_val)

    cdef object _binary_buffer_decode(self, _Reader buffer):
        return py_bool(buffer.read_u8())

    cdef int _get_value_fitness(self, value) except -1:
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
        raise InvalidValue(value, self)

    cdef _json_format(self, value):
        return self._convert_value(value)

    cdef _json_decode(self, value):
        cdef py_bool decoded = value
        return decoded

    cdef _CanonicalForm canonical_form(self, set created):
        return _CanonicalForm('"boolean"')


@cython.final
cdef class IntType(AvroType):
    """The avro int type."""
    type_name = "int"

    cpdef AvroType copy(self):
        return self.clone_base()

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type'})

    cpdef dict _get_schema_extra(self, set created):
        return {}

    cdef int _binary_buffer_encode(self, _Writer buffer, value) except -1:
        value = self._convert_value(value)
        zigzag_encode_int(buffer, value)

    cdef _binary_buffer_decode(self, _Reader buffer):
        return zigzag_decode_int(buffer)

    cdef int _get_value_fitness(self, value) except -1:
        max_fit = FIT_EXACT
        if isinstance(value, (bool_, py_bool)):
            return FIT_POOR if self.options.coerce_values_to_int else FIT_NONE
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
        if not self.options.coerce_values_to_int and isinstance(value, (bool_, py_bool)):
            raise ValueError(f'{value} not valid for long')
        if not isinstance(value, int):
            if self.options.coerce_values_to_int or isinstance(value, integer):
                value = int(value)
            else:
                raise InvalidValue(value, self)
        if value > INT32_MAX:
            if self.options.clamp_int_overflow:
                return INT32_MAX 
        elif value < INT32_MIN:
            if self.options.clamp_int_overflow:
                return INT32_MIN
        else:
            return value
        raise InvalidValue(value, self)

    cdef _json_format(self, value):
        return self._convert_value(value)

    cdef _json_decode(self, value):
        if isinstance(value, (float, py_bool, bool_)) or not isinstance(value, int):
            raise InvalidValue(value, self)
        if value < INT32_MIN or value > INT32_MAX:
            raise InvalidValue(value, self)
        return value

    cdef _CanonicalForm canonical_form(self, set created):
        return _CanonicalForm('"int"')


@cython.final
cdef class LongType(AvroType):
    """The avro long type."""
    type_name = "long"

    cpdef AvroType copy(self):
        return self.clone_base()

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type'})

    cpdef dict _get_schema_extra(self, set created):
        return {}

    cdef int _binary_buffer_encode(self, _Writer buffer, value) except -1:
        value = self._convert_value(value)
        zigzag_encode_long(buffer, value)

    cdef _binary_buffer_decode(self, _Reader buffer):
        return zigzag_decode_long(buffer)

    cdef int _get_value_fitness(self, value) except -1:
        max_fit = FIT_EXACT
        if isinstance(value, (bool_, py_bool)):
            return FIT_POOR if self.options.coerce_values_to_int else FIT_NONE
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
        if not self.options.coerce_values_to_int and isinstance(value, (bool_, py_bool)):
            raise ValueError(f'{value} not valid for long')
        if not isinstance(value, int):
            if self.options.coerce_values_to_int or isinstance(value, integer):
                value = int(value)
            else:
                raise InvalidValue(value, self)
        if value > INT64_MAX:
            if self.options.clamp_int_overflow:
                return INT64_MAX 
        elif value < INT64_MIN:
            if self.options.clamp_int_overflow:
                return INT64_MIN
        else:
            return value
        raise InvalidValue(value, self)

    cdef json_format(self, object value):
        return self._convert_value(value)

    cdef _json_decode(self, value):
        if isinstance(value, (float, py_bool, bool_)) or not isinstance(value, int):
            raise InvalidValue(value, self)
        if value < INT64_MIN or value > INT64_MAX:
            raise InvalidValue(value, self)
        return value

    cdef _CanonicalForm canonical_form(self, set created):
        return _CanonicalForm('"long"')

    cdef AvroType _for_writer(self, AvroType writer):
        if isinstance(writer, IntType):
            return writer # Int is a subset of Long


@cython.final
cdef class FloatType(AvroType):
    """The avro float type."""
    type_name = "float"

    cpdef AvroType copy(self):
        return self.clone_base()

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type'})

    cpdef dict _get_schema_extra(self, set created):
        return {}

    cdef int _binary_buffer_encode(self, _Writer buffer, value) except -1:
        cdef float float_val = self._convert_value(value)
        cdef uint8_t *int_val = <uint8_t*>&float_val
        buffer.write_n(int_val[:4])

    cdef _binary_buffer_decode(self, _Reader buffer):
        cdef const uint8_t[:] val = buffer.read_n(4)
        return (<float*>(&val[0]))[0]

    cdef int _get_value_fitness(self, value) except -1:
        max_fit = FIT_EXACT
        if not isinstance(value, (float, np_f16, np_f32)):
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
        
        if self.options.clamp_float_overflow or self.options.float_out_of_range_inf:
            return max_fit

        if (value >= -FLT_MAX and value <= FLT_MAX) or isnan(value) or isinf(value):
            return max_fit
        return FIT_NONE

    cpdef object _convert_value(self, object value):
        if isinstance(value, float):
            pass
        elif isinstance(value, (np_f16, np_f32)):
            value = float(value)
        else:
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
                    raise InvalidValue(value, self)
        
        if isnan(value):
            if self.options.clamp_float_overflow and not self.options.float_out_of_range_inf:
                return 0.0
            return value
        if isinf(value):
            if self.options.clamp_float_overflow and not self.options.float_out_of_range_inf:
                return FLT_MAX if value > 0 else -FLT_MAX
            return value
        if value < -FLT_MAX:
            if self.options.clamp_float_overflow:
                return -FLT_MAX
            if self.options.float_out_of_range_inf:
                return float('-inf')
            raise InvalidValue(value, self)
        elif value > FLT_MAX:
            if self.options.clamp_float_overflow:
                return FLT_MAX
            if self.options.float_out_of_range_inf:
                return float('inf')
            raise InvalidValue(value, self)
        else:
            return value

    cdef _json_format(self, value):
        return self._convert_value(value)

    cdef _json_decode(self, value):
        if isinstance(value, (py_bool, bool_)):
            raise InvalidValue(value, self)
        if value in ('nan', 'inf', '-inf'):
            return float(value)
        if not isinstance(value, (float, int)):
            raise InvalidValue(value, self)
        if (value < -FLT_MAX or value > FLT_MAX) and not isnan(value) and not isinf(value):
            raise InvalidValue(value, self)
        return value

    cdef _CanonicalForm canonical_form(self, set created):
        return _CanonicalForm('"float"')

    cdef AvroType _for_writer(self, AvroType writer):
        if isinstance(writer, (IntType, LongType)):
            promoted = writer.clone_base()
            promoted.value_adapters = promoted.value_adapters + (PromoteToFloat(),)
            return promoted


@cython.final
cdef class DoubleType(AvroType):
    """The avro double type."""
    type_name = "double"

    cpdef AvroType copy(self):
        return self.clone_base()

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type'})

    cpdef dict _get_schema_extra(self, set created):
        return {}

    cdef int _binary_buffer_encode(self, _Writer buffer, value) except -1:
        cdef double float_val = self._convert_value(value)
        cdef uint8_t *int_val = <uint8_t*>&float_val
        buffer.write_n(int_val[:8])

    cdef _binary_buffer_decode(self, _Reader buffer):
        cdef const uint8_t[:] val = buffer.read_n(8)
        return (<double*>(&val[0]))[0]

    cdef int _get_value_fitness(self, value) except -1:
        max_fit = FIT_EXACT
        if not isinstance(value, (float, np_f16, np_f32, np_f64)):
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
        if isinstance(value, float):
            pass
        elif isinstance(value, (np_f16, np_f32, np_f64)):
            value = float(value)
        else:
            if isinstance(value, (int, integer)) and self.options.coerce_int_to_float and not isinstance(value, (py_bool, bool_)):
                value = float(value)
            else:
                if self.options.coerce_values_to_float:
                    try:
                        value = float(value)
                    except OverflowError:
                        if self.options.clamp_float_overflow:
                            return DBL_MAX
                        else:
                            raise
                else:
                    raise InvalidValue(value, self)
        if isnan(value):
            if self.options.clamp_float_overflow:
                return 0.0
        elif  (value):
            if self.options.clamp_float_overflow:
                return DBL_MAX
        
        return value

    cdef _json_format(self, value):
        return self._convert_value(value)

    cdef _json_decode(self, value):
        if isinstance(value, (py_bool, bool_)):
            raise InvalidValue(value, self)
        if not isinstance(value, (float, int)):
            raise InvalidValue(value, self)
        return value

    cdef _CanonicalForm canonical_form(self, set created):
        return _CanonicalForm('"double"')

    cdef AvroType _for_writer(self, AvroType writer):
        cdef AvroType promoted
        if isinstance(writer, FloatType):
            return writer
        if isinstance(writer, (IntType, LongType)):
            promoted = writer.clone_base()
            promoted.value_adapters = promoted.value_adapters + (PromoteToFloat(),)
            return promoted
