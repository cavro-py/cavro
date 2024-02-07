import cavro
import pytest
import gzip
from io import BytesIO


import cavro
import pytest
import gzip
from io import BytesIO


def test_gzip_str_simple():
    schema = cavro.Schema({
        "type": "bytes",
        "logicalType": "gzip-str"
    })
    val = 'test gzip string'

    encoded = schema.binary_encode(val)
 
    decoded = schema.binary_decode(encoded)
    assert decoded == val


def test_gzip_str_empty():
    schema = cavro.Schema({
        "type": "bytes",
        "logicalType": "gzip-str"
    })
    val = ''

    encoded = schema.binary_encode(val)
    assert len(encoded) > 0  # Gzip encoding should result in some bytes even for empty string

    decoded = schema.binary_decode(encoded)
    assert decoded == val


def test_gzip_str_long():
    schema = cavro.Schema({
        "type": "bytes",
        "logicalType": "gzip-str"
    })
    val = 'a' * 10000  # Long string consisting of repeating character

    encoded = schema.binary_encode(val)
    assert len(encoded) < len(val)  # The encoded form should be smaller due to compression

    decoded = schema.binary_decode(encoded)
    assert decoded == val