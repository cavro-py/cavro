import enum

class Order(enum.Enum):
    ASC = 'ascending'
    DESC = 'descending'
    IGNORE = 'ignore'

NO_DEFAULT = object()


cdef class Record:
    cdef list data

    def __init__(self, data):
        self.data = data

    def _asdict(self):
        return {f.name: v for (f, v) in zip(self.Type.fields, self.data)}


cdef class RecordField:
    cdef readonly str name
    cdef readonly str doc
    cdef readonly AvroType type
    cdef readonly object default_value
    cdef readonly object order
    cdef readonly set aliases

    def __init__(self, schema, source, namespace):
        self.name = source['name']
        self.doc = source.get('doc', '')
        self.type = AvroType.for_source(schema, source['type'], namespace)
        self.default_value = (
            self.type.json_decode(source['default'])
            if 'default' in source
            else NO_DEFAULT
        )
        self.order = Order(source.get('order', 'ascending'))
        self.aliases = set(source.get('aliases', []))


cdef object make_record_class(RecordType record_type):
    return type(
        record_type.name,
        (Record, ),
        {
            'Type': record_type,
            '__slots__': ()
        }
    )


cdef class RecordType(NamedType):
    cdef readonly str doc
    cdef readonly tuple fields
    cdef dict field_dict
    cdef readonly type record

    def __init__(self, schema, source, namespace):
        NamedType.__init__(self, schema, source, namespace)
        self.doc = source.get('doc', '')
        self.fields = tuple(
            RecordField(schema, f, self.namespace) for f in source['fields']
        )
        self.field_dict = {f.name: f for f in self.fields}
        self.record = make_record_class(self)

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef RecordField field
        for field in self.fields:
            field_value = value.get(field.name, field.default_value)
            if field_value is NO_DEFAULT:
                raise ValueError(f"required field '{field.name}' missing")
            field.type.binary_buffer_encode(buffer, field_value)

    cdef binary_buffer_decode(self, Reader buffer):
        cdef RecordField field
        cdef list data = []
        for field in self.fields:
            data.append(field.type.binary_buffer_decode(buffer))
        return self.record(data)

    cdef int get_value_fitness(self, value) except -1:
        cdef int level = FIT_EXACT
        cdef RecordField field
        if isinstance(value, self.record):
            return FIT_EXACT
        elif isinstance(value, dict):
            remaining_keys = set(value.keys())
            for field in self.fields:
                field_value = value.get(field.name, field.default_value)
                if field_value is NO_DEFAULT:
                    return FIT_NONE
                level = min(level, field.type.get_value_fitness(field_value))
                if level <= FIT_NONE:
                    return level
                remaining_keys.discard(field.name)
            if remaining_keys:
                return FIT_POOR
            return level
