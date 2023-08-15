import pytest
import cavro


def test_string_schema():
    schema = cavro.Schema('"string"')
    assert isinstance(schema.type, cavro.StringType)


@pytest.mark.parametrize('encoded,expected', [
    (b'\x00', ''),
    (b'\x02A', 'A'),
    (b'\x04Hi', 'Hi'),
    (b'\x04\xc2\xa3', '£'),
    (b'\x08\xf0\x9f\x98\x80', '😀'),
    (b'\x0eOne\x00Two', 'One\x00Two'),
    (b'\x7aPower\xd9\x84\xd9\x8f\xd9\x84\xd9\x8f\xd8\xb5\xd9\x91\xd8\xa8\xd9'
      b'\x8f\xd9\x84\xd9\x8f\xd9\x84\xd8\xb5\xd9\x91\xd8\xa8\xd9\x8f\xd8'
      b'\xb1\xd8\xb1\xd9\x8b \xe0\xa5\xa3 \xe0\xa5\xa3h \xe0\xa5\xa3 \xe0'
      b'\xa5\xa3\xe5\x86\x97',
      'Powerلُلُصّبُلُلصّبُررً ॣ ॣh ॣ ॣ冗')
])
def test_string_decoding(encoded, expected):
    schema = cavro.Schema('"string"')
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
def test_string_encoding(raw, expected):
    schema = cavro.Schema('"string"')
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
def test_string_json_encoding(raw, expected):
    schema = cavro.Schema('"string"')
    assert schema.json_encode(raw) == expected


@pytest.mark.parametrize('value,expected,coerce', [
    ('', True, True),
    ('🧙🏽‍♀️', True, True),
    (0, False, True),
    (0.1, False, True),
    (b'', False, True),
    ({'a': 'b'}, False, True),
    ([''], False, True),
])
def test_string_can_encode(value, expected, coerce):
    schema = cavro.Schema('"string"')
    assert schema.can_encode(value) == expected
    schema = cavro.Schema('"string"', cavro.Options(coerce_values_to_str=True))
    assert schema.can_encode(value) == coerce


def test_string_encoding_decoding():
    schema = cavro.Schema('"string"')
    encoded = schema.binary_encode('abacus')
    assert schema.binary_decode(encoded) == 'abacus'


def test_fixed_encoding():
    schema = cavro.Schema('{"type": "fixed", "size": 4, "name": "test"}')
    encoded = schema.binary_encode(b'abcd')
    assert encoded == b'abcd'
    assert schema.binary_decode(encoded) == b'abcd'


def test_fixed_encoding_padding():
    schema = cavro.Schema({"type": "fixed", "size": 4, "name": "test"})
    permissive_schema = cavro.Schema({"type": "fixed", "size": 4, "name": "test"}, zero_pad_fixed=True, truncate_fixed=True)
    
    with pytest.raises(ValueError):
        schema.binary_encode(b'ab')
    assert permissive_schema.binary_encode(b'ab') == b'ab\x00\x00'

    with pytest.raises(ValueError):
        schema.binary_encode(b'abcde')
    assert permissive_schema.binary_encode(b'abcde') == b'abcd'
    

def test_fixed_json():
    schema = cavro.Schema({"type": "fixed", "size": 4, "name": "test"})
    permisive_schema = cavro.Schema({"type": "fixed", "size": 4, "name": "test"}, zero_pad_fixed=True, truncate_fixed=True)

    assert schema.json_encode(b'abcd') == '"abcd"'
    with pytest.raises(ValueError):
        schema.json_encode(b'ab')
    assert permisive_schema.json_encode(b'ab') == '"ab\\u0000\\u0000"'

    with pytest.raises(ValueError):
        schema.json_encode(b'abcde')
    assert permisive_schema.json_encode(b'abcde') == '"abcd"'


def test_fixed_read_json():
    schema = cavro.Schema({"type": "fixed", "size": 4, "name": "test"})
    assert schema.json_decode('"abcd"') == b'abcd'
    assert schema.json_decode('"ab\\u0000\\u0000"') == b'ab\x00\x00'
    with pytest.raises(ValueError):
        schema.json_decode('"ab"')