
cdef class EnumType(NamedType):
    type_name = 'enum'

    cdef readonly tuple symbols
    cdef dict symbol_indexes

    def __init__(self, schema, source, namespace):
        NamedType.__init__(self, schema, source, namespace)
        if not schema.permissive:
            if not isinstance(source['symbols'], list):
                raise ValueError("Enum symbols must be an array of strings")
            seen_symbols = set()
            for symbol in source['symbols']:
                if not isinstance(symbol, str):
                    raise ValueError('Enum symbols must be strings')
                if symbol in seen_symbols:
                    raise ValueError(f"Enum symbols must be unique. '{symbol}' found twice")
                seen_symbols.add(symbol)
        self.symbols = tuple(source['symbols'])
        cdef size_t i
        self.symbol_indexes = {}
        for i, symbol in enumerate(self.symbols):
            self.symbol_indexes[symbol] = i

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

    def json_format(self, value):
        if value not in self.symbol_indexes:
            raise KeyError(f"'{value}' invalid for enum")
        return value

    cdef str canonical_form(self):
        return dict_to_canonical({
            'type': 'enum',
            'name': self.get_type_name(),
            'symbols': self.symbols
        })