import pytest

import cavro
from testutil import bytesx

def test_map():
    schema = cavro.Schema({"type": "map", 'values': 'int'})
    assert schema.binary_encode({}) == b'\x00'
    assert schema.binary_encode({'': 0}) == b'\x02\x00\x00\x00'
    assert schema.binary_encode({'A': 1, 'B': 2}) == b'\x04\x02A\x02\x02B\x04\x00'
    assert schema.binary_encode({'A': 1, 'B': 2, 'XX': 99999}) == bytesx("""
        06    // 3 Entries
        02 A  // String 'B'
        02    // Number 1
        02 B  // String 'B'
        04    // Number 2
        04 XX // String 'XX'
        be 9a 0c // Number 99999
        00    // End of map
    """)


def test_map_non_string_keys():
    schema = cavro.Schema({"type": "map", 'values': 'int'})
    with pytest.raises(TypeError) as exc:
        schema.binary_encode({1: 2})
    with pytest.raises(TypeError) as exc:
        schema.binary_encode({('x', ): 2})


def test_map_from_fuzz_1():
    schema = cavro.Schema({"type": "map", "values": [
        {"type": "string"},
        {"name": "A", "type": "record", "fields": [{"name": "a", "type": "long"}]},
        {"type": "map", "values": "float"},
    ]})
    assert schema.binary_encode({'x': {'a': 1}}) == bytesx("""
        02  // 1 map item
        02 x // key = x
        02   // union index 1
        02   // a = 1
        00  // end of map
    """)


def test_map_json_encode():
    schema = cavro.Schema({"type": "map", 'values': 'int'})
    assert schema.json_encode({}) == '{}'
    assert schema.json_encode({'': 0}) == '{"": 0}'
    assert schema.json_encode({'A': 1, 'B': 2}) == '{"A": 1, "B": 2}'
    assert schema.json_encode({'A': 1, 'B': 2, 'XX': 99999}) == '{"A": 1, "B": 2, "XX": 99999}'
    with pytest.raises(TypeError) as exc:
        schema.json_encode({1: 2})
    with pytest.raises(ValueError) as exc:
        schema.json_encode({'A': 'x'})


def test_map_json_decode():
    schema = cavro.Schema({"type": "map", 'values': 'int'})
    assert schema.json_decode('{}') == {}
    assert schema.json_decode('{"": 0}') == {'': 0}
    assert schema.json_decode('{"A": 1, "B": 2}') == {'A': 1, 'B': 2}
    assert schema.json_decode('{"A": 1, "B": 2, "XX": 99999}') == {'A': 1, 'B': 2, 'XX': 99999}
    with pytest.raises(ValueError) as exc:
        schema.json_decode('{"A": "x"}')