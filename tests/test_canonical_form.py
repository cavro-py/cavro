import cavro
import pytest


@pytest.mark.parametrize(
    ['schema', 'expected'],
    [
        ('"null"', '"null"'),
        ({'type': 'null'}, '"null"'),
        ({'type': 'bool'}, '"bool"'),
        ({'type': 'int'}, '"int"'),
        ({'type': 'long'}, '"long"'),
        ({'type': 'float'}, '"float"'),
        ({'type': 'double'}, '"double"'),
        ('"bytes"', '"bytes"'),
        ('"string"', '"string"'),
        ({'type': 'enum', 'symbols': ['X', 'A', '\u00a3'], 'name': 'Foo', 'doc': 'bar'},
         '{"name":"Foo","type":"enum","symbols":["X","A","£"]}'),
        ('{"type": "enum", "symbols": ["X", "A", "\\u00a3"], "name": "Foo", "doc": "bar"}',
         '{"name":"Foo","type":"enum","symbols":["X","A","£"]}'),
        ({"type": "fixed", "size": 16, "name": "md5", "aliases": ["bob"]},
         '{"name":"md5","type":"fixed","size":16}')

    ]
)
def test_canonical_form(schema, expected):
    schema_obj = cavro.Schema(schema)
    assert schema_obj.canonical_form == expected