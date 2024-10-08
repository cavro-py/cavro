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


def test_allow_false_null_encoding():
    schema = cavro.Schema('"null"', cavro.Options(allow_false_values_for_null=True))
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


def test_allow_false_null_json_encoding():
    schema = cavro.Schema('"null"', cavro.Options(allow_false_values_for_null=True))
    assert schema.json_encode(None) == 'null'
    assert schema.json_encode(False) == 'null'
    with pytest.raises(ValueError):
        schema.binary_encode(1)


@pytest.mark.parametrize(
    'given, can_encode, allow_false_encode',
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
def test_json_can_encode(given, can_encode, allow_false_encode):
    assert cavro.Schema('"null"').can_encode(given) == can_encode
    allow_schema = cavro.Schema('"null"', cavro.Options(allow_false_values_for_null=True))
    assert allow_schema.can_encode(given) == allow_false_encode

def test_json_decode():
    schema = cavro.Schema('"null"')
    assert schema.json_decode('null') is None
    with pytest.raises(ValueError):
        schema.json_decode('1')

def test_null_canonical_form():
    schema = cavro.Schema('"null"')
    assert schema.canonical_form == '"null"'
