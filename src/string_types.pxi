
@cython.final
cdef class BytesType(AvroType):
    type_name = "bytes"

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {'type'})

    cpdef dict _get_schema_extra(self, set created):
        return {}

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        value = self.convert_value(value)
        cdef Py_ssize_t length = len(value)
        zigzag_encode_long(buffer, length)
        if length:
            buffer.write_n(value)

    cdef _binary_buffer_decode(self, Reader buffer):
        cdef uint64_t length = zigzag_decode_long(buffer)
        return buffer.read_bytes(length)

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, bytes):  # If bytes, we're good
            return FIT_EXACT
        # If there's a bytes_codec, then if we get get value to be a str, then we have a way through
        if not self.options.bytes_codec:
            return FIT_NONE
        # We may be allowed to coerce to str
        MAX_FIT = FIT_OK
        if not isinstance(value, str):
            MAX_FIT = FIT_POOR
            if self.options.coerce_values_to_str:
                value = str(value)
            else:
                return FIT_NONE # We can't get a str

        # We now know that value is str and we have a codec       
        try:
            value.encode(self.options.bytes_codec)
        except (TypeError, ValueError, UnicodeEncodeError):
            return FIT_NONE
        return MAX_FIT

    cdef json_format(self, value):
        value = self.convert_value(value)
        return value.decode('latin-1')

    cdef json_decode(self, value):
        cdef str sval = value
        return sval.encode('latin-1')

    cpdef object _convert_value(self, object value):
        if isinstance(value, bytes):
            return value
        codec = self.options.bytes_codec
        if not codec:
            raise ValueError(f"Invalid value for bytes: '{value}'")
        if not isinstance(value, str):
            if self.options.coerce_values_to_str:
                value = str(value)
            raise ValueError(f"Invalid value for bytes: '{value}'")
        # We have a str, and codec
        return value.encode(codec)

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"bytes"')


@cython.final
cdef class StringType(AvroType):
    type_name = "string"

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {'type'})

    cpdef dict _get_schema_extra(self, set created):
        return {}

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        value = self._convert_value(value).encode('utf8')
        cdef size_t length = len(value)
        zigzag_encode_long(buffer, length)
        if length:
            buffer.write_n(value)

    cdef _binary_buffer_decode(self, Reader buffer):
        cdef uint64_t length = zigzag_decode_long(buffer)
        return buffer.read_bytes(length).decode('utf-8')

    cdef int get_value_fitness(self, value) except -1:
        if isinstance(value, str):
            return FIT_EXACT
        if self.options.coerce_values_to_str:
            if isinstance(value, bytes):
                return FIT_OK
            return FIT_POOR
        return FIT_NONE

    cdef json_format(self, value):
        return self._convert_value(value)

    cdef json_decode(self, value):
        cdef str sval = value
        return sval

    cpdef object _convert_value(self, object value):
        if isinstance(value, str):
            return value
        if not self.options.coerce_values_to_str:
            raise TypeError(f"Invalid value for string: '{value}'")
        if isinstance(value, bytes):
            return value.decode()
        return str(value)

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"string"')


@cython.final
cdef class FixedType(NamedType):
    type_name = "fixed"

    cdef readonly Py_ssize_t size

    def __init__(self, schema, source, namespace):
        self.size = source['size']
        super().__init__(schema, source, namespace)

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {'type', 'name', 'namespace', 'aliases', 'size'})

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        value = self._convert_value(value)
        cdef Py_ssize_t length = len(value)
        if length != self.size:
            raise ValueError(f"Invalid length for fixed field: {length} != {self.size}")
        buffer.write_n(value)

    cdef _binary_buffer_decode(self, Reader buffer):
        return bytes(buffer.read_n(self.size))

    cdef int get_value_fitness(self, value) except -1:
        MAX_FIT = FIT_EXACT
        if not isinstance(value, bytes):
            MAX_FIT = FIT_OK
            # Let's see if we can recover this
            if self.options.fixed_codec is None:
                return FIT_NONE # No codec, so can't encode

            # It's not even a str, but can we coerce it?
            if not isinstance(value, str):
                if not self.options.coerce_values_to_str: # Not allowed
                    return FIT_NONE
                MAX_FIT = FIT_POOR
                try:
                    value = str(value)
                except (TypeError, ValueError, UnicodeEncodeError):
                    return FIT_NONE
            
            # We have a str, and a codec
            try:
                value = value.encode(self.options.fixed_codec)
            except (TypeError, ValueError, UnicodeEncodeError):
                return FIT_NONE
        # We have bytes now, check the length
        cdef Py_ssize_t length = len(value)
        if length == self.size:
            return FIT_EXACT
        if length < self.size and self.options.zero_pad_fixed:
            return FIT_OK
        if self.options.truncate_fixed:
            return FIT_OK
        return FIT_NONE

    cdef json_format(self, value):
        value = self._convert_value(value)
        return value.decode('utf8')

    cdef json_decode(self, value):
        cdef str sval = value
        cdef bytes encoded = sval.encode('latin1')
        if len(encoded) != self.size:
            raise ValueError(f"Invalid length for fixed field: {len(encoded)} != {self.size}")
        return encoded

    cpdef object _convert_value(self, object value):
        if not isinstance(value, bytes):
            # Let's see if we can recover this
            if self.options.fixed_codec is None:
                raise ValueError(f"Invalid non-bytes value for fixed: '{value}'")

            # It's not even a str, but can we coerce it?
            if not isinstance(value, str):
                if not self.options.coerce_values_to_str: # Not allowed
                    raise ValueError(f"Invalid non-str value for fixed: '{value}'")
                value = str(value)
                    
            value = value.encode(self.options.fixed_codec)
        # We have bytes now, check the length
        cdef Py_ssize_t length = len(value)
        if length == self.size:
            return value
        if length < self.size and self.options.zero_pad_fixed:
            return value + b'\x00' * (self.size - length)
        if self.options.truncate_fixed:
            return value[:self.size]
        raise ValueError(f"Invalid length for fixed field: {length} != {self.size}")

    cdef CanonicalForm canonical_form(self, set created):
        if self in created:
            return self.get_type_name()
        created.add(self)
        return dict_to_canonical({
            'type': 'fixed',
            'name': self.get_type_name(),
            'size': self.size
        })