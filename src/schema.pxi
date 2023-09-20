import json
import hashlib

cdef str resolve_namespaced_name(str namespace, str name):
    if '.' in name or namespace is None:
        return name
    return f'{namespace}.{name}'


class class_inst_method:
    def __init__(self, func):
        self.func = func

    def __get__(self, inst, cls):
        return partial(self.func, inst, cls)


cdef class Schema:

    cdef readonly dict named_types
    cdef readonly object source
    cdef readonly Options options
    cdef readonly AvroType type

    cdef readonly dict logical_types

    def __init__(self, source, Options options=DEFAULT_OPTIONS, named_types=None, parse_json=True, _type=None, **extra_options):
        if isinstance(source, (str, bytes)) and parse_json:
            source = json.loads(source)
        self.source = source
        if extra_options:
            options = options.replace(**extra_options)
        self.options = options
        self.named_types = {} if named_types is None else named_types
        self.logical_types = self._make_logical_types(options)
        self.type = AvroType.for_schema(self) if _type is None else _type

    @class_inst_method
    def wrap_type(inst, cls, AvroType avro_type, Options options=None):
        if inst is not None:
            if options is None:
                options = inst.options
        if options is None:
            options = DEFAULT_OPTIONS
        source = avro_type.get_schema(set())
        cdef Schema new_inst = cls(source, options, parse_json=False, _type=avro_type)
        return new_inst

    def _make_logical_types(self, options):
        logical_by_name = {}
        self.logical_types = logical_by_name
        for logical_type in options.logical_types:
            type_name = logical_type.logical_name
            dest = logical_by_name.setdefault(type_name, [])
            dest.append(logical_type)
        return logical_by_name
    
    cdef void register_type(self, str namespace, str name, AvroType avro_type):
        resolved = resolve_namespaced_name(namespace, name)
        if self.options.named_type_names_must_be_unique and resolved in self.named_types:
            existing = self.named_types[resolved]
            raise DuplicateName(f'Name {resolved!r} appears multiple times in schema')
        self.named_types[resolved] = avro_type

    property canonical_form:
        def __get__(self):
            return self.type.canonical_form(set())

    property schema:
        def __get__(self):
            return self.type.get_schema(set())

    property schema_str:
        def __get__(self):
            return json.dumps(self.schema, indent=2)

    def fingerprint(self, method='rabin', **kwargs):
        if method == 'rabin':
            hasher = Rabin()
        else:
            try:
                hasher = hashlib.new(method, **kwargs)
            except ValueError:
                raise InvalidHasher(f'Unknown hash method: {method!r}')
        hasher.update(self.canonical_form.encode('utf-8'))
        if self.options.fingerprint_returns_digest:
            return hasher.digest()
        return hasher

    def find_type(self, str namespace, str name):
        return self.named_types[resolve_namespaced_name(namespace, name)]

    def can_encode(self, value):
        fitness = self.type.get_value_fitness(value)
        return fitness > FIT_NONE

    def binary_encode(self, value):
        cdef MemoryWriter buffer = MemoryWriter()
        self.type.binary_buffer_encode(buffer, value)
        return buffer.bytes()

    def binary_decode(self, bytes value):
        cdef MemoryReader buffer = MemoryReader(value)
        return self.type.binary_buffer_decode(buffer)

    cpdef binary_read(self, Reader reader):
        return self.type.binary_buffer_decode(reader)

    cpdef binary_write(self, Writer writer, value):
        self.type.binary_buffer_encode(writer, value)

    def json_encode(self, value, serialize=True, **kwargs):
        data = self.type.json_format(value)
        if serialize:
            return json.dumps(data, **kwargs)
        return data

    def json_decode(self, value, deserialize=True, **kwargs):
        if deserialize:
            value = json.loads(value, **kwargs)
        return self.type.json_decode(value)

    cpdef Schema reader_for_writer(self, Schema writer_schema):
        new_type = self.type.for_writer(writer_schema.type)
        return ResolvedSchema(new_type, self.options)


cdef class ResolvedSchema(Schema):

    def __init__(self, AvroType resolved_type, Options options=DEFAULT_OPTIONS):
        named_types = {}
        for sub_type in resolved_type.walk_types(set()):
            if isinstance(sub_type, NamedType):
                named_types[sub_type.type] = sub_type
            
        self.named_types = named_types
        self.source = None
        self.options = options
        self.type = resolved_type
        self.logical_types = self._make_logical_types(options)