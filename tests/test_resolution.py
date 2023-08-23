import cavro
import pytest


def test_promote_bytes_to_str():
    writer_schema = cavro.Schema('"string"')
    reader_schema = cavro.Schema('"bytes"')
    resolved = reader_schema.reader_for_writer(writer_schema)
    encoded = writer_schema.binary_encode("hello")
    assert resolved.binary_decode(encoded) == b"hello"


@pytest.mark.parametrize(
    "writer_schema,reader_schema,value,expected",
    [
        ('"int"', '"long"', 1, 1),
        ('"int"', '"float"', 2, 2.),
        ('"int"', '"double"', 3, 3.),
        ('"long"', '"float"', 4, 4.),
        ('"long"', '"double"', 5, 5.),
        ('"float"', '"double"', 6., 6.),
        ({"type": "array", "items": "int"}, {"type": "array", "items": "float"}, [1, 2, 3], [1., 2., 3.]),
        ({"type": "map", "values": "int"}, {"type": "map", "values": "float"}, {'a': 1}, {'a': 1.}),

    ]
)
def test_simple_promotions(writer_schema, reader_schema, value, expected):
    writer_schema = cavro.Schema(writer_schema)
    reader_schema = cavro.Schema(reader_schema)
    resolved = reader_schema.reader_for_writer(writer_schema)
    encoded = writer_schema.binary_encode(value)
    assert resolved.binary_decode(encoded) == expected


@pytest.mark.parametrize(
    "writer_schema,reader_schema",
    [
        ('"long"', '"int"'),
        ('"float"', '"int"'),
        ('"double"', '"int"'),
        ('"float"', '"long"'),
        ('"double"', '"long"'),
        ('"double"', '"float"'),
    ]
)
def test_invalid_promotions(writer_schema, reader_schema):
    writer_schema = cavro.Schema(writer_schema)
    reader_schema = cavro.Schema(reader_schema)
    with pytest.raises(cavro.CannotPromoteError) as exc_info:
        reader_schema.reader_for_writer(writer_schema)
    assert exc_info.value.reader_type is reader_schema.type
    assert exc_info.value.writer_type is writer_schema.type


def test_record_resolution_dict():
    reader = cavro.Schema({
        "type": "record",
        "name": "test",
        "fields": [
            {"name": "a", "type": "long"},
            {"name": "b", "type": "bytes"},
            {"name": "c", "type": "string", "default": "world"},
        ]
    }, record_decodes_to_dict=True)
    writer = cavro.Schema({
        "type": "record",
        "name": "test",
        "fields": [
            {"name": "a", "type": "int"},
            {"name": "b", "type": "string"},
        ]
    })
    resolved = reader.reader_for_writer(writer)

    encoded = writer.binary_encode({"a": 1, "b": "hello"})
    decoded = resolved.binary_decode(encoded)
    assert decoded == {"a": 1, "b": b"hello", "c": "world"}


def test_record_resolution_record():
    reader = cavro.Schema({
        "type": "record",
        "name": "test",
        "fields": [
            {"name": "a", "type": "long"},
            {"name": "b", "type": "bytes"},
            {"name": "c", "type": "string", "default": "world"},
        ]
    }, record_decodes_to_dict=False)
    writer = cavro.Schema({
        "type": "record",
        "name": "test",
        "fields": [
            {"name": "a", "type": "int"},
            {"name": "b", "type": "string"},
        ]
    })
    resolved = reader.reader_for_writer(writer)

    encoded = writer.binary_encode({"a": 1, "b": "hello"})
    decoded = resolved.binary_decode(encoded)
    assert decoded == reader.named_types['test'].record(a=1, b=b'hello', c='world')


def test_record_resolution_alias():
    reader = cavro.Schema({
        "type": "record",
        "name": "test",
        "fields": [
            {"name": "a", "type": "long"},
            {"name": "b", "type": "bytes", "aliases": ["c"]},
        ]
    }, record_decodes_to_dict=True)
    writer = cavro.Schema({
        "type": "record",
        "name": "test",
        "fields": [
            {"name": "a", "type": "int"},
            {"name": "c", "type": "string"},
        ]
    })
    resolved = reader.reader_for_writer(writer)

    encoded = writer.binary_encode({"a": 1, "c": "hello"})
    decoded = resolved.binary_decode(encoded)
    assert decoded == {"a": 1, "b": b"hello"}