import cavro


def test_record_creation():
    schema = cavro.Schema({'type': 'record', 'name': 'A', 'fields': [
        {'name': 'a', 'type': 'int'},
        {'name': 'b', 'type': 'int', 'default': 123},
    ]})
    rec = schema.named_types['A'].record({'a': 1})
    assert repr(rec) == '<Record:A {a: 1 b: 123}>'


def test_record_schema():
    schema = cavro.Schema({'type': 'record', 'name': 'A', 'fields': [
        {'name': 'a', 'type': 'int'},
    ]})
    assert isinstance(schema.type, cavro.RecordType)
    assert len(schema.type.fields) == 1

def test_read_record():
    schema = cavro.Schema({'type': 'record', 'name': 'A', 'fields': [
        {'name': 'a', 'type': 'int'},
        {'name': 'b', 'type': 'long'},
    ]})
    assert schema.binary_decode(b'\x02\x04')._asdict() == {'a': 1, 'b': 2}

def test_write_record_from_dict():
    schema = cavro.Schema({'type': 'record', 'name': 'A', 'fields': [
        {'name': 'a', 'type': 'int'},
        {'name': 'b', 'type': 'long'},
    ]})
    assert schema.binary_encode({'a': 1, 'b': 2}) == b'\x02\x04'

def test_write_record_from_record():
    schema = cavro.Schema({'type': 'record', 'name': 'A', 'fields': [
        {'name': 'a', 'type': 'int'},
        {'name': 'b', 'type': 'long'},
    ]})
    rec = schema.type.record({'a': 1, 'b': 2})
    assert schema.binary_encode(rec) == b'\x02\x04'

def test_asdict_nested():
    schema = cavro.Schema({'type': 'record', 'name': 'A', 'fields': [
        {'name': 'a', 'type': 'int'},
        {'name': 'b', 'type': 'string'},
        {
            'name': 'c',
            'type': ['null', {'type': 'A'}]
        },
    ]})
    rec = schema.type.record(a=1, b='hi', c={'a': 2, 'b': 'hoho', 'c': None})
    assert rec._asdict() == {'a': 1, 'b': 'hi', 'c': {'a': 2, 'b': 'hoho', 'c':  None}}
    assert rec.c.a == 2
    assert isinstance(rec.c, schema.type.record)


def test_record_json_encoding():
    schema = cavro.Schema({'type': 'record', 'name': 'A', 'fields': [
        {'name': 'a', 'type': 'int'},
        {'name': 'b', 'type': 'long'},
        {'name': 'c', 'type': ["null", "string"]},
    ]})
    assert schema.json_encode({'a': 1, 'b': 2, 'c': 'hi'}) == '{"a": 1, "b": 2, "c": {"string": "hi"}}'


def test_record_json_decoding():
    schema = cavro.Schema({'type': 'record', 'name': 'A', 'fields': [
        {'name': 'a', 'type': 'int'},
        {'name': 'b', 'type': 'long'},
        {'name': 'c', 'type': ["null", "string"]},
    ]})
    expected = schema.type.record(a=1, b=2, c='hi')
    assert schema.json_decode('{"a": 1, "b": 2, "c": {"string": "hi"}}') == expected