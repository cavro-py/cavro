import cavro
import pytest

import struct

@pytest.mark.parametrize("value,expected", [
    (0, b'\x00'),
    (-1, b'\x01'),
    (1, b'\x02'),
    (-2, b'\x03'),
    (2, b'\x04'),
    (-64, b'\x7f'),
    (64, b'\x80\x01'),
    ((2**31)-1, b'\xfe\xff\xff\xff\x0f'),
    (-(2**31), b'\xff\xff\xff\xff\x0f'),
])
def test_int_encoding(value, expected):
    schema = cavro.Schema('"int"')
    assert schema.binary_encode(value) == expected


def test_int_overflow():
    schema = cavro.Schema('"int"')
    assert schema.can_encode(2**32) == False
    with pytest.raises(OverflowError) as exc:
        schema.binary_encode(2**33)
    assert "value too large" in str(exc.value)


def test_int_json():
    schema = cavro.Schema('"int"')
    assert schema.json_encode(1) == "1"
    assert schema.json_encode(2**31-1) == "2147483647"
    with pytest.raises(OverflowError ):
        schema.json_encode(2**63-1)


@pytest.mark.parametrize("value,expected", [
    (0, b'\x00'),
    (-1, b'\x01'),
    (1, b'\x02'),
    (-2, b'\x03'),
    (2, b'\x04'),
    (-64, b'\x7f'),
    (64, b'\x80\x01'),
    ((2**31)-1, b'\xfe\xff\xff\xff\x0f'),
    (-(2**31), b'\xff\xff\xff\xff\x0f'),
    ((2**63)-1, b'\xfe\xff\xff\xff\xff\xff\xff\xff\xff\x01'),
    (-(2**63), b'\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01'),
])
def test_long_encoding(value, expected):
    schema = cavro.Schema('"long"')
    assert schema.binary_encode(value) == expected


def test_long_overflow():
    schema = cavro.Schema('"long"')
    assert schema.can_encode(2**64) == False
    with pytest.raises(OverflowError) as exc:
        schema.binary_encode(2**65)
    assert "too large" in str(exc.value)
    with pytest.raises(OverflowError) as exc:
        schema.binary_encode(-2**65)
    assert "too large" in str(exc.value)


def test_long_json():
    schema = cavro.Schema('"long"')
    assert schema.json_encode(1) == "1"
    assert schema.json_encode(2**31-1) == "2147483647"
    assert schema.json_encode(2**63-1) == "9223372036854775807"
    with pytest.raises(OverflowError):
        schema.json_encode(2**64)


@pytest.mark.parametrize("value", [
    3.1415, -1, -0.1, 0, 0.1, 1, 10, 100, 1e10, 3e38
])
def test_float_encoding(value):
    schema = cavro.Schema('"float"')
    assert schema.binary_encode(value) == struct.pack('<f', value)


@pytest.mark.parametrize("value", [
    3.1415, -1, -0.1, 0, 0.1, 1, 10, 100, 1e10, 3e38, 1.01e100, 1e308
])
def test_double_encoding(value):
    schema = cavro.Schema('"double"')
    assert schema.binary_encode(value) == struct.pack('<d', value)


def test_float_json():
    schema = cavro.Schema('"float"')
    assert schema.json_encode(3.14159e2) == "314.159"
    assert schema.json_encode(31.4159e30) == "3.14159e+31"


def test_double_json():
    schema = cavro.Schema('"double"')
    assert schema.json_encode(3.14159e2) == "314.159"
    assert schema.json_encode(31.4159e200) == "3.14159e+201"