import pytest
import cavro


def test_bytes_schema():
    schema = cavro.Schema('"bytes"')
    assert isinstance(schema.type, cavro.BytesType)


@pytest.mark.parametrize('encoded,expected', [
    (b'\x00', b''),
    (b'\x02A', b'A'),
    (b'\x04Hi', b'Hi'),
    (b'\x04\xc2\xa3', b'\xc2\xa3'),
    (b'\x08\xf0\x9f\x98\x80', b'\xf0\x9f\x98\x80'),
    (b'\x0eOne\x00Two', b'One\x00Two')
])
def test_bytes_decoding(encoded, expected):
    schema = cavro.Schema('"bytes"')
    assert schema.binary_decode(encoded) == expected


@pytest.mark.parametrize('raw,expected', [
    ('', b'\x00'),
    ('A', b'\x02A'),
    ('Hi', b'\x04Hi'),
    ('£', b'\x04\xc2\xa3'),
    ('😀', b'\x08\xf0\x9f\x98\x80'),
    ('One\x00Two', b'\x0eOne\x00Two'),
    ('Powerلُلُصّبُلُلصّبُررً ॣ ॣh ॣ ॣ冗',
      b'\x7aPower\xd9\x84\xd9\x8f\xd9\x84\xd9\x8f\xd8\xb5\xd9\x91\xd8\xa8\xd9'
      b'\x8f\xd9\x84\xd9\x8f\xd9\x84\xd8\xb5\xd9\x91\xd8\xa8\xd9\x8f\xd8'
      b'\xb1\xd8\xb1\xd9\x8b \xe0\xa5\xa3 \xe0\xa5\xa3h \xe0\xa5\xa3 \xe0'
      b'\xa5\xa3\xe5\x86\x97'
    ),
])
def test_bytes_encoding(raw, expected):
    schema = cavro.Schema('"bytes"', cavro.Options(bytes_codec='utf8'))
    assert schema.binary_encode(raw) == expected


@pytest.mark.parametrize('raw,expected', [
    ('', '""'),
    ('A', '"A"'),
    ('Hi', '"Hi"'),
    ('£'.encode('latin1'), '"\\u00a3"'),
    ('"', '"\\""'),
    ('😀', '"\\u00f0\\u009f\\u0098\\u0080"'),
    ('One\x00Two', '"One\\u0000Two"'),
    ('Powerلُلُصّبُلُلصّبُررً ॣ ॣh ॣ ॣ冗',
      '"Power\\u00d9\\u0084\\u00d9\\u008f\\u00d9\\u0084\\u00d9\\u008f\\u00d8\\u00b5\\u00d9\\u0091\\u00d8\\u00a8\\u00d9'
      '\\u008f\\u00d9\\u0084\\u00d9\\u008f\\u00d9\\u0084\\u00d8\\u00b5\\u00d9\\u0091\\u00d8\\u00a8\\u00d9\\u008f\\u00d8'
      '\\u00b1\\u00d8\\u00b1\\u00d9\\u008b \\u00e0\\u00a5\\u00a3 \\u00e0\\u00a5\\u00a3h \\u00e0\\u00a5\\u00a3 \\u00e0'
      '\\u00a5\\u00a3\\u00e5\\u0086\\u0097"'
    ),
])
def test_bytes_json_encoding(raw, expected):
    schema = cavro.Schema('"bytes"', cavro.Options(bytes_codec='utf8'))
    encoded = schema.json_encode(raw)
    assert encoded == expected


@pytest.mark.parametrize('value,expected,can_encode_utf,can_encode_latin1,coerce,coerce_utf', [
    (b'',         True , True , True , True , True),
    (b'Hi',       True , True , True , True , True),
    ('🧙🏽‍♀️',        False, True , False, False, True),
    (0,           False, False, False, False, True),
    (0.1,         False, False, False, False, True),
    ({'a': 'b'},  False, False, False, False, True),
    ({'🧙🏽‍♀️': 'b'}, False, False, False, False, True),
    ([''],        False, False, False, False, True),
])
def test_bytes_can_encode(value, expected, can_encode_utf, can_encode_latin1, coerce, coerce_utf):
    schema = cavro.Schema('"bytes"')
    schema_encode_utf = cavro.Schema('"bytes"', cavro.Options(bytes_codec='utf-8'))
    schema_encode_latin1 = cavro.Schema('"bytes"', cavro.Options(bytes_codec='latin-1'))
    schema_coerce = cavro.Schema('"bytes"', cavro.Options(coerce_values_to_str=True))
    schema_coerce_utf = cavro.Schema('"bytes"', cavro.Options(coerce_values_to_str=True, bytes_codec='utf-8'))

    for schema, expected in [
        (schema, expected),
        (schema_encode_utf, can_encode_utf),
        (schema_encode_latin1, can_encode_latin1),
        (schema_coerce, coerce),
        (schema_coerce_utf, coerce_utf)
    ]:
        assert schema.can_encode(value) == expected


@pytest.mark.parametrize('value', [
    b'',
    b'abacus',
    '🧙🏽‍♀️'.encode(),
    bytearray(b'Hi')
])
def test_bytes_encoding_decoding(value):
    schema = cavro.Schema('"bytes"')
    encoded = schema.binary_encode(value)
    assert schema.binary_decode(encoded) == bytes(value)


def test_bytes_decoding_json():
    schema = cavro.Schema('"bytes"', cavro.Options(bytes_codec='utf8'))
    assert schema.json_decode('"abacus"') == b'abacus'