
@cython.final
cdef class EnumType(NamedType):
    type_name = 'enum'

    cdef readonly tuple symbols
    cdef dict symbol_indexes
    cdef readonly object default_value
    cdef readonly str doc

    def __init__(self, schema, source, namespace):
        NamedType.__init__(self, schema, source, namespace)
        raw_symbols = source['symbols']
        if not isinstance(raw_symbols, (list, tuple)):
            raise ValueError("Enum symbols must be a list of strings")
        
        if schema.options.enum_symbols_must_be_unique:
            seen_symbols = set()
            for symbol in raw_symbols:
                if symbol in seen_symbols:
                    raise DuplicateName(f"Enum symbols must be unique. '{symbol}' found twice")
                seen_symbols.add(symbol)
        else:
            seen_symbols = raw_symbols

        name_pattern = schema.options.name_pattern
        if schema.options.enforce_enum_symbol_name_rules:
            for symbol in seen_symbols:
                if not isinstance(symbol, str):
                    raise InvalidName('Enum symbols must be strings')
                if schema.options.enforce_enum_symbol_name_rules:
                    if not name_pattern.fullmatch(symbol):
                        raise InvalidName(f"Enum symbol '{symbol}' is not a valid name")
        
        self.symbols = tuple(raw_symbols)
        cdef size_t i
        self.symbol_indexes = {}
        for i, symbol in enumerate(self.symbols):
            self.symbol_indexes[symbol] = i
        self.default_value = source.get('default', NO_DEFAULT)
        if self.default_value is not NO_DEFAULT:
            if self.default_value not in self.symbol_indexes:
                raise ValueError(f"Default value '{self.default_value}' not in enum symbols")
        self.doc = source.get('doc', '')

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {
            'type',
            'name', 
            'namespace', 
            'aliases', 
            'doc', 
            'symbols'
        })

    cpdef dict _get_schema_extra(self, set created):
        extra = NamedType._get_schema_extra(self, created)
        if self.default_value is not NO_DEFAULT:
            extra['default'] = self.default_value
        extra['symbols'] = list(self.symbols)
        return extra

    cdef int _binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef size_t index = self.symbol_indexes[value]
        zigzag_encode_long(buffer, index)

    cdef _binary_buffer_decode(self, Reader buffer):
        return self.symbols[zigzag_decode_long(buffer)]

    cdef int _get_value_fitness(self, value) except -1:
        try:
            if value in self.symbol_indexes:
                return FIT_EXACT
        except TypeError:
            return FIT_NONE

    cpdef object _convert_value(self, object value):
        # if value is valid for type, then it needs no conversion
        return value

    cdef json_format(self, value):
        if value not in self.symbol_indexes:
            raise KeyError(f"'{value}' invalid for enum")
        return value

    cdef json_decode(self, value):
        if value not in self.symbol_indexes:
            raise ValueError(f"'{value}' invalid for enum")
        return value

    cdef CanonicalForm canonical_form(self, set created):
        if self in created:
            return CanonicalForm('"' + self.type + '"')
        created.add(self)
        return dict_to_canonical({
            'type': 'enum',
            'name': self.type,
            'symbols': self.symbols
        })

    cdef AvroType _for_writer(self, AvroType writer):
        reader_symbols = set(self.symbols)
        writer_symbols = set(writer.symbols)
        writer_extra_symbols = writer_symbols - reader_symbols
        if not writer_extra_symbols:  # Reader knows about all possible symbols
            return self
        if self.default_value is NO_DEFAULT:
            raise CannotPromoteError(self, writer, f"reader has no default value, but writer has extra symbols: {', '.join(writer_extra_symbols)}")
        
        cdef EnumType writer_enum = writer
        cdef EnumType new_type = writer.clone_base()
        new_type.symbols = tuple(s if s in reader_symbols else self.default_value for s in writer.symbols)
        new_type.symbol_indexes = writer_enum.symbol_indexes
        return new_type


        
            