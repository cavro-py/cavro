import cavro
import pytest

import struct


def test_null_encoding():
    schema = cavro.Schema('"null"')
    assert schema.binary_encode(None) == b''
    with pytest.raises(ValueError):
        schema.binary_encode('d')
    with pytest.raises(ValueError):
        schema.binary_encode('')


def test_permissive_null_encoding():
    schema = cavro.Schema('"null"', permissive=True)
    assert schema.binary_encode(None) == b''
    assert schema.binary_encode(False) == b''
    assert schema.binary_encode(0) == b''
    with pytest.raises(ValueError):
        schema.binary_encode(1)
    with pytest.raises(ValueError):
        schema.binary_encode('Hi')


def test_null_json_encoding():
    schema = cavro.Schema('"null"')
    assert schema.json_encode(None) == 'null'
    with pytest.raises(ValueError):
        schema.binary_encode(1)

def test_permissive_null_json_encoding():
    schema = cavro.Schema('"null"')
    assert schema.json_encode(None) == 'null'
    with pytest.raises(ValueError):
        schema.binary_encode(1)

@pytest.mark.parametrize(
    'given, can_encode, permissive_encode',
    (
        (None, True, True),
        ('', False, True),
        ((), False, True),
        (0, False, True),
        (0.0, False, True),
        (1, False, False),
        ('x', False, False),
    )
)
def test_json_can_encode(given, can_encode, permissive_encode):
    assert cavro.Schema('"null"').can_encode(given) == can_encode
    assert cavro.Schema('"null"', permissive=True).can_encode(given) == permissive_encode

def test_null_encoding():
    schema = cavro.Schema('"null"')
    assert schema.canonical_form == '"null"'
