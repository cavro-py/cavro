import cavro


def test_array_binary_encoding():
    schema = cavro.Schema({'type': 'array', 'items': 'int'})
    assert isinstance(schema.type, cavro.ArrayType)
    encoded = schema.binary_encode([1,2,3])
    assert encoded == b'\x06\x02\x04\x06\x00'


def test_array_json_encoding():
    schema = cavro.Schema({'type': 'array', 'items': 'int'})
    assert isinstance(schema.type, cavro.ArrayType)
    encoded = schema.json_encode([1,2,3])
    assert encoded == '[1, 2, 3]'
    encoded = schema.json_encode([])
    assert encoded == '[]'


def test_array_json_decoding():
    schema = cavro.Schema({'type': 'array', 'items': 'int'})
    assert isinstance(schema.type, cavro.ArrayType)
    decoded = schema.json_decode('[1, 2, 3]')
    assert decoded == [1,2,3]
    decoded = schema.json_decode('[]')
    assert decoded == []