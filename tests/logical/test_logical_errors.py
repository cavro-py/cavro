import cavro
import pytest
import decimal


def test_unknown_logical_type():
    """Unknown logical types should be ignored"""
    schema = cavro.Schema({
        "type": "string",
        "logicalType": "unknown",
        "foo": "bar",
    })
    assert schema.binary_encode("hello") == b"\nhello"
    assert schema.binary_decode(b"\nhello") == "hello"


def test_missing_field_logical():
    schema = cavro.Schema({
        "type": "bytes",
        "logicalType": "decimal",
    })
    assert schema.type.value_adapters == ()
    with pytest.raises(ValueError):
        schema.binary_encode(decimal.Decimal("1.0"))
    
    