import cavro
import pytest


@pytest.mark.parametrize(
    ['schema', 'expected'],
    [
        ('"null"', '"null"'),
        ({'type': 'null'}, '"null"'),
        ({'type': 'boolean'}, '"boolean"'),
        ({'type': 'int'}, '"int"'),
        ({'type': 'long'}, '"long"'),
        ({'type': 'float'}, '"float"'),
        ({'type': 'double'}, '"double"'),
        ('"bytes"', '"bytes"'),
        ('"string"', '"string"'),
        (
            {'type': 'fixed', 'size': 12, 'name': 'F'},
            '{"name":"F","type":"fixed","size":12}'
        ),
        ({'type': 'enum', 'symbols': ['X', 'A', '\u00a3'], 'name': 'Foo', 'doc': 'bar'},
         '{"name":"Foo","type":"enum","symbols":["X","A","£"]}'),
        ('{"type": "enum", "symbols": ["X", "A", "\\u00a3"], "name": "Foo", "doc": "bar"}',
         '{"name":"Foo","type":"enum","symbols":["X","A","£"]}'),
        ('{"type": "record", "fields": [{"name": "a", "type": "Foo"}], "name": "Foo"}',
         '{"name":"Foo","type":"record","fields":[{"name":"a","type":"Foo"}]}'),
        ('''{"type": "record", "name": "rec", "fields": [
                {"name": "a", "type": {"type": "enum", "symbols": ["a"], "name": "X"}},
                {"name": "b", "type": {"type": "X"}}
        ]}''',
        '{"name":"rec","type":"record","fields":[{"name":"a","type":{"name":"X","type":"enum","symbols":["a"]}},{"name":"b","type":"X"}]}'),
        ({'type': 'array', 'items': 'long'}, '{"type":"array","items":"long"}'),
        (
            {'type': 'map', 'values': {'type': 'fixed', 'size': 8, 'name': 'Xxx', 'namespace': 'com.x'}},
            '{"type":"map","values":{"name":"com.x.Xxx","type":"fixed","size":8}}'
        )
    ]
)
def test_canonical_form(schema, expected):
    schema_obj = cavro.Schema(schema, cavro.PERMISSIVE_OPTIONS)
    assert schema_obj.canonical_form == expected