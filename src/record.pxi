import enum

class Order(enum.Enum):
    ASC = 'ascending'
    DESC = 'descending'
    IGNORE = 'ignore'

NO_DEFAULT = object()


cdef list record_data_from_dict(RecordType record, dict data):
    cdef list field_data = [None] * len(record.fields)
    cdef Py_ssize_t index = 0
    for field in record.fields:
        value = data.get(field.name, field.default_value)
        if value is NO_DEFAULT:
            raise ValueError(f"Field {field.name} is required for record {record.get_type_name()}")
        field_data[index] = field.type.convert_value(value)
        index += 1
    return field_data


cdef class Record:
    cdef list data

    def __init__(self, data=None, **kwargs):
        cdef dict data_dict
        cdef Record rec
        if isinstance(data, Record) and  data.Type.name == self.Type.name:
            if type(data) is type(self): # short-circuit for creating record from record
                rec = data
                self.data = rec.data
                return
            data_dict =  data._asdict()
        if data:
            if kwargs:
                raise ValueError(f"Records may either be instantiated with a single dict, or **kwargs, not both")
            data_dict = data
        else:
            data_dict = kwargs
        self.data = record_data_from_dict(self.Type, data_dict)

    def __dir__(self):
        return ['Type'] + [f.name for f in self.Type.fields] + ['_asdict', '__getitem__']

    def __getitem__(self, name):
        cdef dict indexes = self._field_to_index
        cdef Py_ssize_t field_index = indexes[name]
        return self.data[field_index]

    cdef _repr_children(self, remain):
        cdef Record rec
        if remain < 4:
            return "{...}"
        more = False
        key_len = sum(len(f.name) + 1 for f in self.Type.fields)
        child_remain = remain - key_len
        vals = []
        for field in self.Type.fields:
            value = self[field.name]
            if isinstance(value, Record):
                rec = value
                value = rec._repr_children(child_remain)
            else:
                value = repr(value)
            repr_val = f'{field.name}: {value}'
            vals.append(repr_val)
            remain -= len(repr_val) + 1
            if remain < 4:
                more = True
                break
        return '{' + (" ".join(vals)) + ("..." if more else "") + "}"

    def __repr__(self):
        child_reprs = {f.name: self[f.name] for f in self.Type.fields}
        child_desc = ', '.join([f''])
        return f'<Record:{self.Type.get_type_name()} {self._repr_children(70)}>'

    def _asdict(self):
        cdef dict items = {}
        cdef RecordField field
        for field, data in zip(self.Type.fields, self.data):
            if isinstance(data, Record):
                data = data._asdict()
            items[field.name] = data
        return items


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

    cdef CanonicalForm canonical_form(self, set created):
        return dict_to_canonical({
            'name': self.name,
            'type': self.type.canonical_form(created),
        })



cdef class FieldAccessor:
    cdef Py_ssize_t index

    def __init__(self, index):
        self.index = index

    def __get__(self, inst, cls):
        cdef Record record = inst
        return record.data[self.index]

    def __set__(self, inst, value):
        cdef Record record = inst
        record.data[self.index] = value


cdef object make_record_class(RecordType record_type):
    attrs = {}
    field_to_index = {}
    for i, field in enumerate(record_type.fields):
        attrs[field.name] = FieldAccessor(i)
        field_to_index[field.name] = i

    attrs['Type'] = record_type
    attrs['__slots__'] = ()
    attrs['_field_to_index'] = field_to_index
    return type(
        record_type.name,
        (Record, ),
        attrs
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
            RecordField(schema, f, self.effective_namespace) for f in source['fields']
        )
        self.field_dict = {f.name: f for f in self.fields}
        self.record = make_record_class(self)

    cdef int binary_buffer_encode(self, Writer buffer, value) except -1:
        cdef RecordField field
        cdef list rec_data
        cdef Record rec
        cdef Py_ssize_t index = 0
        if isinstance(value, Record):
            rec = value
            rec_data = rec.data
            for field in self.fields:
                field_value = rec_data[index]
                if field_value is NO_DEFAULT:
                    raise ValueError(f"required field '{field.name}' missing")
                field.type.binary_buffer_encode(buffer, field_value)
                index = index + 1
        else:
            for field in self.fields:
                field_value = value.get(field.name, field.default_value)
                if field_value is NO_DEFAULT:
                    raise ValueError(f"required field '{field.name}' missing")
                field.type.binary_buffer_encode(buffer, field_value)

    cdef binary_buffer_decode(self, Reader buffer):
        cdef RecordField field
        cdef list data = [None] * len(self.fields)
        cdef Record rec
        cdef Py_ssize_t index = 0
        for field in self.fields:
            data[index] = field.type.binary_buffer_decode(buffer)
            index += 1
        rec = Record.__new__(self.record)
        rec.data = data
        return rec

    cdef int get_value_fitness(self, value) except -1:
        cdef int level = FIT_OK
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

    def json_format(self, value):
        cdef Record record
        if not isinstance(value, self.record):
            raise ValueError(f"Value is not compatible with this schema: {value}")
        record = value
        out = {}
        for field, value in zip(self.fields, record.data):
            out[field.name] = field.type.json_format(value)
        return out

    cpdef object _convert_value(self, object value):
        return self.record(value)

    cdef CanonicalForm canonical_form(self, set created):
        cdef RecordField field
        if self in created:
            return CanonicalForm('"' + self.get_type_name() + '"')
        created.add(self)
        return dict_to_canonical({
            'type': 'record',
            'name': self.get_type_name(),
            'fields': [field.canonical_form(created) for field in self.fields]
        })

