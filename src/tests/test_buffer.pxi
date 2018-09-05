
@ctest
def test_reader_read8():
    buffer = MemoryReader(b'\x01\x02\x03')
    assert buffer.read8() == 1
    assert buffer.read8() == 2
    assert buffer.read8() == 3
    import pytest
    with pytest.raises(ValueError):
        buffer.read8()


@ctest
def test_reader_read_to32():
    buffer = MemoryReader(b'\x01\x02\x03\x04\x05\x06')
    val = buffer.read_to32()
    assert ((val & 0xff)) == 1
    assert (((val & 0xff00) >> 8)) == 2
    assert (((val & 0xff0000) >> 16)) == 3
    assert (((val & 0xff000000) >> 24)) == 4
    val = buffer.read_to32()
    assert ((val & 0xff)) == 5
    assert (((val & 0xff00) >> 8)) == 6
    assert (((val & 0xff0000) >> 16)) == 0
    assert (((val & 0xff000000) >> 24)) == 0
    import pytest
    with pytest.raises(ValueError):
        buffer.read_to32()

@ctest
def test_reader_read_n():
    buffer = MemoryReader(b'abacuscounter1')
    assert bytes(buffer.read_n(6)) == b'abacus'
    assert bytes(buffer.read_n(7)) == b'counter'
    import pytest
    with pytest.raises(ValueError):
        buffer.read_n(2)
