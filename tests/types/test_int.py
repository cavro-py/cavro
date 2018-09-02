import cavro
import pytest

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