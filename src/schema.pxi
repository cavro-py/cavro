import json
import hashlib

cdef str resolve_namespaced_name(str namespace, str name):
    if '.' in name or namespace is None:
        return name
    return f'{namespace}.{name}'


cdef class Schema:

    cdef readonly dict named_types
    cdef readonly object source
    cdef readonly Options options
    cdef readonly AvroType type

    cdef readonly dict logical_types

    def __init__(self, source, options=DEFAULT_OPTIONS, **extra_options):
        if isinstance(source, (str, bytes)):
            source = json.loads(source)
        if extra_options:
            options = dataclasses.replace(options, **extra_options)
        self.options = options
        self.named_types = {}
        self.source = source

        logical_by_name = {}
        self.logical_types = logical_by_name
        for logical_type in options.logical_types:
            type_name = logical_type.logical_name
            dest = logical_by_name.setdefault(type_name, [])
            dest.append(logical_type)

        self.type = AvroType.for_schema(self)

    cdef void register_type(self, str namespace, str name, AvroType avro_type):
        self.named_types[resolve_namespaced_name(namespace, name)] = avro_type

    property canonical_form:
        def __get__(self):
            return self.type.canonical_form(set())

    def fingerprint(self, method='rabin', **kwargs):
        if method == 'rabin':
            hasher = Rabin()
        else:
            hasher = hashlib.new(method, **kwargs)
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