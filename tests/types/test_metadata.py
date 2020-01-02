import pytest
import cavro


@pytest.mark.parametrize('given,expected', [
    ('{"type": "string"}', {}),
    ('"string"', {}),
    ('{"type": "string", "foo": "bar"}', {'foo': 'bar'}),
    ('{"type": "string", "name": "xx"}', {'name': 'xx'}),
    ('{"type": "enum", "symbols": ["X"], "name": "xx"}', {}),
    
    ('{"type": "null"}', {}),
    ('{"type": "null", "foo": "bar"}', {'foo': 'bar'}),
    ('{"type": "boolean"}', {}),
    ('{"type": "boolean", "foo": "bar"}', {'foo': 'bar'}),
    ('{"type": "int"}', {}),
    ('{"type": "int", "foo": "bar"}', {'foo': 'bar'}),
    ('{"type": "long"}', {}),
    ('{"type": "long", "foo": "bar"}', {'foo': 'bar'}),
    ('{"type": "float"}', {}),
    ('{"type": "float", "foo": "bar"}', {'foo': 'bar'}),
    ('{"type": "double"}', {}),
    ('{"type": "double", "foo": "bar"}', {'foo': 'bar'}),
    ('{"type": "bytes"}', {}),
    ('{"type": "bytes", "foo": "bar"}', {'foo': 'bar'}),
    ('{"type": "null"}', {}),
    ('{"type": "null", "foo": "bar"}', {'foo': 'bar'}),
    ('{"type": "array", "items": "int"}', {}),
    ('{"type": "array", "items": "int", "foo": "bar"}', {'foo': 'bar'}),
    ('{"type": "map", "values": "int"}', {}),
    ('{"type": "map", "values": "int", "foo": "bar"}', {'foo': 'bar'}),


    ('{"type": "record", "name": "X", "doc": "bob", "fields": []}', {}),
    ('{"type": "record", "name": "X", "doc": "bob", "fields": [], "foo": "bar"}', {'foo': 'bar'}),

])
def test_expected_metadata(given, expected):
    schema = cavro.Schema(given)
    assert schema.type.metadata == expected