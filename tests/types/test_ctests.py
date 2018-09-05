import cavro
import pytest

import struct


@pytest.mark.parametrize("name, fn", cavro._tests.items())
def test_c_test(name, fn):
    fn()


def test_enum_json_encoding():
    schema = cavro.Schema({'type': 'enum', 'name': 'A', 'symbols': ['a', 'b', 'c']})
    schema.json_encode('a') == 'a'
    schema.json_encode('c') == 'c'
    with pytest.raises(KeyError):
        schema.json_encode('d')


def test_enum_with_duplicate_symbols():
    with pytest.raises(ValueError):
        cavro.Schema({
            'type': 'enum',
            'name': 'A',
            'symbols': ['a', 'b', 'b']
        })


def test_enum_with_invalid_symbol_type():
    with pytest.raises(ValueError):
        cavro.Schema({
            'type': 'enum',
            'name': 'A',
            'symbols': True
        })

def test_enum_with_invalid_symbols():
    with pytest.raises(ValueError):
        cavro.Schema({
            'type': 'enum',
            'name': 'A',
            'symbols': ['one', 2, 'do']
        })
    schema = cavro.Schema({
            'type': 'enum',
            'name': 'A',
            'symbols': ['one', 2, 'do']
        }, permissive=True)
    assert schema.binary_encode(2) == b'\x02'