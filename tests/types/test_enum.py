import cavro
import pytest

import struct


def test_enum_encoding():
    schema = cavro.Schema({'type': 'enum', 'name': 'A', 'symbols': ['a', 'b', 'c']})
    assert schema.binary_encode('a') == b'\x00'
    assert schema.binary_encode('c') == b'\x04'
    with pytest.raises(KeyError):
         schema.binary_encode('d')


def test_enum_json_encoding():
    schema = cavro.Schema({'type': 'enum', 'name': 'A', 'symbols': ['a', 'b', 'c']})
    schema.json_encode('a') == 'a'
    schema.json_encode('c') == 'c'
    with pytest.raises(KeyError):
        schema.json_encode('d')


def test_enum_blank_symbol():
    schema = cavro.Schema(
        {'type': 'enum', 'name': 'A', 'symbols': ['a', '', 'c']}, 
        cavro.Options(enforce_enum_symbol_name_rules=False)
    )
    assert schema.binary_encode('a') == b'\x00'
    assert schema.binary_encode('') == b'\x02'
    assert schema.binary_encode('c') == b'\x04'


def test_enum_with_duplicate_symbols():
    with pytest.raises(cavro.DuplicateName):
        cavro.Schema({
            'type': 'enum',
            'name': 'A',
            'symbols': ['a', 'b', 'b']
        })


def test_enum_with_invalid_symbol_type():
    with pytest.raises(ValueError):
        cavro.Schema({
            'type': 'enum',
            'name': 'A',
            'symbols': True
        })

@pytest.mark.parametrize('bad_sym,is_uni', [
    ('2', False),
    ('говорить', True),
    ('daß', True),
    ('option٢', True),
    (2, False),
])
def test_enum_with_invalid_symbols(bad_sym, is_uni):
    defn = {
            'type': 'enum',
            'name': 'A',
            'symbols': ['one', bad_sym, 'do']
        }

    with pytest.raises(cavro.InvalidName): # Default is to fail
        cavro.Schema(defn)
    if is_uni:
        schema = cavro.Schema(defn, ascii_name_rules=False)
        assert schema.binary_encode(bad_sym) == b'\x02'
    else:
        with pytest.raises(cavro.InvalidName): # This one also fails extended unicode naming
            cavro.Schema(defn, ascii_name_rules=False)
    
    schema = cavro.Schema(defn, enforce_enum_symbol_name_rules=False)
    assert schema.binary_encode(bad_sym) == b'\x02'


def test_decoding_json():
    schema = cavro.Schema({'type': 'enum', 'name': 'A', 'symbols': ['a', 'b', 'c']})
    assert schema.json_decode('"a"') == 'a'
    assert schema.json_decode('"c"') == 'c'
    with pytest.raises(ValueError):
        schema.json_decode('"d"')