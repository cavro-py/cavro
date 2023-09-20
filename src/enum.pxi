
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
                    raise InvalidName('Enum symbols must be a list of strings')
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

    cpdef AvroType copy(self):
        cdef EnumType new_inst = self.clone_base()
        new_inst.symbols = self.symbols
        new_inst.symbol_indexes = self.symbol_indexes
        new_inst.default_value = self.default_value
        new_inst.doc = self.doc
        return new_inst

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {
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

    cdef _json_format(self, value):
        if value not in self.symbol_indexes:
            raise KeyError(f"'{value}' invalid for enum")
        return value

    cdef _json_decode(self, value):
        if value not in self.symbol_indexes:
            raise ValueError(f"'{value}' invalid for enum")
        return value

    cdef CanonicalForm canonical_form(self, set created):
        if self in created and not self.options.canonical_form_repeat_fixed_enum:
            return CanonicalForm('"' + self.type + '"')
        created.add(self)
        return dict_to_canonical({
            'type': 'enum',
            'name': self.type,
            'symbols': self.symbols
        })

    cdef AvroType _for_writer(self, AvroType writer):
        if not isinstance(writer, EnumType):
            return
        cdef EnumType writer_enum = writer
        if not self.name_matches(writer_enum):
            return
        reader_symbols = set(self.symbols)
        writer_symbols = set(writer_enum.symbols)
        writer_extra_symbols = writer_symbols - reader_symbols
        if not writer_extra_symbols:  # Reader knows about all possible symbols
            return self
        
        cdef PromotingEnumType new_type = writer.clone_base(PromotingEnumType)
        new_type.reader_type = self
        new_type.writer_type = writer_enum
        new_type.symbols = tuple(s if s in reader_symbols else self.default_value for s in writer.symbols)
        new_type.unknown_symbols = writer_extra_symbols
        new_type.symbol_indexes = writer_enum.symbol_indexes
        return new_type

    cdef object resolve_default_value(self, object schema_default, str field):
        if self.options.string_types_default_unchanged:
            return schema_default
        return AvroType.resolve_default_value(self, schema_default, field)


cdef class PromotingEnumType(EnumType):
    cdef readonly set unknown_symbols
    cdef readonly EnumType reader_type
    cdef readonly EnumType writer_type

    cdef _json_decode(self, value):
        value = EnumType._json_decode(self, value)
        if value in self.unknown_symbols:
            if self.defaul_value is NO_DEFAULT:
                raise CannotPromote(self.reader_type, self.writer_type, f"'{value}' invalid for enum")
            return self.default_value
        return value

    cdef _binary_buffer_decode(self, Reader buffer):
        value = EnumType._binary_buffer_decode(self, buffer)
        if value is NO_DEFAULT:
            raise CannotPromoteError(self.reader_type, self.writer_type, f"Unknown value for enum")
        return value