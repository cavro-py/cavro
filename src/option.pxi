
LOGICAL_TYPES = (
    DecimalType,
    UUIDStringType,
    UUIDFixedType,
)

@dataclasses.dataclass
cdef class Options:

    record_can_encode_dict: bint = True
    allow_primitive_name_collision: bint = False
    
    enum_symbols_must_be_unique: bint = True
    enforce_enum_symbol_name_rules: bint = True
    ascii_name_rules: bint = True

    allow_false_values_for_null: bint = False
    allow_empty_unions: bint = False
    allow_nested_unions: bint = False
    allow_duplicate_union_types: bint = False

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

    types_str_to_schema: bint = False
    logical_types: tuple[LogicalType] = LOGICAL_TYPES


DEFAULT_OPTIONS = Options()
PERMISSIVE_OPTIONS = Options(
    allow_primitive_name_collision=True,
    enum_symbols_must_be_unique=False,
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
)