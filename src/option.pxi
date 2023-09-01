

NAME_RE_STRICT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
NAME_RE_UNICODE = None

cdef get_unicode_name_re():
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
    RAW_VALUES = 0
    TYPE_TUPLE_IF_AMBIGUOUS = 1
    TYPE_TUPLE_IF_RECORD_AMBIGUOUS = 2
    TYPE_TUPLE_IF_RECORD = 3
    TYPE_TUPLE_ALWAYS = 4


@dataclasses.dataclass
cdef class Options:

    fingerprint_returns_digest: bint = False
    canonical_form_repeat_fixed: bint = False

    record_can_encode_dict: bint = True
    record_values_type_hint: bint = False
    record_decodes_to_dict: bint = False
    record_allow_extra_fields: bint = True
    record_encode_use_defaults: bint = True
    union_decodes_to: UnionDecodeOption = UnionDecodeOption.RAW_VALUES

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
    allow_aliases_to_be_string: bint = False

    coerce_values_to_int: bint = False
    coerce_values_to_float: bint = False
    coerce_int_to_float: bint = True
    truncate_float: bint = False
    coerce_values_to_boolean: bint = False
    coerce_values_to_str: bint = False
    bytes_codec: str = None
    fixed_codec: str = None

    zero_pad_fixed: bint = False
    truncate_fixed: bint = False
    clamp_int_overflow: bint = False
    clamp_float_overflow: bint = False

    bytes_default_value_utf8: bint = False  # Avro 1.11/12 utf8 encode the default value for bytes (rather than latin1) 
    string_types_default_unchanged: bint = False # Avro < 1.11 pass default value back unmodified for bytes/fixed etc..

    decimal_check_exp_overflow: bint = True

    types_str_to_schema: bint = False
    logical_types: tuple[LogicalType] = LOGICAL_TYPES

    adapt_record_types: bint = False
    return_uuid_object: bint = True

    allow_error_type: bint = False
    allow_leading_dot_in_names: bint = True

    naive_dt_assume_utc: bint = False
    alternate_timestamp_millis_encoding: bint = False
    date_type_accepts_string: bint = False
    raise_on_invalid_logical: bint = False
    inline_namespaces: bint = False
    expand_types_in_schema: bint = False

    container_fill_blocks: bint = False
    defer_schema_promotion_errors: bint = False

    def replace(self, **changes):
        return dataclasses.replace(self, **changes)

    @property
    def name_pattern(self):
        if self.ascii_name_rules:
            return NAME_RE_STRICT
        return get_unicode_name_re()

    cdef bint can_have_missing_values(self):
        return self.missing_values_can_be_empty_container or self.missing_values_can_be_null


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
    zero_pad_fixed=True,
    truncate_fixed=True,
    truncate_float=True,
    clamp_int_overflow=True,
    clamp_float_overflow=True,
    coerce_values_to_float=True,
    adapt_record_types=True,
    enforce_type_name_rules=False,
    allow_error_type=True,
    allow_leading_dot_in_names=True,
    enforce_namespace_name_rules=False,
    named_type_names_must_be_unique=False,
    missing_values_can_be_null=True,
    missing_values_can_be_empty_container=True,
)