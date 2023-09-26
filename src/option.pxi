

NAME_RE_STRICT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
NAME_RE_UNICODE = None

cdef _get_unicode_name_re():
    global NAME_RE_UNICODE
    if NAME_RE_UNICODE is None:
        import unicodedata, sys
        letters = set()
        for c in range(sys.maxunicode + 1):
            if unicodedata.category(chr(c)) in ('Ll', 'Lu'):
                letters.add(chr(c))
        letter_pattern = re.escape(''.join(letters))
        NAME_RE_UNICODE = re.compile(fr'[{letter_pattern}_]\w*')
    return NAME_RE_UNICODE


LOGICAL_TYPES = (
    DecimalType,
    UUIDStringType,
    UUIDFixedType,
    Date,
    TimeMillis, 
    TimeMicros,
    TimestampMillis,
    TimestampMicros,
)

class UnionDecodeOption(enum.Enum):

    """
    Controls how union values are decoded:
     * RAW_VALUES - The value of the matching union type is returned unmodified
     * TYPE_TUPLE_IF_AMBIGUOUS - If union contains types that might be ambiguous (Record + Map) or (String + Enum), then the value is returned as a 2-tuple of (<type>, <value>)
     * TYPE_TUPLE_IF_RECORD_AMBIGUOUS - If union contains multiple record (or map) types, then the value is returned as a 2-tuple of (<type>, <value>)
     * TYPE_TUPLE_IF_RECORD - values matching any union member that is record are returned as a 2-tuple of (<type>, <value>)
     * TYPE_TUPLE_ALWAYS - values are always returned as a 2-tuple of (<type>, <value>)
    """

    RAW_VALUES = 0
    TYPE_TUPLE_IF_AMBIGUOUS = 1
    TYPE_TUPLE_IF_RECORD_AMBIGUOUS = 2
    TYPE_TUPLE_IF_RECORD = 3
    TYPE_TUPLE_ALWAYS = 4

_EMPTY_MP = MappingProxyType({})

def _eval(val):
    if isinstance(val, str):
        if val == 'bint':
            val = 'bool'
        return eval(val, globals(), {})
    return val

class _SignatureWrapper:

    '''
    As of cython 3.0.2, dataclasses do not have a class-level signature
    (unlike pure python classes/dataclasses)

    This wrapper allows us to implement a signature on a frozen dataclass, meaning
    that `inspect.signature(MyDataclass)` will work as expected.

    It does this by creating a temporary pure-python version of the dataclass, and then
    copying the signature from that.
    '''

    def __init__(self):
        self.__signature__ = None
        self.annotations = {}

    def _set_from_dataclass(self, cls):
        fields = [(f.name, f.type, f) for f in dataclasses.fields(cls)]
        for name, type_str, _ in fields:
            self.annotations[name] = _eval(type_str)
        inst = dataclasses.make_dataclass(cls.__name__, fields)
        self.__signature__ = inspect.signature(inst)


_OptionsWrapper = _SignatureWrapper()

@dataclasses.dataclass(frozen=True, kw_only=True)
cdef class Options:

    """
    Runtime configuration options for controlling the behaviour
    of a schema.
    Instances of `Options` are immutable, create a modified copy of options, use the `replace` and `with_*` methods.

    Parameters:

    * `fingerprint_returns_digest` If `True`, the `Schema.fingerprint` method returns a hashlib hash object, rather than the digest bytes
    * `canonical_form_repeat_fixed` Some libraries repeat enum type definitions with the same name/size in canonical form.  Setting this flag to True replicates that
    * `canonical_form_repeat_enum` Some libraries repeat enum type definitions with the same name/symbols in canonical form.  Setting this flag to True replicates that
    * `record_can_encode_dict` If `True`, dicts can be encoded as records (provided they have the correct fields).  If false, then an instance of the relevant record type must be used.
    * `record_values_type_hint`
        If `True`, then dicts encoded using a record schema can have an optional key `-type` (note the leading '-')
        with a value that is the name of the record, ensuring the correct record schema is chosen.
    * `record_decodes_to_dict` If `True`, then records are decoded to a dict, rather than a record class instance
    * `record_allow_extra_fields` If `True`, then any fields in a dict that are not in the record schema are ignored. If `False`, then an error is raised.
    * `record_fields_must_be_unique` If `True`, then all fields within a record must have a unique name
    * `record_encode_use_defaults` 
        If `True`, then when encoding a dict as a record, any fields that are not present in the dict are encoded using their default value from the schema.
        If `False`, then an error is raised for any missing keys
    * `missing_values_can_be_null` If `True`, then missing values may be encoded as `null` where this is valid in the schema. (i.e. `['null', 'string']`)
    * `missing_values_can_be_empty_container` If `True`, then missing values may be encoded as an empty container (list, dict) where this is valid in the schema.
    * `allow_tuple_notation` If `True`, then values can be encoded by passing a 2-tuple of (<type>, <value>) where <type> is the name of the type to encode as, and <value> is the value to encode.
    * `union_decodes_to` Controls how union values are decoded.  See `UnionDecodeOption` for details.  The default, `UnionDecodeOption.RAW_VALUES` returns the value from the matching union unmodified.
    * `union_json_encodes_type_name` 
        If `True` (default), then when JSON encoding a value in a union, the type name is included in the output as per spec.
        If `False`, then the JSON-encoded value of the matching union type is output directly.
    * `allow_primitive_name_collision` If `True`, then named types can have the same name as one of the primitive types (e.g. `int`, `float`, `str` etc..)
    * `allow_primitive_names_in_namespaces` If `True`, then namespace parts can have the same name as one of the primitive types (e.g. `int`, `float`, `str` etc..)
    * `named_type_names_must_be_unique` If `True`, then all named types must have a unique name within the schema
    * `enum_symbols_must_be_unique` If `True`, then all symbols within an enum must be unique
    * `enforce_enum_symbol_name_rules` If `True`, then enum symbol values are checked to ensure they match the rules for valid symbols
    * `enforce_type_name_rules` If `True`, then type names are checked to ensure they match the rules for valid names
    * `enforce_namespace_name_rules` If `True`, then namespace names are checked to ensure they match the rules for valid names
    * `ascii_name_rules` 
        If `True`, then name checking (names/symbols) is done using the strict ASCII rules in the spec.
        If `False`, then equivalent unicode rules are used.
    * `allow_false_values_for_null` If `True`, then a null type will accept any value for which `bool(value)` is `False`, otherwise an error is raised for any non-`None` value.
    * `allow_empty_unions` If `True`, then unions can be empty (i.e. `[]`), otherwise an error is raised.
    * `allow_nested_unions` If `True`, then unions can contain other unions, otherwise an error is raised.
    * `allow_duplicate_union_types` If `True`, then unions can contain multiple types that are forbidden from being in the same union by the spec.
    * `allow_union_default_any_member` If `True`, then the default value for a union can match the schema of any member of the union, otherwise the default value must match the first member of the union.
    * `allow_aliases_to_be_string` 
        If `True`, then aliases can be specified as a string or a list
        If `False`, then aliases must be specified as a list
    * `coerce_values_to_int`
        If `True`, then values encoded in `int` or `long` schemas will be coerced to `int` where possible
    * `coerce_values_to_float`
        If `True`, then values encoded in `float` or `double` schemas will be coerced to `float` where possible
    * `coerce_int_to_float`
        If `True`, then `float` and `double` types will accept `int` values, and encode them as the closest floating-point value
    * `coerce_values_to_boolean`
        If `True`, then values encoded in `boolean` schemas will be coerced to `bool` where possible
    * `coerce_values_to_str`
        If `True`, then values encoded in `string` schemas will be coerced to `str` where possible
    * `bytes_codec` If not `None`, then values passed to bytes schemas will be encoded using the specified codec
    * `fixed_codec` If not `None`, then values passed to fixed schemas will be encoded using the specified codec
    * `null_pad_fixed` If `True`, then values encoded in `fixed` schemas will be zero-padded to the specified size
    * `truncate_fixed` If `True`, then values encoded in `fixed` schemas will be truncated to the specified size (extra bytes will be dropped on encoding)
    * `clamp_int_overflow` If `True`, then values encoded in `int` schemas will be clamped to the min/max values for the specified size
    * `clamp_float_overflow` If `True`, then values encoded in the `float` schema will be clamped to the min/max values 32-bit floats.  (Note, this also replaces INF/NaN values with the closest representable value unless `float_out_of_range_inf` is `True)
    * `float_out_of_range_inf` If `True`, then values encoded in the `float` schema that are out of range will be encoded as INF/NaN, otherwise an error is raised.
    * `bytes_default_value_utf8` If `True`, then the default value for a bytes schema is encoded as UTF-8, otherwise it is encoded as latin1, this should probably never be used except for library compatibility reasons
    * `string_types_default_unchanged` If `True`, then default values for string/bytes/fixed schemas are passed back unmodified (may not be a string), otherwise the relevant JSON decoding is performed. this should probably never be used except for library compatibility reasons
    * `decimal_check_exp_overflow` If `True`, then values encoded in the `decimal` schema will be checked to ensure they are within the range of the specified precision/scale, otherwise an error is raised.
    * `types_str_to_schema` If `True`, then calling `str(<schema instance>)` returns a JSON representation of the schema, otherwise the default `str` implementation is used.
    * `logical_types`
        A tuple of logical types to use when parsing schemas, each item must be an instance of `LogicalType`.  
        Typically this means that for custom logical types, you should subclass `cavro.CustomLogicalType`
        and implement `def custom_encode_value(value)` and `def custom_decode_value(value)`.
        To add types to this tuple, use the `with_logical_types` method.
    * `adapt_record_types` 
        If `True`, then when encoding records, if a record type is passed that has come from a different schema,
        then the record type is adapted to the current schema, provided the name and fields match.
        This situation can easily occur if a source schema is parsed twice.  Each instance of the schema will
        have its own version of the Record class, and these are not compatible without this option.
    * `return_uuid_object` If `True`, then UUID values are returned as `uuid.UUID` objects, otherwise they are returned as strings.
    * `allow_error_type` If `True`, then the `error` type is allowed in schemas (As an alias for 'record').
    * `allow_leading_dot_in_names` If `True`, then names can start with a dot, indicating the null namespace, otherwise an error is raised.
    * `naive_dt_assume_utc` If `True`, then naive datetime values are assumed to be in UTC, otherwise they are treated as representing local time (using current locale)
    * `alternate_timestamp_millis_encoding` If `True`, then an alternate approach to encoding timestamps is used that has slightly different behaviour at extreme values.
    * `date_type_accepts_string` If `True`, then the `date` logical type will accept string in ISO8601 format as input (YYYY-MM-DD), otherwise an error is raised.
    * `raise_on_invalid_logical` If `True`, then attempts to parse a schema that contain invalid logical decimal paramters, will raise an error, rather than silently ignoring the logical type (as per spec)
    * `inline_namespaces` If `True`, then when outputting schema JSON from a parsed schema, namespaces are inlined into the name, otherwise the namespace is output as a separate field.
    * `expand_types_in_schema` 
        If `True`, then when outputting schema JSON from a parsed schema, repeated types are output in full, rather than being referenced by name.
        **Note**: This does not apply to nested/recursive types, which are always referenced by name to prevent infinite recursion.
    * `unicode_errors` The error handling strategy to use when decoding strings/bytes.  See the `errors` parameter to `str.decode` for details.
    * `container_fill_blocks`
        If `True`, then when writing a container, records are written until the current block is > `max_blocksize` (I.e. blocks will often be larger than `max_blocksize`)
        By default, container writer will write a new block whenever the next record will take the current block over the `max_blocksize`,
        meaning that blocks will always be <= `max_blocksize` unless a single value is larger than `max_blocksize`
    * `defer_schema_promotion_errors`
        `cavro` performs eager promotion calculation for performance reasons, this means that incompatible reader/writer schemas are typically detected at schema parse time, and errors raised.
        For compatibility purposes, setting this option to `True` results in schema promotion errors being stored and raised when the first value is read.
    * `invalid_value_includes_record_name`
        When raising exceptions based on Invalid Values, the exception path includes the name of the record type, rather than just the field name.
    * `invalid_value_include_array_index`
        When raising exceptions based on Invalid Values, the exception path includes the array index of any arrays
    * `invalid_value_include_map_key`
        When raising exceptions based on Invalid Values, the exception path includes the key of any maps in the value
    * `allow_invalid_default_values`
        Typically, default values must be valid JSON values for the schema, setting this option to `True` allows invalid default values to be used (JSON decoding is still performed, but decode errors result in the raw value being used).
    * `externally_defined_types`
        An immutable dict of named types (instances of `AvroType`) that are defined outside of the schema being parsed.  This allows for custom/complex schema loading patterns where type definitions may be spread across multiple locations.
        For example, if this dict has `{'Foo': <RecordType...>}, then a schema: `{"type": "Foo"}` will be parsed to be the passed-in Foo type.
        To add types to this dict, use the `with_external_types` method.
        **Note**: It's possible to end up with some weird situations including infinite recursion when using this option, as it's possible to create reference cycles between schemas resulting in infinite recursion errors.
        
    """

    __wrapped__ = _OptionsWrapper
    __annotations__ = _OptionsWrapper.annotations

    fingerprint_returns_digest: bint = False
    canonical_form_repeat_fixed: bint = False
    canonical_form_repeat_enum: bint = False

    record_can_encode_dict: bint = True
    record_values_type_hint: bint = False
    record_decodes_to_dict: bint = False
    record_allow_extra_fields: bint = True
    record_encode_use_defaults: bint = True
    allow_tuple_notation: bint = False
    union_decodes_to: UnionDecodeOption = UnionDecodeOption.RAW_VALUES
    union_json_encodes_type_name: bint = True

    allow_primitive_name_collision: bint = False
    allow_primitive_names_in_namespaces: bint = False

    named_type_names_must_be_unique: bint = True
    enum_symbols_must_be_unique: bint = True
    enforce_enum_symbol_name_rules: bint = True
    enforce_type_name_rules: bint = True
    enforce_namespace_name_rules: bint = True
    record_fields_must_be_unique: bint = True
    ascii_name_rules: bint = True

    missing_values_can_be_null: bint = False
    missing_values_can_be_empty_container: bint = False

    allow_false_values_for_null: bint = False
    allow_empty_unions: bint = False
    allow_nested_unions: bint = False
    allow_duplicate_union_types: bint = False
    allow_union_default_any_member: bint = False
    allow_aliases_to_be_string: bint = False

    coerce_values_to_int: bint = False
    coerce_values_to_float: bint = False
    coerce_int_to_float: bint = True
    coerce_values_to_boolean: bint = False
    coerce_values_to_str: bint = False
    bytes_codec: str = None
    fixed_codec: str = None

    null_pad_fixed: bint = False
    truncate_fixed: bint = False
    clamp_int_overflow: bint = False
    clamp_float_overflow: bint = False
    float_out_of_range_inf: bint = False

    bytes_default_value_utf8: bint = False  # Avro 1.11/12 utf8 encode the default value for bytes (rather than latin1) 
    string_types_default_unchanged: bint = False # Avro < 1.11 pass default value back unmodified for bytes/fixed etc..

    decimal_check_exp_overflow: bint = True

    types_str_to_schema: bint = False
    logical_types: tuple[LogicalType] = LOGICAL_TYPES

    adapt_record_types: bint = True
    return_uuid_object: bint = True

    allow_error_type: bint = False
    allow_leading_dot_in_names: bint = True

    naive_dt_assume_utc: bint = False
    alternate_timestamp_millis_encoding: bint = False
    date_type_accepts_string: bint = False
    raise_on_invalid_logical: bint = False
    inline_namespaces: bint = False
    expand_types_in_schema: bint = False
    unicode_errors: str = 'strict'

    container_fill_blocks: bint = False
    defer_schema_promotion_errors: bint = False

    invalid_value_includes_record_name: bint = False
    invalid_value_include_array_index: bint = True
    invalid_value_include_map_key: bint = True
    allow_invalid_default_values: bint = False

    externally_defined_types: MappingProxyType = _EMPTY_MP

    def replace(self, **changes) -> Options:
        '''
        Return a copy of the options with the specified fields replaced.
        This is a simple wrapper around `dataclasses.replace`
        '''
        return dataclasses.replace(self, **changes)

    def with_logical_types(self, *logical_types):
        '''
        Return a copy of the options with additional logical types added.
        '''
        new_types = logical_types + self.logical_types
        return self.replace(logical_types=new_types)

    def with_external_types(self, named_types: dict[str, AvroType]) -> Options:
        '''
        Return a copy of the options with pre-parsed external named types added
        (Allows for references to types in the schema that have not been defined in the schema)
        '''
        new_types = dict(self.externally_defined_types)
        new_types.update(named_types)
        return self.replace(externally_defined_types=new_types)

    @property
    def name_pattern(self):
        '''
        Returns the relevant regular expression for validating names based on the current options.
        '''
        if self.ascii_name_rules:
            return NAME_RE_STRICT
        return _get_unicode_name_re()

    cdef bint can_have_missing_values(self):
        '''
        If we are expecting a value, and there's no default in the schema, is it ever possible for that value to be absent without error?
        '''
        return self.missing_values_can_be_empty_container or self.missing_values_can_be_null

    def equals(self, Options other: Options, ignore: Sequence[str]=()) -> bool:
        '''
        Compares two Options objects, this is equivalent to 
        `self == other` except you can pass in a list of field names to ignore
        '''
        if not ignore:
            return self == other
        for field in dataclasses.fields(Options):
            if field.name in ignore:
                continue
            self_val = getattr(self, field.name)
            other_val = getattr(other, field.name)
            if self_val != other_val:
                return False
        return True

    def diff(self, Options other: Options, ignore: Sequence[str]=()) -> dict[str, tuple[object, object]]:
        '''
        Returns a dictionary containing just the fields that are different between two Options objects.
        Any fields whose names are in `ignore` are not included.
        The return dictionary is of the form: `{field_name: (self_value, other_value)}`
        '''
        out = {}
        for field in dataclasses.fields(Options):
            if field.name in ignore:
                continue
            self_val = getattr(self, field.name)
            other_val = getattr(other, field.name)
            if self_val != other_val:
                out[field.name] = (self_val, other_val)
        return out

_OptionsWrapper._set_from_dataclass(Options)


DEFAULT_OPTIONS = Options()
PERMISSIVE_OPTIONS = Options(
    allow_primitive_name_collision=True,
    enum_symbols_must_be_unique=False,
    record_fields_must_be_unique=False,
    enforce_enum_symbol_name_rules=False,
    allow_false_values_for_null=True,
    allow_empty_unions=True,
    allow_nested_unions=True,
    allow_duplicate_union_types=True,
    coerce_values_to_boolean=True,
    coerce_values_to_str=True,
    coerce_values_to_int=True,
    bytes_codec='utf8',
    fixed_codec='utf8',
    null_pad_fixed=True,
    truncate_fixed=True,
    clamp_int_overflow=True,
    clamp_float_overflow=True,
    float_out_of_range_inf=True,
    coerce_values_to_float=True,
    adapt_record_types=True,
    enforce_type_name_rules=False,
    allow_error_type=True,
    allow_leading_dot_in_names=True,
    enforce_namespace_name_rules=False,
    named_type_names_must_be_unique=False,
    missing_values_can_be_null=True,
    missing_values_can_be_empty_container=True,
    allow_tuple_notation=True,
    allow_union_default_any_member=True,
    unicode_errors='replace',
)