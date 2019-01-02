
@_tests
def _tests(add):

    @add
    def _test_reader_read_u8():
        buffer = MemoryReader(b'\x01\x02\x03')
        assert buffer.read_u8() == 1
        assert buffer.read_u8() == 2
        assert buffer.read_u8() == 3
        import pytest
        with pytest.raises(ValueError):
            buffer.read_u8()

    @add
    def _test_reader_read_n():
        buffer = MemoryReader(b'abacuscounter1')
        a = bytes(buffer.read_n(6)[:6])
        assert a == b'abacus', a
        b = bytes(buffer.read_n(7)[:7])
        assert b == b'counter', b
        import pytest
        with pytest.raises(ValueError):
            buffer.read_n(2)
