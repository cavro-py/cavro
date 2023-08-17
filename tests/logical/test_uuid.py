import cavro
import pytest
from uuid import UUID, uuid4

def test_uuid():
    schema = cavro.Schema({
        "type": "string",
        "logicalType": "uuid"
    })
    val = uuid4()

    encoded = schema.binary_encode(val)
    lenval = chr(len(str(val)) * 2).encode()
    assert encoded == lenval + str(val).encode()
    decoded = schema.binary_decode(encoded)
    assert decoded == val


def test_uuid_fixed():
    schema = cavro.Schema({
        "type": "fixed",
        "name": "uuid",
        "size": 16,
        "logicalType": "uuid"
    })
    val = uuid4()

    encoded = schema.binary_encode(val)
    assert encoded == val.bytes
    decoded = schema.binary_decode(encoded)
    assert decoded == val