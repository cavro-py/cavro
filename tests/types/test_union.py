import cavro
import pytest

def test_empty_union():
    with pytest.raises(ValueError) as exc:
        cavro.Schema([])
    assert str(exc.value) == 'Unions must contain at least one member type'
    avro_type = cavro.Schema([], permissive=True)
    assert isinstance(avro_type.type, cavro.UnionType)
    assert len(avro_type.type.union_types) == 0

def test_duplicate_item_union():
    with pytest.raises(ValueError) as exc:
        cavro.Schema(['int', 'int'])
    assert str(exc.value) == "Unions may not have more than one member of type 'int'"
    avro_type = cavro.Schema(['int', 'int'], permissive=True)
    assert isinstance(avro_type.type, cavro.UnionType)
    assert len(avro_type.type.union_types) == 2
    assert avro_type.binary_encode(1) == b"\x00\x02"

def test_duplicate_item_in_union_declared_differently():
    with pytest.raises(ValueError) as exc:
        cavro.Schema(['bool', {'type': 'bool'}])
    assert str(exc.value) == "Unions may not have more than one member of type 'bool'"

def test_simple_binary_encoding():
    schema = cavro.Schema(['int', 'long'])
    assert schema.binary_encode(1) == b'\x00\x02'
    assert schema.binary_encode(2**48) == b'\x02\x80\x80\x80\x80\x80\x80\x80\x01'
