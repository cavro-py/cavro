---
title: API Reference
---

All members of cavro are defined in the top-level module.

Currently, the docs are a little funky, because cython doesn't expose Signtaure information that easily, and `pdoc`
isn't geared up to handle it. This may change in the future.

## Main Interface Classes

### `class` Schema
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

#### Members:

##### `init` Schema(self, /, *args, **kwargs)







<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/schema.pxi#L111" target="_blank">[source]</a>
</div>

##### `method` fingerprint(self, method=&#39;rabin&#39;, **kwargs) -&gt; Union[bytes, _hashlib.HASH]

Return the deterministic fingerprint of the schema, using the given hash method.

`**kwargs` are passed to the relevant `hashlib.new()` call.

Return type is controlled by the `fingerprint_returns_digest` option.



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/schema.pxi#L152" target="_blank">[source]</a>
</div>

##### `method` can_encode(self, value: object) -&gt; bool

Check if `value` can be encoded using this schema



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/schema.pxi#L159" target="_blank">[source]</a>
</div>

##### `method` binary_encode(self, value: object) -&gt; bytes

Encode `value` using this schema and return the avro bytes representing it.



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/schema.pxi#L167" target="_blank">[source]</a>
</div>

##### `method` binary_decode(self, value: bytes) -&gt; object

Decode `value` using this schema and return the decoded value.



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/schema.pxi#L188" target="_blank">[source]</a>
</div>

##### `method` json_encode(self, value, serialize=True, **kwargs)

Encode `value` using this schema and return the avro json representing it.



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/schema.pxi#L197" target="_blank">[source]</a>
</div>

##### `method` json_decode(self, value: Union[str, object], deserialize: bool = True, **kwargs)

Decode `value` in JSON form using this schema and return the decoded value.

If `deserialize` is True, then value must be a `str` containing the serialized JSON value.
If `deserialize` is False, then value must be a python object representing the JSON value.



##### `attr` canonical_form
Returns the canonical form of the schema as a string



##### `attr` schema
Return an object representing the schema definition.
Note: This will not always be identical to the `source` used to construct this schema object, as it is reconstructed from the types on-demand.



##### `attr` schema_str
`Schema.schema`, but json encoded



##### `attr` named_types



##### `attr` source



##### `attr` options



##### `attr` type



##### `attr` logical_types







<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/schema.pxi#L131" target="_blank">[source]</a>
</div>

##### `method` find_type(self, namespace, name, _raise=True)

Given a namespace and name (namespace may be None), find and return the `AvroType` instance matching this name.



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/schema.pxi#L174" target="_blank">[source]</a>
</div>

##### `method` binary_read(self, reader: cavro._Reader)

Read a value from `reader` using this schema and return the decoded value.
`reader` may be a `MemoryReader` or `FileReader` instance.



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/schema.pxi#L181" target="_blank">[source]</a>
</div>

##### `method` binary_write(self, writer: cavro._Writer, value: object)

Write `value` to `writer` using this schema.
`writer` may be a `MemoryWriter` or `FileWriter` instance.



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/schema.pxi#L208" target="_blank">[source]</a>
</div>

##### `method` reader_for_writer(self, writer_schema: cavro.Schema)

Return a schema that is the result of promoting this schema to the writer schema.

The returned schema may only be used for reading, and should return values that match the reader schema.







  
### `class` Options
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
* `allow_tuple_notation` If `True`, then values can be encoded by passing a 2-tuple of (&lt;type>, &lt;value>) where &lt;type> is the name of the type to encode as, and &lt;value> is the value to encode.
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
* `types_str_to_schema` If `True`, then calling `str(&lt;schema instance>)` returns a JSON representation of the schema, otherwise the default `str` implementation is used.
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
    meaning that blocks will always be &lt;= `max_blocksize` unless a single value is larger than `max_blocksize`
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
    For example, if this dict has `{'Foo': &lt;RecordType...>}, then a schema: `{"type": "Foo"}` will be parsed to be the passed-in Foo type.
    To add types to this dict, use the `with_external_types` method.
    **Note**: It's possible to end up with some weird situations including infinite recursion when using this option, as it's possible to create reference cycles between schemas resulting in infinite recursion errors.

#### Members:

##### `init` Options(self, /, *args, **kwargs)













<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/option.pxi#L284" target="_blank">[source]</a>
</div>

##### `method` replace(self, **changes) -&gt; cavro.Options

Return a copy of the options with the specified fields replaced.
This is a simple wrapper around `dataclasses.replace`



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/option.pxi#L291" target="_blank">[source]</a>
</div>

##### `method` with_logical_types(self, *logical_types)

Return a copy of the options with additional logical types added.



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/option.pxi#L298" target="_blank">[source]</a>
</div>

##### `method` with_external_types(self, named_types: dict[str, cavro.AvroType]) -&gt; cavro.Options

Return a copy of the options with pre-parsed external named types added
(Allows for references to types in the schema that have not been defined in the schema)



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/option.pxi#L322" target="_blank">[source]</a>
</div>

##### `method` equals(
    self,
    other: cavro.Options,
    ignore: collections.abc.Sequence[str] = ()
) -&gt; bool

Compares two Options objects, this is equivalent to 
`self == other` except you can pass in a list of field names to ignore



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/option.pxi#L338" target="_blank">[source]</a>
</div>

##### `method` diff(
    self,
    other: cavro.Options,
    ignore: collections.abc.Sequence[str] = ()
) -&gt; dict[str, tuple[object, object]]

Returns a dictionary containing just the fields that are different between two Options objects.
Any fields whose names are in `ignore` are not included.
The return dictionary is of the form: `{field_name: (self_value, other_value)}`



##### `attr` name_pattern
Returns the relevant regular expression for validating names based on the current options.



##### `attr` fingerprint_returns_digest



##### `attr` canonical_form_repeat_fixed



##### `attr` canonical_form_repeat_enum



##### `attr` record_can_encode_dict



##### `attr` record_values_type_hint



##### `attr` record_decodes_to_dict



##### `attr` record_allow_extra_fields



##### `attr` record_encode_use_defaults



##### `attr` allow_tuple_notation



##### `attr` union_decodes_to



##### `attr` union_json_encodes_type_name



##### `attr` allow_primitive_name_collision



##### `attr` allow_primitive_names_in_namespaces



##### `attr` named_type_names_must_be_unique



##### `attr` enum_symbols_must_be_unique



##### `attr` enforce_enum_symbol_name_rules



##### `attr` enforce_type_name_rules



##### `attr` enforce_namespace_name_rules



##### `attr` record_fields_must_be_unique



##### `attr` ascii_name_rules



##### `attr` missing_values_can_be_null



##### `attr` missing_values_can_be_empty_container



##### `attr` allow_false_values_for_null



##### `attr` allow_empty_unions



##### `attr` allow_nested_unions



##### `attr` allow_duplicate_union_types



##### `attr` allow_union_default_any_member



##### `attr` allow_aliases_to_be_string



##### `attr` coerce_values_to_int



##### `attr` coerce_values_to_float



##### `attr` coerce_int_to_float



##### `attr` coerce_values_to_boolean



##### `attr` coerce_values_to_str



##### `attr` bytes_codec



##### `attr` fixed_codec



##### `attr` null_pad_fixed



##### `attr` truncate_fixed



##### `attr` clamp_int_overflow



##### `attr` clamp_float_overflow



##### `attr` float_out_of_range_inf



##### `attr` bytes_default_value_utf8



##### `attr` string_types_default_unchanged



##### `attr` decimal_check_exp_overflow



##### `attr` types_str_to_schema



##### `attr` logical_types



##### `attr` adapt_record_types



##### `attr` return_uuid_object



##### `attr` allow_error_type



##### `attr` allow_leading_dot_in_names



##### `attr` naive_dt_assume_utc



##### `attr` alternate_timestamp_millis_encoding



##### `attr` date_type_accepts_string



##### `attr` raise_on_invalid_logical



##### `attr` inline_namespaces



##### `attr` expand_types_in_schema



##### `attr` unicode_errors



##### `attr` container_fill_blocks



##### `attr` defer_schema_promotion_errors



##### `attr` invalid_value_includes_record_name



##### `attr` invalid_value_include_array_index



##### `attr` invalid_value_include_map_key



##### `attr` allow_invalid_default_values



##### `attr` externally_defined_types
















  
### `class` ContainerReader
A class for reading avro object container files.

The container can ben used as an iterator, in which case it will yield the objects in the file in order:
```
for obj in ContainerReader('file.avro'):
    print(obj)
```

Arguments:
 * `src`: The source to read from. Can be a file-like object, instance of `cavro.MemoryReader`, or a path to a file (str|Path)
 * `reader_schema`: The schema to use when reading objects. If not provided, the writer schema will be used.
 * `options`: An Options object to use when constructing the writer schema. Defaults to the default options. This does not affect the `reader_schema` options.

#### Members:

##### `init` ContainerReader(self, /, *args, **kwargs)







##### `attr` metadata



##### `attr` marker



##### `attr` writer_schema



##### `attr` reader_schema



##### `attr` schema



##### `attr` codec_name



##### `attr` objects_left_in_block








<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/container.pxi#L117" target="_blank">[source]</a>
</div>

##### `method` next_object(self)








  
### `class` ContainerWriter
A class for writing avro object container files.

The writer can be used as a context manager, in which case it will be closed when the context exits:
```
with ContainerWriter('file.avro', schema) as writer:
    writer.write_one(obj)
```

Arguments:
 * `dest`: The destination to write to. Can be a file-like object, instance of `cavro.MemoryWriter`, or a path to a file (str|Path)
 * `schema`: The schema of the objects to be written.
 * `codec`: The codec to use. Must be one of the supported codecs. Default to `null`
 * `max_blocksize`: The maximum size of a block. Defaults to `16352`.
 * `write_header`: Whether to write the avro header to the file before writing blocks. Defaults to `True`.
 * `metadata`: A dictionary of metadata to write to the file. Defaults to an empty dictionary.
 * `marker`: A 16-byte marker to use to separate blocks. Defaults to a random UUID.
 * `options`: An Options object to use when writing. Defaults to the default options.

#### Members:





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/container.pxi#L238" target="_blank">[source]</a>
</div>

##### `method` close(self)




<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/container.pxi#L264" target="_blank">[source]</a>
</div>

##### `method` flush(self, force=False)




<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/container.pxi#L284" target="_blank">[source]</a>
</div>

##### `method` write_many(self, objs)




##### `attr` closed



##### `attr` schema



##### `attr` codec



##### `attr` marker



##### `attr` max_blocksize



##### `attr` options



##### `attr` should_write_header



##### `attr` num_pending



##### `attr` blocks_written



##### `attr` metadata







<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/container.pxi#L267" target="_blank">[source]</a>
</div>

##### `method` write_one(self, obj)






  
### `class` FileReader
A cavro wrapper for reading data from a file-like object (Object that implements `.read(n)`).

This class will not close or seek the underlying file object

Arguments:
    `file_obj`: The file-like object to read from.

#### Members:

##### `init` FileReader(self, /, *args, **kwargs)













  
### `class` FileWriter
A cavro wrapper for writing data to a file-like object (Object that implements `.write(data)` and `.flush()`).

This class will not close or seek the underlying file object

#### Members:

##### `init` FileWriter(self, /, *args, **kwargs)













  


## Other Classes






### `class` MemoryWriter
A class that writes to a memory buffer. The buffer is automatically resized to fit the data.

The underlying data is accessible through the `buffer` attribute as an `array.array` of bytes.

#### Members:


##### `attr` buffer



##### `attr` len










### `class` MemoryReader
A class that allows cavro to read binary data from a memory buffer.

Arguments:
 * data: The data to read from. Can be a `bytes` object or a `memoryview`.

#### Members:

##### `init` MemoryReader(self, /, *args, **kwargs)














### `class` Rabin
An implementation of the 64-bit Rabin hash function  as described in the avro specification.

The interface in this class roughly approximates the `hashlib.hash` objects.

#### Members:

##### `init` Rabin(self, /, *args, **kwargs)





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/rabin.pxi#L52" target="_blank">[source]</a>
</div>

##### `method` digest(self)




<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/rabin.pxi#L56" target="_blank">[source]</a>
</div>

##### `method` hexdigest(self)




<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/rabin.pxi#L59" target="_blank">[source]</a>
</div>

##### `method` copy(self)




##### `attr` value







##### `attr` name



##### `attr` digest_size



##### `attr` block_size



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/rabin.pxi#L44" target="_blank">[source]</a>
</div>

##### `method` update(self, data)









### `class` Record
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

#### Members:

##### `init` Record(self, /, *args, **kwargs)

























### `class` RecordField
Holds the metadata for a record schema field.
This class should never be instantiated directly, instead it is created by `RecordType` when parsing a schema.

#### Members:

##### `init` RecordField(self, /, *args, **kwargs)





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/record.pxi#L242" target="_blank">[source]</a>
</div>

##### `method` get_schema(self, created)




##### `attr` name



##### `attr` writer_name



##### `attr` doc



##### `attr` type



##### `attr` default_value



##### `attr` order



##### `attr` aliases


















### `class` AvroType
The base class for all Avro types.
`cavro` separates the concept of a `Schema` from a `Type`, which is not strictly neccessary, but
makes some management of state a bit easier.
Here, a `Type` is the specific implementation of the data management, whereas a `Schema` is the
public interface for a schema definition, typically (but not always) containing multiple types either in unions or in nested record fields.

For normal usage, the `AvroType` class and subclasses can largely be ignored.

#### Members:

##### `init` AvroType(self, /, *args, **kwargs)






<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/type.pxi#L63" target="_blank">[source]</a>
</div>

##### `method` for_source(cls, schema, source, namespace=None)




<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/type.pxi#L84" target="_blank">[source]</a>
</div>

##### `method` for_schema(cls, schema)




<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/type.pxi#L286" target="_blank">[source]</a>
</div>

##### `method` walk_types(self, visited)




##### `attr` type



##### `attr` options



##### `attr` metadata



##### `attr` value_adapters







##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/type.pxi#L108" target="_blank">[source]</a>
</div>

##### `method` copy(self)





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/type.pxi#L134" target="_blank">[source]</a>
</div>

##### `method` convert_value(self, value, check_value=False)





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/type.pxi#L292" target="_blank">[source]</a>
</div>

##### `method` get_schema(self, created=None)









### `class` UnionType
The avro union type

#### Members:

##### `init` UnionType(self, /, *args, **kwargs)





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/union.pxi#L90" target="_blank">[source]</a>
</div>

##### `method` walk_types(self, visited)




##### `attr` union_types



##### `attr` by_name_map



##### `attr` return_type_tuple







##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/union.pxi#L77" target="_blank">[source]</a>
</div>

##### `method` copy(self)




<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/union.pxi#L97" target="_blank">[source]</a>
</div>

##### `method` get_schema(self, created=None)




<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/union.pxi#L170" target="_blank">[source]</a>
</div>

##### `method` convert_value(self, value, check_value=True)









### `class` StringType
The avro string type

#### Members:





##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/string_types.pxi#L97" target="_blank">[source]</a>
</div>

##### `method` copy(self)











### `class` BytesType
The avro bytes type

#### Members:





##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/string_types.pxi#L7" target="_blank">[source]</a>
</div>

##### `method` copy(self)













### `class` DoubleType
The avro double type.

#### Members:





##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/numeric_types.pxi#L328" target="_blank">[source]</a>
</div>

##### `method` copy(self)











### `class` FloatType
The avro float type.

#### Members:





##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/numeric_types.pxi#L213" target="_blank">[source]</a>
</div>

##### `method` copy(self)











### `class` LongType
The avro long type.

#### Members:





##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/numeric_types.pxi#L137" target="_blank">[source]</a>
</div>

##### `method` copy(self)











### `class` IntType
The avro int type.

#### Members:





##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/numeric_types.pxi#L65" target="_blank">[source]</a>
</div>

##### `method` copy(self)











### `class` BoolType
The avro boolean type.

#### Members:





##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/numeric_types.pxi#L15" target="_blank">[source]</a>
</div>

##### `method` copy(self)











### `class` NullType
The avro null type.

#### Members:





##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/null.pxi#L6" target="_blank">[source]</a>
</div>

##### `method` copy(self)











### `class` MapType
The avro map type.

#### Members:

##### `init` MapType(self, /, *args, **kwargs)





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/map.pxi#L23" target="_blank">[source]</a>
</div>

##### `method` walk_types(self, visited)




##### `attr` value_type







##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/map.pxi#L14" target="_blank">[source]</a>
</div>

##### `method` copy(self)





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/map.pxi#L122" target="_blank">[source]</a>
</div>

##### `method` convert_value(self, orig_value, check_value=True)









### `class` ArrayType
The avro array type.

#### Members:

##### `init` ArrayType(self, /, *args, **kwargs)





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/array.pxi#L23" target="_blank">[source]</a>
</div>

##### `method` walk_types(self, visited)




##### `attr` item_type







##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/array.pxi#L15" target="_blank">[source]</a>
</div>

##### `method` copy(self)





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/array.pxi#L92" target="_blank">[source]</a>
</div>

##### `method` convert_value(self, value, check_value=True)











### `class` FixedType
The avro fixed type

#### Members:

##### `init` FixedType(self, /, *args, **kwargs)





##### `attr` size







##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/string_types.pxi#L163" target="_blank">[source]</a>
</div>

##### `method` copy(self)











### `class` RecordType
The Type that corresponds to a Record in a Schema.

Attributes:
 * `doc` Any "doc" metadata defined in the schema
 * `fields` A tuple of `RecordField` instances, one for each field in the record
 * `record` A subclass of `Record` that can be used to instantiate records of this type

#### Members:

##### `init` RecordType(self, /, *args, **kwargs)





<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/record.pxi#L364" target="_blank">[source]</a>
</div>

##### `method` walk_types(self, visited)




##### `attr` doc



##### `attr` fields



##### `attr` record







##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/record.pxi#L346" target="_blank">[source]</a>
</div>

##### `method` copy(self)











### `class` PromotingRecordType
A variant of a `RecordType`, specialized for reading records from a different schema from a writer.

#### Members:










### `class` EnumType
The avro enum type

#### Members:

##### `init` EnumType(self, /, *args, **kwargs)





##### `attr` symbols



##### `attr` default_value



##### `attr` doc







##### `attr` type_name



<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/enum.pxi#L47" target="_blank">[source]</a>
</div>

##### `method` copy(self)











### `class` PromotingEnumType
The avro enum type

#### Members:

##### `attr` unknown_symbols



##### `attr` reader_type



##### `attr` writer_type












### `class` ResolvedSchema
A variant of a schema that is the result of schema promotion.

#### Members:

##### `init` ResolvedSchema(self, /, *args, **kwargs)














### `class` ValueAdapter
Abstract base class for any helper that affects how values are transformed prior to avro encoding/decoding.

#### Members:











### `class` LogicalType
Semi-abstract class for all logical types.

Subclasses must be implemented as cython classes.

#### Members:



##### `method` for_type(unknown)








##### `attr` logical_name



##### `attr` underlying_types








### `class` CustomLogicalType
Logical type that allows custom encoding/decoding functions to be provided.

To use a custom logical type, subclass this class, and implement the:
 * `encode_value(value: object) -> object` - Transforms a provided value into something that can be encoded by the underlying type.
 * `decode_value(value: object) -> object` - Transforms a value decoded by the underlying type into a value to return to the user.
methods.

Also implement two class attributes, and a classmethod:
 * `logical_name` - The name to look for in the schema
 * `underlying_types` A tuple of `AvtoType` classes that this logical type can be applied to.
 * `_for_type(cls, underlying: AvroType) -> Cls` 
    A classmethod that returns an instance of the class, optionally customized with information from the underlying type,
    or None if the logical type is not applicable to the underlying type.

#### Members:











### `class` DecimalType
Logical type for decimal values.

#### Members:

##### `init` DecimalType(self, /, *args, **kwargs)






##### `attr` type_name



##### `attr` precision



##### `attr` scale



##### `attr` scale_val



##### `attr` context



##### `attr` size



##### `attr` check_exp_overflow







##### `attr` logical_name



##### `attr` underlying_types








### `class` UUIDBase
Logical type for UUID values

#### Members:

##### `init` UUIDBase(self, /, *args, **kwargs)










##### `attr` logical_name








### `class` UUIDStringType
Logical type for UUID values

#### Members:


##### `attr` type_name







##### `attr` underlying_types








### `class` UUIDFixedType
Logical type for UUID values

#### Members:


##### `attr` type_name







##### `attr` underlying_types








### `class` Date
Logical type for Date values

#### Members:

##### `init` Date(self, /, *args, **kwargs)






##### `attr` type_name



##### `attr` accepts_string







##### `attr` logical_name



##### `attr` underlying_types








### `class` TimeMillis
Logical type for time-millis values

#### Members:



##### `attr` type_name







##### `attr` logical_name



##### `attr` underlying_types








### `class` TimeMicros
Logical type for time-micros values

#### Members:



##### `attr` type_name







##### `attr` logical_name



##### `attr` underlying_types








### `class` TimestampMillis
Logical type for timestamp-micros values

#### Members:

##### `init` TimestampMillis(self, /, *args, **kwargs)






##### `attr` type_name



##### `attr` alternate_timestamp_encoding







##### `attr` logical_name



##### `attr` underlying_types








### `class` TimestampMicros
Logical type for timestamp-micros values

#### Members:



##### `attr` type_name







##### `attr` logical_name



##### `attr` underlying_types








### `class` Codec
Abstract base class for all codecs.  This class is not meant to be used directly.

Subclasses must be implemented in cython.

#### Members:






##### `attr` name






















### `class` PromoteToFloat
A value adapter that converts a value to a float on read.

#### Members:











### `class` PromoteBytesToString
A value adapter that decodes bytes to a string (utf8) on read.

#### Members:











### `class` PromoteStringToBytes
A value adapter that encodes a string to bytes (utf8) on read.

#### Members:











### `class` CannotPromote
A captured schema promotion error that has been deferred by `Options`, the first time this value is read, the error will be raised.

#### Members:

##### `init` CannotPromote(self, /, *args, **kwargs)





##### `attr` reader_type



##### `attr` writer_type



##### `attr` extra
















### `class` CavroException
Base class for exceptions raised by cavro

#### Members:






### `class` InvalidName
The schema contains a type or enum symbol with an invalid name (as per the avro specification)

#### Members:






### `class` UnknownType
The schema contains an unexptected type name (either a missing named-type definition, or invalid primitive type)

#### Members:
<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/error.pxi#L20" target="_blank">[source]</a>
</div>

##### `init` UnknownType(self, name)










### `class` DuplicateName
A record contains multiple fields with the same name, a schema contains multiple types of the same name, or an enum has multiple identical symbols.

#### Members:






### `class` InvalidHasher
An unknown hash method was requested

#### Members:






### `class` ExponentTooLarge
The exponent of a decimal value is too large to be represented in the given type

#### Members:






### `class` CodecUnavailable
A requested codec (or codec in a container) is not available or is unknown.

#### Members:






### `class` CannotPromoteError
A schema cannot be promoted to another schema. (reader/writer schema promotion)

Attributes:
 * `reader_type`: The schema type of the reader
 * `writer_type`: The schema type of the writer
 * `extra`: An optional extra message

#### Members:
<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/error.pxi#L61" target="_blank">[source]</a>
</div>

##### `init` CannotPromoteError(self, reader_type, writer_type, extra=None)










### `class` InvalidValue
A value is invalid for a given avro type.
    
Attributes:
 * `value`: The value that caused the error
 * `dest_type`: The schema type that the value was being converted to
 * `schema_path`: A sequence of identifiers (field names etc) to help locate the value that caused the error

#### Members:
<div>
<a style={{float: 'right'}} href="https://github.com/stestagg/cavro/blob/v0.3.1/src/error.pxi#L82" target="_blank">[source]</a>
</div>

##### `init` InvalidValue(self, value, dest_type, path=())











### `class` UnionDecodeOption
Controls how union values are decoded:
 * RAW_VALUES - The value of the matching union type is returned unmodified
 * TYPE_TUPLE_IF_AMBIGUOUS - If union contains types that might be ambiguous (Record + Map) or (String + Enum), then the value is returned as a 2-tuple of (&lt;type>, &lt;value>)
 * TYPE_TUPLE_IF_RECORD_AMBIGUOUS - If union contains multiple record (or map) types, then the value is returned as a 2-tuple of (&lt;type>, &lt;value>)
 * TYPE_TUPLE_IF_RECORD - values matching any union member that is record are returned as a 2-tuple of (&lt;type>, &lt;value>)
 * TYPE_TUPLE_ALWAYS - values are always returned as a 2-tuple of (&lt;type>, &lt;value>)

#### Members:








##### `attr` RAW_VALUES



##### `attr` TYPE_TUPLE_IF_AMBIGUOUS



##### `attr` TYPE_TUPLE_IF_RECORD_AMBIGUOUS



##### `attr` TYPE_TUPLE_IF_RECORD



##### `attr` TYPE_TUPLE_ALWAYS


















### `class` Order
The order of a field in a record.

#### Members:








##### `attr` ASC



##### `attr` DESC



##### `attr` IGNORE


































































































































