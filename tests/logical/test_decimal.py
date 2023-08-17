import cavro
import pytest

import decimal


@pytest.mark.parametrize(
    "value, expected",
    [
        ("0.0", b"\x02\x00"),
        ("-0.0", b"\x02\x00"),
        ("0.1", b"\x02d"),
        ("-0.1", b"\x02\x9c"),
        ("0.2", b"\x04\x00\xc8"),
        ("-0.2", b"\x04\xff8"),
        ("0.456", b"\x04\x01\xc8"),
        ("-0.456", b"\x04\xfe8"),
        ("2.55", b"\x04\t\xf6"),
        ("-2.55", b"\x04\xf6\n"),
        ("2.90", b"\x04\x0bT"),
        ("-2.90", b"\x04\xf4\xac"),
        ("123.456", b"\x06\x01\xe2@"),
        ("-123.456", b"\x06\xfe\x1d\xc0"),
        ("3245.234", b"\x061\x84\xb2"),
        ("-3245.234", b"\x06\xce{N"),
        ("9999999999999999.456", b"\x12\x00\x8a\xc7#\x04\x89\xe7\xfd\xe0"),
        ("-999999999999999.456", b"\x10\xf2\x1fILX\x9c\x02 "),
        ("3.123", b"\x04\x0c3"),
    ],
)
def test_simple(value, expected):
    schema = cavro.Schema({
        "type": "bytes",
        "logicalType": "decimal",
        "precision": 20,
        "scale": 3
    })
    val = decimal.Decimal(value)

    encoded = schema.binary_encode(val)
    assert encoded == expected
    decoded = schema.binary_decode(encoded)
    assert decoded == val