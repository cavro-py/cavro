

SYMBOL_NAME_RE_STRICT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
SYMBOL_NAME_RE_UNICODE = None

cdef get_unicode_name_re():
    global SYMBOL_NAME_RE_UNICODE
    if SYMBOL_NAME_RE_UNICODE is None:
        import unicodedata, sys
        letters = set()
        for c in range(sys.maxunicode + 1):
            if unicodedata.category(chr(c)) in ('Ll', 'Lu'):
                letters.add(chr(c))
        letter_pattern = re.escape(''.join(letters))
        SYMBOL_NAME_RE_UNICODE = re.compile(fr'[{letter_pattern}_]\w*')
    return SYMBOL_NAME_RE_UNICODE


cdef class EnumType(NamedType):
    type_name = 'enum'

    cdef readonly tuple symbols
    cdef dict symbol_indexes

    def __init__(self, schema, source, namespace):
        NamedType.__init__(self, schema, source, namespace)
        raw_symbols = source['symbols']
        if not isinstance(raw_symbols, (list, tuple)):
            raise ValueError("Enum symbols must be a list of strings")
        
        if schema.options.enum_symbols_must_be_unique:
            seen_symbols = set()
            for symbol in raw_symbols:
                if symbol in seen_symbols:
                    raise ValueError(f"Enum symbols must be unique. '{symbol}' found twice")
                seen_symbols.add(symbol)
        else:
            seen_symbols = raw_symbols

        name_pattern = SYMBOL_NAME_RE_STRICT if schema.options.ascii_name_rules else get_unicode_name_re()
        
        if schema.options.enforce_enum_symbol_name_rules:
            for symbol in seen_symbols:
                if not isinstance(symbol, str):
                    raise ValueError('Enum symbols must be strings')
                if schema.options.enforce_enum_symbol_name_rules:
                    if not name_pattern.fullmatch(symbol):
                        raise ValueError(f"Enum symbol '{symbol}' is not a valid name")
        
        self.symbols = tuple(raw_symbols)
        cdef size_t i
        self.symbol_indexes = {}
        for i, symbol in enumerate(self.symbols):
            self.symbol_indexes[symbol] = i

    cdef dict _extract_metadata(self, source):
        return _strip_keys(source, {
            'type',
            'name', 
            'namespace', 
            'aliases', 
            'doc', 
            'symbols'
        })

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef size_t index = self.symbol_indexes[value]
        zigzag_encode_long(buffer, index)

    cdef binary_buffer_decode(self, Reader buffer):
        return self.symbols[zigzag_decode_long(buffer)]

    cdef int get_value_fitness(self, value) except -1:
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
            return CanonicalForm('"' + self.get_type_name() + '"')
        created.add(self)
        return dict_to_canonical({
            'type': 'enum',
            'name': self.get_type_name(),
            'symbols': self.symbols
        })