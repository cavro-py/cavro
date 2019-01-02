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
    schema = cavro.Schema('"bytes"')
    assert schema.binary_encode(raw) == expected


@pytest.mark.parametrize('raw,expected', [
    ('', '""'),
    ('A', '"A"'),
    ('Hi', '"Hi"'),
    ('£', '"\\u00a3"'),
    ('"', '"\\""'),
    ('😀', '"\\ud83d\\ude00"'),
    ('One\x00Two', '"One\\u0000Two"'),
    ('Powerلُلُصّبُلُلصّبُررً ॣ ॣh ॣ ॣ冗',
     '"Power\\u0644\\u064f\\u0644\\u064f\\u0635\\u0651\\u0628\\u064f\\u0644'
     '\\u064f\\u0644\\u0635\\u0651\\u0628\\u064f\\u0631\\u0631\\u064b \\u0963 '
     '\\u0963h \\u0963 \\u0963\\u5197"'
    ),
])
def test_bytes_json_encoding(raw, expected):
    schema = cavro.Schema('"bytes"')
    assert schema.json_encode(raw) == expected


@pytest.mark.parametrize('value,expected,permissive', [
    (b'', True, True),
    (b'Hi', True, True),
    ('🧙🏽‍♀️', False, True),
    (0, False, False),
    (0.1, False, False),
    ({'a': 'b'}, False, False),
    ([''], False, False),
])
def test_bytes_can_encode(value, expected, permissive):
    schema = cavro.Schema('"bytes"')
    assert schema.can_encode(value) == expected
    schema = cavro.Schema('"bytes"', permissive=True)
    assert schema.can_encode(value) == permissive


def test_bytes_encoding_decoding():
    schema = cavro.Schema('"bytes"')
    encoded = schema.binary_encode(b'abacus')
    assert schema.binary_decode(encoded) == b'abacus'
