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


def test_int_overflow():
    schema = cavro.Schema('"int"')
    assert schema.can_encode(2**32) == False
    with pytest.raises(OverflowError) as exc:
        schema.binary_encode(2**33)
    assert "value too large" in str(exc.value)


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
