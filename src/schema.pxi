import json

cdef class Schema:

    cdef readonly dict named_types
    cdef readonly object source
    cdef readonly bint permissive
    cdef readonly AvroType type

    def __init__(self, source, permissive=False):
        if isinstance(source, str):
            source = json.loads(source)
        self.permissive = permissive
        self.named_types = {}
        self.source = source
        self.type = AvroType.for_schema(self)

    def find_type(self, namespace, source):
        if '.' not in source and namespace is not None:
            source = "%s.%s" % (namespace, source)
        return self.named_types[source]

    def can_encode(self, value):
        return self.type.is_value_valid(value)

    def binary_encode(self, value):
        return self.type.binary_encode(value)

    def json_encode(self, value):
        data = self.type.json_encode(value)
        return json.dumps(data)