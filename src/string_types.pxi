
@cython.final
cdef class BytesType(AvroType):
    type_name = "bytes"

    cpdef AvroType copy(self):
        return self.clone_base()

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type'})

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

    cdef int _get_value_fitness(self, value) except -1:
        if isinstance(value, (bytes, bytearray)):  # If bytes, we're good
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

    cdef _json_format(self, value):
        value = self.convert_value(value)
        return value.decode('latin-1')

    cdef _json_decode(self, value):
        cdef str sval = value
        return sval.encode('latin-1')

    cpdef object _convert_value(self, object value):
        if isinstance(value, (bytes, bytearray)):
            return value
        codec = self.options.bytes_codec
        if not codec:
            raise InvalidValue(value, self)
        if not isinstance(value, str):
            if self.options.coerce_values_to_str:
                value = str(value)
            raise InvalidValue(value, self)
        # We have a str, and codec
        return value.encode(codec)

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"bytes"')

    cdef AvroType _for_writer(self, AvroType writer):
        if isinstance(writer, StringType):
            return self # Decoding is identical for bytes / str

    cdef object resolve_default_value(self, object schema_default, str field):
        if self.options.string_types_default_unchanged:
            return schema_default
        if self.options.bytes_default_value_utf8:
            try:
                schema_default = schema_default.encode('utf-8')
            except (AttributeError, TypeError, UnicodeEncodeError) as e:
                raise TypeError(f"Default value {schema_default!r} is not valid for bytes field: {field}") from e
            return schema_default
        return AvroType.resolve_default_value(self, schema_default, field)
        


@cython.final
cdef class StringType(AvroType):
    type_name = "string"

    cpdef AvroType copy(self):
        return self.clone_base()

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type'})

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
        return buffer.read_bytes(length).decode('utf-8', errors=self.options.unicode_errors)

    cdef int _get_value_fitness(self, value) except -1:
        if isinstance(value, str):
            return FIT_EXACT
        if self.options.coerce_values_to_str:
            if isinstance(value, bytes):
                return FIT_OK
            return FIT_POOR
        return FIT_NONE

    cdef _json_format(self, value):
        return self._convert_value(value)

    cdef _json_decode(self, value):
        cdef str sval = value
        return sval

    cpdef object _convert_value(self, object value):
        if isinstance(value, str):
            return value
        if not self.options.coerce_values_to_str:
            raise InvalidValue(value, self)
        if isinstance(value, bytes):
            return value.decode(errors=self.options.unicode_errors)
        return str(value)

    cdef CanonicalForm canonical_form(self, set created):
        return CanonicalForm('"string"')

    cdef AvroType _for_writer(self, AvroType writer):
        if isinstance(writer, BytesType):
            return self


@cython.final
cdef class FixedType(NamedType):
    type_name = "fixed"

    cdef readonly Py_ssize_t size

    def __init__(self, schema, source, namespace):
        self.size = source['size']
        if self.size < 0:
            raise ValueError(f'Invalid negative size for fixed: {self.size}')
        super().__init__(schema, source, namespace)

    cpdef AvroType copy(self):
        cdef FixedType new_inst =  self.clone_base()
        new_inst.size = self.size
        return new_inst

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {'type', 'name', 'namespace', 'aliases', 'size'})

    cpdef dict _get_schema_extra(self, set created):
        return dict(NamedType._get_schema_extra(self, created), size=self.size)

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        value = self._convert_value(value)
        cdef Py_ssize_t length = len(value)
        if length != self.size:
            raise ValueError(f"Invalid length for fixed field: {length} != {self.size} (value: {value})")
        buffer.write_n(value)

    cdef _binary_buffer_decode(self, Reader buffer):
        return bytes(buffer.read_n(self.size))

    cdef int _get_value_fitness(self, value) except -1:
        MAX_FIT = FIT_EXACT
        if not isinstance(value, (bytes, bytearray)):
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

    cdef _json_format(self, value):
        value = self._convert_value(value)
        return value.decode('utf8', errors=self.options.unicode_errors)

    cdef _json_decode(self, value):
        cdef str sval = value
        cdef bytes encoded = sval.encode('latin1')
        if len(encoded) != self.size:
            raise ValueError(f"Invalid length for fixed field: {len(encoded)} != {self.size} (value: {value})")
        return encoded

    cpdef object _convert_value(self, object value):
        if not isinstance(value, (bytes, bytearray)):
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
        raise ValueError(f"Invalid length for fixed field: {length} != {self.size} (value: {value})")

    cdef CanonicalForm canonical_form(self, set created):
        if self in created and not self.options.canonical_form_repeat_fixed_enum:
            return CanonicalForm(f'"{self.type}"')
        created.add(self)
        return dict_to_canonical({
            'type': 'fixed',
            'name': self.type,
            'size': self.size
        })

    cdef AvroType _for_writer(self, AvroType writer):
        cdef FixedType writer_fixed
        if not isinstance(writer, FixedType):
            return
        writer_fixed = writer
        if not self.name_matches(writer_fixed):
            return
        if writer_fixed.size != self.size:
            return
        return self

    cdef object resolve_default_value(self, object schema_default, str field):
        if self.options.string_types_default_unchanged:
            return schema_default
        if self.options.bytes_default_value_utf8:
            try:
                schema_default = schema_default.encode('utf-8').decode('latin-1')
            except (AttributeError, TypeError, UnicodeEncodeError) as e:
                raise TypeError(f"Default value {schema_default!r} is not valid for fixed field: {field}") from e
        return AvroType.resolve_default_value(self, schema_default, field)