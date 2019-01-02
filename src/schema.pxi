import json

cdef str resolve_namespaced_name(str namespace, str name):
    if '.' in name or namespace is None:
        return name
    return f'{namespace}.{name}'


cdef class Schema:

    cdef readonly dict named_types
    cdef readonly object source
    cdef readonly bint permissive
    cdef readonly AvroType type

    def __init__(self, source, permissive=False):
        if isinstance(source, (str, bytes)):
            source = json.loads(source)
        self.permissive = permissive
        self.named_types = {}
        self.source = source
        self.type = AvroType.for_schema(self)

    cdef void register_type(self, str namespace, str name, AvroType avro_type):
        self.named_types[resolve_namespaced_name(namespace, name)] = avro_type

    property canonical_form:
        def __get__(self):
            return self.type.canonical_form()

    def find_type(self, str namespace, str name):
        return self.named_types[resolve_namespaced_name(namespace, name)]

    def can_encode(self, value):
        fitness = self.type.get_value_fitness(value)
        threshold = FIT_POOR if self.permissive else FIT_OK
        return fitness >= threshold

    def binary_encode(self, value):
        cdef MemoryWriter buffer = MemoryWriter()
        self.type.binary_buffer_encode(buffer, value)
        return buffer.bytes()

    def binary_decode(self, bytes value):
        cdef MemoryReader buffer = MemoryReader(value)
        return self.type.binary_buffer_decode(buffer)

    def binary_read(self, Reader reader):
        return self.type.binary_buffer_decode(reader)

    def json_encode(self, value, serialize=True, **kwargs):
        data = self.type.json_format(value)
        if serialize:
            return json.dumps(data, **kwargs)
        return data