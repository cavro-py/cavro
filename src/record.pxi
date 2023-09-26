
class Order(enum.Enum):
    """
    The order of a field in a record.
    """

    ASC = 'ascending'
    DESC = 'descending'
    IGNORE = 'ignore'
    

NO_DEFAULT = _Sentinel('NO_DEFAULT')


cdef class _PlaceholderType(AvroType):

    """
    An avro type that just provied a constant value when read.
    This is used during schema promotion where the reader has a defaulted value that the writer does not.
    """

    type_name = "placeholder"

    cdef readonly object default_value

    def __init__(self, options, default_value):
        schema = Schema('"null"', options)
        AvroType.__init__(self, schema, None, None)
        self.default_value = None if default_value is MISSING_VALUE else default_value

    cdef dict _extract_metadata(self, source):
        return {}

    cpdef dict _get_schema_extra(self, set created):
        return {}
    
    cdef _make_logical(self, schema, source):
        pass

    cdef int binary_buffer_encode(self, _Writer buffer, value) except -1:
        raise NotImplementedError("Placeholder types cannot be encoded")

    cdef _binary_buffer_decode(self, _Reader buffer):
        return self.default_value

    cdef int _get_value_fitness(self, value) except -1:
        return FIT_NONE

    cdef _json_format(self, value):
        raise NotImplementedError("Placeholder types cannot be encoded")

    cdef _json_decode(self, value):
        return self.default_value

    cpdef object _convert_value(self, object value):
        return None

    cdef _CanonicalForm canonical_form(self, set created):
        raise NotImplementedError("Placeholder types have no canonical form")


cdef list _record_data_from_dict(RecordType record, dict data):
    cdef list field_data = [None] * len(record.fields)
    cdef Py_ssize_t index = 0
    cdef Options options = record.options

    if not options.record_allow_extra_fields:
        extra_fields = data.keys() - record.field_dict.keys()
        if extra_fields:
            extra_field, *_ = extra_fields
            raise InvalidValue('...', record, (extra_field, ))
    if not options.record_encode_use_defaults:
        missing_fields = record.field_dict.keys() - data.keys()
        if missing_fields:
            missing_field, *_ = missing_fields
            raise InvalidValue('<missing>', record, (missing_field, ))

    for field in record.fields:
        value = data.get(field.name, field.default_value)
        if value is NO_DEFAULT:
            raise ValueError(f"Field {field.name} is required for record {record.type}")
        field_data[index] = field.type.convert_value(value)
        index += 1
    return field_data


@cython.freelist(8)
cdef class Record:

    """
    An instance of a record value from a schema.
    This class should never be instantiated directly, instead it forms the base-class for `RecordType.record` classes.

    Field values can be accessed using dot notation, e.g. `record.field_name`, index notation, e.g. `record['field_name']`, or by calling `_asdict()`
    Subclasses of record have a class attribute: `Type`, which is the `RecordType` schema that the record was created from.

    Internally, records are represented as a list of values, one for each field in the record, with associated field metadata.
    Subclasses can be instantiated in the following ways:
     * `Record(data: list|tuple)`: The length of data must match the number of fields in the record, and each value should correspond to the relevant field value
     * `Record(data: dict)`: The keys of the dict must match the field names, and each value should correspond to the relevant field value
     * `Record(data: Record)`: The record must be of the same type as the subclass, or must be adaptable to the subclass (Matching name and fields)
     * `Record(**kwargs)`: Each keyword argument should correspond to a field name, and the value should correspond to the relevant field value
    """

    cdef list data

    def __init__(self, data=None, **kwargs):
        cdef dict data_dict
        cdef Record rec
        if isinstance(data, type(self)):
            rec = data
            self.data = rec.data
            return
        if isinstance(data, Record) and data.Type.name == self.Type.name:
            if self.Type.options.adapt_record_types:
                data_dict = data._asdict()
            else:
                raise ValueError(f"Record {data} cannot be adapted to {self}")
        if data:
            if kwargs:
                raise ValueError(f"Records may either be instantiated with a single dict, or **kwargs, not both")
            data_dict = data
        else:
            data_dict = kwargs
        self.data = _record_data_from_dict(self.Type, data_dict)

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
        return f'<Record:{self.Type.type} {self._repr_children(70)}>'

    def _asdict(self):
        """
        Returns the record as a dict, with field names as keys.
        """
        cdef dict items = {}
        cdef RecordField field
        cdef Py_ssize_t i = 0
        for field in self.Type.fields:
            data = self.data[i]
            if isinstance(data, Record):
                data = data._asdict()
            items[field.name] = data
            i += 1
        return items

    def __eq__(self, other):
        if not isinstance(other, self.Type.record):
            return False
        cdef Record other_rec = other
        return self.data == other_rec.data


@cython.final
cdef class RecordField:

    """
    Holds the metadata for a record schema field.
    This class should never be instantiated directly, instead it is created by `RecordType` when parsing a schema.
    """

    cdef readonly str name
    cdef readonly str writer_name
    cdef readonly str doc
    cdef readonly AvroType type
    cdef readonly object default_value
    cdef readonly object order
    cdef readonly frozenset aliases

    def __init__(self, schema, source, namespace):
        cdef AvroType sub_type
        self.name = source['name']
        self.writer_name = self.name
        self.doc = source.get('doc', '')
        self.type = AvroType.for_source(schema, source['type'], namespace)
        self.default_value = self.type.resolve_default_value(source.get('default', NO_DEFAULT), self.name)
        self.order = Order(source.get('order', 'ascending'))
        alias_val = source.get('aliases', [])
        if not isinstance(alias_val, (list, tuple, set)):
            raise ValueError(f"Aliases must be a list/tuple/set, got: {repr(alias_val)}")
        self.aliases = frozenset(alias_val)

    cdef for_reader(self, str reader_name, AvroType reader_type):
        cdef RecordField cloned
        cloned = RecordField.__new__(RecordField)
        cloned.name = reader_name
        cloned.writer_name = self.writer_name
        if reader_type is not None: 
            cloned.type = reader_type.for_writer(self.type)
        else:
            cloned.type = self.type
        cloned.default_value = NO_DEFAULT # If we're reading, then no default
        return cloned

    cdef placeholder(self):
        cdef RecordField rec = RecordField.__new__(RecordField)
        rec.name = self.name
        rec.doc = ''
        rec.type = _PlaceholderType(self.type.options, self.default_value)
        rec.default_value = self.default_value
        rec.order = Order.ASC
        rec.aliases = frozenset()
        return rec

    cdef _CanonicalForm canonical_form(self, set created):
        return dict_to_canonical({
            'name': self.name,
            'type': self.type.canonical_form(created),
        })

    def get_schema(self, created):
        schema = {
            'name': self.name, 
            'type': self.type.get_schema(created), 
        }
        if self.doc:
            schema['doc'] = self.doc
        if self.aliases:
            schema['aliases'] = list(self.aliases)
        if self.order != Order.ASC:
            schema['order'] = self.order.value
        if self.default_value not in {NO_DEFAULT, MISSING_VALUE}:
            try:
                schema['default'] = self.type.json_format(self.default_value)
            except InvalidValue:
                if self.type.options.allow_invalid_default_values:
                    schema['default'] = self.default_value
                else:
                    raise
        return schema


@cython.final
cdef class _FieldAccessor:
    cdef Py_ssize_t index

    def __init__(self, index):
        self.index = index

    def __get__(self, inst, cls):
        cdef Record record = inst
        return record.data[self.index]

    def __set__(self, inst, value):
        cdef Record record = inst
        record.data[self.index] = value


cdef object _make_record_class(RecordType record_type):
    attrs = {}
    field_to_index = {}
    for i, field in enumerate(record_type.fields):
        attrs[field.name] = _FieldAccessor(i)
        field_to_index[field.name] = i

    attrs['Type'] = record_type
    attrs['__slots__'] = ()
    attrs['_field_to_index'] = field_to_index
    return type(
        record_type.name,
        (Record, ),
        attrs
    )

_EMPTY_ARRAY = array.array(SSIZE_TYPECODE.decode())


cdef class RecordType(_NamedType):

    """
    The Type that corresponds to a Record in a Schema.

    Attributes:
     * `doc` Any "doc" metadata defined in the schema
     * `fields` A tuple of `RecordField` instances, one for each field in the record
     * `record` A subclass of `Record` that can be used to instantiate records of this type
    """

    type_name = 'record'

    cdef readonly str doc
    cdef readonly tuple fields
    cdef dict field_dict
    cdef readonly type record

    cdef bint _setting_up

    def __init__(self, schema, source, namespace):
        cdef Schema schema_ = schema
        self._setting_up = True
        self.doc = source.get('doc', '')
        _NamedType.__init__(self, schema, source, namespace)
        self.fields = tuple(
            RecordField(schema_, f, self.effective_namespace) for f in source['fields']
        )
        self.field_dict = {}
        for field in self.fields:
            if schema_.options.record_fields_must_be_unique and field.name in self.field_dict:
                raise InvalidName(f'Duplicate field name: {field.name}')
            self.field_dict[field.name] = field

        n_fields = len(self.fields)
        self.record = _make_record_class(self)

        self._setting_up = False
        logical = self._make_logical(schema, source)
        if logical is not None:
            self.value_adapters = self.value_adapters + (logical,)

    cdef _make_logical(self, schema, source):
        if self._setting_up:
            return
        return AvroType._make_logical(self, schema, source)

    cpdef AvroType copy(self):
        cdef RecordType new_inst = self.clone_base()
        new_inst.doc = self.doc
        new_inst.fields = self.fields
        new_inst.field_dict = self.field_dict
        new_inst.record = self.record
        return new_inst

    cdef dict _extract_metadata(self, source):
        return _strip_keys(dict(source), {
            'type', 
            'name', 
            'namespace', 
            'doc', 
            'aliases', 
            'fields'
        })

    def walk_types(self, visited):
        if self in visited:
            return
        yield from super().walk_types(visited)
        for field in self.fields:
            yield from field.type.walk_types(visited)

    cpdef dict _get_schema_extra(self, set created):
        extra = super(RecordType, self)._get_schema_extra(created)
        return dict(extra, fields=[f.get_schema(created) for f in self.fields])

    cdef int _binary_buffer_encode(self, _Writer buffer, value) except -1:
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
            return 0
        if not self.options.record_allow_extra_fields:
            extra_fields = value.keys() - self.field_dict.keys()
            if extra_fields:
                extra_field, *_ = extra_fields
                raise InvalidValue('...', self, (extra_field, ))
        if not self.options.record_encode_use_defaults:
            missing_fields = self.field_dict.keys() - value.keys()
            if missing_fields:
                missing_field, *_ = missing_fields
                raise InvalidValue('<missing>', self, (missing_field, ))
        for field in self.fields:
            try:
                field_value = value.get(field.name, field.default_value)
            except AttributeError as e:
                raise InvalidValue(value, self, (self.name, )) from e
            if field_value is NO_DEFAULT:
                raise ValueError(f"required field '{field.name}' missing")
            try:
                field.type.binary_buffer_encode(buffer, field_value)
            except InvalidValue as e:
                prefix = (field.name, )
                if self.options.invalid_value_includes_record_name:
                    prefix = (self.type, ) + prefix
                e.schema_path = prefix + e.schema_path
                raise

    cdef _binary_buffer_decode_record(self, _Reader buffer):
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

    cdef _binary_buffer_decode_dict(self, _Reader buffer):
        cdef RecordField field
        cdef dict data = {}
        for field in self.fields:
            value = field.type.binary_buffer_decode(buffer)
            if field.name is not None:
                data[field.name] = value
        return data

    cdef _binary_buffer_decode(self, _Reader buffer):
        if self.options.record_decodes_to_dict:
            return self._binary_buffer_decode_dict(buffer)
        return self._binary_buffer_decode_record(buffer)

    cdef int _get_value_fitness(self, value) except -1:
        cdef int level = FIT_OK
        cdef RecordField field
        if isinstance(value, self.record):
            return FIT_EXACT
        if isinstance(value, dict):
            if self.options.record_values_type_hint and '-type' in value:
                value = value.copy()
                type_val = value.pop('-type')
                if type_val != self.type:
                    return FIT_NONE
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
                if self.options.record_allow_extra_fields:
                    return FIT_POOR
                return FIT_NONE
            return level

    cdef _json_format(self, value):
        cdef Record record = self._convert_value(value)
        cdef AvroType field_type
        out = {}
        for field, value in zip(self.fields, record.data):
            field_type = field.type
            out[field.name] = field_type.json_format(value)
        return out

    cdef json_decode_record(self, dict value):
        cdef list data = [None] * len(self.fields)
        cdef RecordField field
        cdef Record rec
        cdef Py_ssize_t index = 0

        for field in self.fields:
            field_value = value.get(field.writer_name, MISSING_VALUE)
            if field_value is MISSING_VALUE:
                if field.default_value is NO_DEFAULT:
                    raise ValueError(f"required field '{field.name}' missing")
                field_value = field.default_value
            else:
                field_value = field.type.json_decode(field_value)
            data[index] = field_value
            index += 1
        rec = Record.__new__(self.record)
        rec.data = data
        return rec

    cdef json_decode_dict(self, dict value):
        cdef dict data = {}
        cdef RecordField field

        for field in self.fields:
            field_value = value.get(field.writer_name, MISSING_VALUE)
            if field_value is MISSING_VALUE:
                if field.default_value is NO_DEFAULT:
                    raise ValueError(f"required field '{field.name}' missing")
                field_value = field.default_value
            else:
                field_value = field.type.json_decode(field_value)
            data[field.name] = field_value
        return data

    cdef _json_decode(self, value):
        if self.options.record_decodes_to_dict:
            return self.json_decode_dict(value)
        return self.json_decode_record(value)

    cpdef object _convert_value(self, object value):
        if isinstance(value, self.record):
            return value
        return self.record(value)

    cdef _CanonicalForm canonical_form(self, set created):
        cdef RecordField field
        if self in created:
            return _CanonicalForm('"' + self.type + '"')
        created.add(self)
        return dict_to_canonical({
            'type': 'record',
            'name': self.type,
            'fields': [field.canonical_form(created) for field in self.fields]
        })

    cdef AvroType _for_writer(self, AvroType writer):
        cdef PromotingRecordType cloned
        cdef RecordType writer_rec
        cdef RecordField field
        cdef Py_ssize_t i
        if not isinstance(writer, RecordType):
            return
        writer_rec = writer
        if not self.name_matches(writer_rec):
            return
        # This allows us to go from the field name to the index in the reader record
        reader_field_idx = {}
        reader_fields = {}
        aliases = {}

        i = 0
        for field in self.fields:
            reader_field_idx[field.name] = i
            reader_fields[i] = field
            for alias in field.aliases:
                aliases[alias] = i
            i += 1

        # We're going to have to read each writer field in order anyway, but if it's a reader field,
        # Then it ends up in the corresponding decode_index slot, but should also be promoted etc..
        out_decode_indexes = []
        out_fields = []
        decoded_reader_fields = set()

        # Todo, only use promoting type if the field order/naming is different
        for field in  writer_rec.fields:
            if field.name in reader_field_idx:
                reader_index = reader_field_idx[field.name]
                reader_field = reader_fields[reader_index]
            elif field.name in aliases:
                reader_index = aliases[field.name]
                reader_field = reader_fields[reader_index]
            else:
                # This field is not in the reader, so we read it and discard (index = -1)
                out_decode_indexes.append(-1)
                out_fields.append(field.for_reader(None, None))
                continue
                
            out_decode_indexes.append(reader_index)
            out_fields.append(field.for_reader(reader_field.name, reader_field.type))
            decoded_reader_fields.add(reader_index)
        
        extra_reader_fields = reader_fields.keys() - decoded_reader_fields
        for reader_index in extra_reader_fields:
            field = reader_fields[reader_index]

            if field.default_value is NO_DEFAULT:
                raise CannotPromoteError(self, writer, f"required field '{field.name}' missing")
            out_decode_indexes.append(reader_index)
            out_fields.append(field.placeholder())
        
        cloned = self.clone_base(PromotingRecordType)
        cloned.decode_indexes = cvarray((len(out_decode_indexes), ), sizeof(Py_ssize_t), SSIZE_TYPECODE)
        for i, idx in enumerate(out_decode_indexes):
            cloned.decode_indexes[i] = idx
        cloned.fields = tuple(out_fields)
        cloned.field_dict = {f.name: f for f in cloned.fields}
        cloned.record = self.record
        return cloned


cdef class PromotingRecordType(RecordType):

    """
    A variant of a `RecordType`, specialized for reading records from a different schema from a writer.
    """

    cdef Py_ssize_t [:] decode_indexes

    cdef _binary_buffer_decode_record(self, _Reader buffer):
        cdef RecordField field
        cdef list data = [None] * len(self.fields)
        cdef Record rec
        cdef Py_ssize_t index = 0
        cdef Py_ssize_t field_index
        for field in self.fields:
            field_index = self.decode_indexes[index]
            value = field.type.binary_buffer_decode(buffer)
            if field_index >= 0: 
                data[field_index] = value
            index += 1
        rec = Record.__new__(self.record)
        rec.data = data
        return rec