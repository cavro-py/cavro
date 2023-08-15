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

@pytest.mark.parametrize("expected, value", [
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
def test_int_decoding(value, expected):
    schema = cavro.Schema('"int"')
    assert schema.binary_decode(value) == expected

def test_int_overflow():
    schema = cavro.Schema('"int"')
    assert schema.can_encode(2**32) == False
    with pytest.raises(OverflowError) as exc:
        schema.binary_encode(2**33)
    assert "out of range" in str(exc.value)


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
    (92, b'\xb8\x01'),
    ((2**31)-1, b'\xfe\xff\xff\xff\x0f'),
    (-(2**31), b'\xff\xff\xff\xff\x0f'),
    (3683971297255489547, b'\x96\x80\xb0\xfa\x8a\x98\x8c\xa0\x66'),
    ((2**63)-1, b'\xfe\xff\xff\xff\xff\xff\xff\xff\xff\x01'),
    (-(2**63), b'\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01'),
])
def test_long_encoding(value, expected):
    schema = cavro.Schema('"long"')
    assert schema.binary_encode(value) == expected


@pytest.mark.parametrize("expected,value", [
    (0, b'\x00'),
    (-1, b'\x01'),
    (1, b'\x02'),
    (-2, b'\x03'),
    (2, b'\x04'),
    (-64, b'\x7f'),
    (64, b'\x80\x01'),
    (92, b'\xb8\x01'),
    ((2**31)-1, b'\xfe\xff\xff\xff\x0f'),
    (-(2**31), b'\xff\xff\xff\xff\x0f'),
    (3683971297255489547, b'\x96\x80\xb0\xfa\x8a\x98\x8c\xa0\x66'),
    ((2**63)-1, b'\xfe\xff\xff\xff\xff\xff\xff\xff\xff\x01'),
    (-(2**63), b'\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01'),
])
def test_long_decoding(value, expected):
    schema = cavro.Schema('"long"')
    assert schema.binary_decode(value) == expected

def test_long_overflow():
    schema = cavro.Schema('"long"')
    assert schema.can_encode(2**64) == False
    with pytest.raises(OverflowError) as exc:
        schema.binary_encode(2**65)
    assert "out of range" in str(exc.value)
    with pytest.raises(OverflowError) as exc:
        schema.binary_encode(-2**65)
    assert "out of range" in str(exc.value)


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
    schema = cavro.Schema('{"type": "float"}')
    encoded = schema.json_encode(3.14159e2)
    assert isinstance(encoded, str)
    assert float(encoded) == 314.159
    encoded = schema.json_encode(31.4159e30)
    assert isinstance(encoded, str)
    assert float(encoded) == 3.14159e+31


def test_double_json():
    schema = cavro.Schema('"double"')
    encoded = schema.json_encode(3.14159e2)
    assert isinstance(encoded, str)
    assert float(encoded) == 314.159
    encoded = schema.json_encode(31.4159e200)
    assert isinstance(encoded, str)
    assert float(encoded) == 3.14159e+201


def test_decode_float_json():
    schema = cavro.Schema('"float"')
    assert schema.json_decode("3.14159") == 3.14159
    with pytest.raises(ValueError):
        schema.json_decode('"3.14159"')
    with pytest.raises(OverflowError):
        schema.json_decode('1e100')


def test_decode_double_json():
    schema = cavro.Schema('"double"')
    assert schema.json_decode("3.14159") == 3.14159
    with pytest.raises(ValueError):
        schema.json_decode('"3.14159"')


def test_decode_int_json():
    schema = cavro.Schema('"int"')
    assert schema.json_decode("23") == 23
    with pytest.raises(ValueError):
        schema.json_decode('12.23')
    with pytest.raises(OverflowError):
        schema.json_decode('4294967296')


def test_decode_long_json():
    schema = cavro.Schema('"long"')
    assert schema.json_decode("23") == 23
    with pytest.raises(ValueError):
        schema.json_decode('12.23')
    with pytest.raises(OverflowError):
        schema.json_decode('18446744073709551616')


@pytest.mark.parametrize('value,encodable', [
    (3.14, True),
    (3, True),
    (-3.14, True),
    (1e100, True),
    (True, False),
    ("100", False),
    (1000 ** 1000, False),
])
def test_double_can_encode(value, encodable):
    schema = cavro.Schema('"double"')
    assert schema.can_encode(value) == encodable

@pytest.mark.parametrize('value,encodable', [
    (3.14, True),
    (3, True),
    (-3.14, True),
    (3e38, True),
    (1e100, False),
    ("100", False),
    (True, False),
    (1000 ** 1000, False),
])
def test_float_can_encode(value, encodable):
    schema = cavro.Schema('"float"')
    assert schema.can_encode(value) == encodable


def test_float_nan_inf():
    schema = cavro.Schema('"float"')
    assert schema.binary_encode(float('nan')) == b'\x00\x00\xc0\x7f'
    assert schema.binary_encode(float('inf')) == b'\x00\x00\x80\x7f'
    assert schema.binary_encode(float('-inf')) == b'\x00\x00\x80\xff'


def test_double_nan_inf():
    schema = cavro.Schema('"double"')
    assert schema.binary_encode(float('nan')) == b'\x00\x00\x00\x00\x00\x00\xf8\x7f'
    assert schema.binary_encode(float('inf')) == b'\x00\x00\x00\x00\x00\x00\xf0\x7f'
    assert schema.binary_encode(float('-inf')) == b'\x00\x00\x00\x00\x00\x00\xf0\xff'

