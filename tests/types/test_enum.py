import cavro
import pytest

import struct


def test_enum_encoding():
    schema = cavro.Schema({'type': 'enum', 'name': 'A', 'symbols': ['a', 'b', 'c']})
    assert schema.binary_encode('a') == b'\x00'
    assert schema.binary_encode('c') == b'\x04'
    with pytest.raises(KeyError):
         schema.binary_encode('d')


def test_enum_json_encoding():
    schema = cavro.Schema({'type': 'enum', 'name': 'A', 'symbols': ['a', 'b', 'c']})
    schema.json_encode('a') == 'a'
    schema.json_encode('c') == 'c'
    with pytest.raises(KeyError):
        schema.json_encode('d')