import dataclasses
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
    schema_obj = cavro.Schema(schema, cavro.PERMISSIVE_OPTIONS.replace(canonical_form_repeat_fixed_enum=False))
    assert schema_obj.canonical_form == expected


def test_default_canonical_form_repeats_fixed_enum():
    '''This appears to be a bug in avro/python, fixed types are repeated in the canonical form'''
    schema = cavro.Schema({
        'type': 'record',
        'name': 'Foo',
        'fields': [
            {'name': 'a', 'type': {'type': 'fixed', 'size': 8, 'name': 'Xxx', 'namespace': 'com.x'}},
            {'name': 'b', 'type': {'type': 'com.x.Xxx'}},
            {'name': 'c', 'type': {'type': 'enum', 'symbols': ['a'], 'name': 'X'}},
            {'name': 'd', 'type': {'type': 'X'}},
            {'name': 'e', 'type': {'type': 'Foo'}},
        ],
    },
    canonical_form_repeat_fixed_enum=True)
    assert schema.canonical_form == '''{
        "name": "Foo",
        "type": "record",
        "fields": [
            {
                "name": "a",
                "type": {
                    "name": "com.x.Xxx",
                    "type": "fixed",
                    "size": 8
                }
            },
            {
                "name": "b",
                "type": {
                    "name": "com.x.Xxx",
                    "type": "fixed",
                    "size": 8
                }
            },
            {"name": "c", "type": {"name": "X", "type": "enum", "symbols": ["a"]}},
            {"name": "d", "type": {"name": "X", "type": "enum", "symbols": ["a"]}},
            {"name": "e", "type": "Foo"}
        ]
    }'''.replace(' ', '').replace('\n', '')