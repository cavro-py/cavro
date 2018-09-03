
cdef class EnumType(NamedType):
    type_name = 'enum'

    cdef tuple symbols
    cdef dict symbol_indexes

    def __init__(self, schema, source, namespace):
        NamedType.__init__(self, schema, source, namespace)
        if not schema.permissive:
            if not isinstance(source['symbols'], list):
                raise ValueError("enum 'symbols' must be an array")
        self.symbols = tuple(source['symbols'])
        cdef size_t i
        self.symbol_indexes = {}
        for i, symbol in enumerate(self.symbols):
            self.symbol_indexes[symbol] = i

    cdef binary_buffer_encode(self, MemoryBuffer buffer, value):
        cdef size_t index = self.symbol_indexes[value]
        zigzag_encode_long(buffer, index)

    def json_encode(self, value):
        if value not in self.symbol_indexes:
            raise KeyError(f"'{value}' invalid for enum")
        return value