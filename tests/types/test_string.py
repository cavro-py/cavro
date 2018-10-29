import cavro


def test_string_encoding_decoding():
    schema = cavro.Schema('"string"')
    encoded = schema.binary_encode('abacus')
    assert schema.binary_decode(encoded) == 'abacus'