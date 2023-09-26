import json
import hashlib

cdef str resolve_namespaced_name(str namespace, str name):
    if '.' in name or namespace is None:
        return name
    return f'{namespace}.{name}'


class _class_inst_method:
    def __init__(self, func):
        self.func = func

    def __get__(self, inst, cls):
        return partial(self.func, inst, cls)


cdef class Schema:

    """
    The main interface for `cavro`.

    This class represents an avro schema, and is able to encode and decode values appropriately.

    Arguments:
     * `source`:
        The source of the schema. This can either be a string that holds the JSON-encoded schema definition, or a python object that represents the schema (e.g. the result of `json.loads`).
     * `options`:
        An instance of `Options` that controls how the schema is interpreted. Defaults to `DEFAULT_OPTIONS`.
     * `named_types`:
        An optional dictionary that will be updated to contain any named types that are encountered while parsing the schema.
     * `parse_json`:
        If `False` then the `source` argument will never be parsed as json, even if it's a string value. Defaults to `True`.
     * `**extra_options`:
        Any extra options that should be applied to the schema. These will override any options that are set in the `options` argument.
        Key-values here must match the attributes of `cavro.Options`.
    """


    cdef readonly dict named_types
    cdef readonly object source
    cdef readonly Options options
    cdef readonly AvroType type

    cdef readonly dict logical_types

    def __init__(self, source: Union[str, object], Options options: Options=DEFAULT_OPTIONS, *, named_types: dict[str, AvroType]=None, parse_json: bool=True, _type=None, **extra_options):
        if isinstance(source, (str, bytes)) and parse_json:
            source = json.loads(source)
        self.source = source
        if extra_options:
            options = options.replace(**extra_options)
        self.options = options
        self.named_types = {} if named_types is None else named_types
        self.logical_types = self._make_logical_types(options)
        self.type = AvroType.for_schema(self) if _type is None else _type

    @_class_inst_method
    def _wrap_type(inst, cls, AvroType avro_type, Options options=None):
        """
        Used in certain situations to create a `Schema` object from a raw `AvroType` instance.
        You probably don't need to use this.
        """
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
        """
        Returns the canonical form of the schema as a string
        """
        def __get__(self):
            return self.type.canonical_form(set())

    property schema:
        """
        Return an object representing the schema definition.
        Note: This will not always be identical to the `source` used to construct this schema object, as it is reconstructed from the types on-demand.
        """
        def __get__(self):
            return self.type.get_schema(set())

    property schema_str:
        """
        `Schema.schema`, but json encoded
        """
        def __get__(self):
            return json.dumps(self.schema, indent=2)

    def fingerprint(self, method='rabin', **kwargs) -> Union[bytes, hashlib._hashlib.HASH]:
        """
        Return the deterministic fingerprint of the schema, using the given hash method.
        
        `**kwargs` are passed to the relevant `hashlib.new()` call.
        
        Return type is controlled by the `fingerprint_returns_digest` option.
        """
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

    cpdef AvroType find_type(self, str namespace, str name, bint _raise=True):
        """
        Given a namespace and name (namespace may be None), find and return the `AvroType` instance matching this name.
        """
        cdef str resolved = resolve_namespaced_name(namespace, name)
        cdef AvroType found = self.named_types.get(resolved)
        if found is not None:
            return found
        found = self.options.externally_defined_types.get(resolved)
        if found is not None:
            self.register_type(namespace, name, found)
            return found
        found = self.named_types.get(name)
        if found is not None:
            return found
        found = self.options.externally_defined_types.get(name)
        if found is not None:
            return found
        if _raise:
            raise UnknownType(f'Unknown type: {resolved!r}')

    def can_encode(self, value: object) -> bool:
        """
        Check if `value` can be encoded using this schema
        """
        fitness = self.type.get_value_fitness(value)
        return fitness > FIT_NONE

    def binary_encode(self, value: object) -> bytes:
        """
        Encode `value` using this schema and return the avro bytes representing it.
        """
        cdef MemoryWriter buffer = MemoryWriter()
        self.type.binary_buffer_encode(buffer, value)
        return buffer.bytes()

    def binary_decode(self, bytes value: bytes) -> object:
        """
        Decode `value` using this schema and return the decoded value.
        """
        cdef MemoryReader buffer = MemoryReader(value)
        return self.type.binary_buffer_decode(buffer)

    cpdef binary_read(self, _Reader reader: _Reader):
        """
        Read a value from `reader` using this schema and return the decoded value.
        `reader` may be a `MemoryReader` or `FileReader` instance.
        """
        return self.type.binary_buffer_decode(reader)

    cpdef binary_write(self, _Writer writer: _Writer, value: object):
        """
        Write `value` to `writer` using this schema.
        `writer` may be a `MemoryWriter` or `FileWriter` instance.
        """
        self.type.binary_buffer_encode(writer, value)

    def json_encode(self, value, serialize=True, **kwargs):
        """
        Encode `value` using this schema and return the avro json representing it.
        """
        data = self.type.json_format(value)
        if serialize:
            return json.dumps(data, **kwargs)
        return data

    def json_decode(self, value: Union[str, object], deserialize: bool=True, **kwargs):
        """
        Decode `value` in JSON form using this schema and return the decoded value.

        If `deserialize` is True, then value must be a `str` containing the serialized JSON value.
        If `deserialize` is False, then value must be a python object representing the JSON value.
        """
        if deserialize:
            value = json.loads(value, **kwargs)
        return self.type.json_decode(value)

    cpdef Schema reader_for_writer(self, Schema writer_schema: Schema):
        """
        Return a schema that is the result of promoting this schema to the writer schema.
        
        The returned schema may only be used for reading, and should return values that match the reader schema.
        """
        new_type = self.type.for_writer(writer_schema.type)
        return ResolvedSchema(new_type, self.options)



cdef class ResolvedSchema(Schema):

    """
    A variant of a schema that is the result of schema promotion.
    """

    def __init__(self, AvroType resolved_type, Options options=DEFAULT_OPTIONS):
        named_types = {}
        for sub_type in resolved_type.walk_types(set()):
            if isinstance(sub_type, _NamedType):
                named_types[sub_type.type] = sub_type
            
        self.named_types = named_types
        self.source = None
        self.options = options
        self.type = resolved_type
        self.logical_types = self._make_logical_types(options)