
cdef class EnumType(NamedType):
    type_name = 'enum'

    cdef tuple symbols
    cdef dict symbol_indexes

    def __init__(self, schema, source, namespace):
        NamedType.__init__(self, schema, source, namespace)
        if not schema.permissive:
            if not isinstance(source['symbols'], list):
                raise ValueError("Enum symbols must be an array or strings")
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

    cdef void binary_buffer_encode(self, MemoryWriter buffer, value):
        cdef size_t index = self.symbol_indexes[value]
        zigzag_encode_long(buffer, index)

    def json_encode(self, value):
        if value not in self.symbol_indexes:
            raise KeyError(f"'{value}' invalid for enum")
        return value