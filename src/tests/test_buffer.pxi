
@_tests
def _tests(add):

    @add
    def _test_reader_read8():
        buffer = MemoryReader(b'\x01\x02\x03')
        assert buffer.read8() == 1
        assert buffer.read8() == 2
        assert buffer.read8() == 3
        import pytest
        with pytest.raises(ValueError):
            buffer.read8()

    @add
    def _test_reader_read_to32():
        import pytest
        raw = bytes(x for x in range(1, 10))
        for raw_len in range(1, 8):
            src = raw[:raw_len]
            reader = MemoryReader(src)
            raw_val = reader.read_to32()
            val = raw_val
            for i in range(1, min(raw_len, 4)+1):
                assert ((val & 0xff)) == i, f"{hex(raw_val)}: {val & 0xff} != {i}"
                reader.advance(1)
                val >>= 8
            if raw_len < 5:
                with pytest.raises(ValueError):
                    reader.read_to32()
            else:
                rest = raw_len - 4
                val = reader.read_to32()
                for i in src[4:]:
                    assert ((val & 0xff)) == i, f"{src}: {val & 0xff} != {i}"
                    reader.advance(1)
                    val >>= 8
            assert val == 0, f"{hex(raw_val)}: {hex(val)}"

    @add
    def _test_reader_read_to64():
        import pytest
        raw = bytes(x for x in range(1, 30))
        for raw_len in range(1, 16):
            src = raw[:raw_len]
            reader = MemoryReader(src)
            raw_val = reader.read_to64()
            val = raw_val
            for i in range(1, min(raw_len, 8)+1):
                assert ((val & 0xff)) == i, f"{src}: {hex(raw_val)}: {val}: {val & 0xff} != {i}"
                reader.advance(1)
                val >>= 8
            if raw_len < 9:
                with pytest.raises(ValueError):
                    reader.read_to64()
            else:
                rest = raw_len - 8
                raw_val = reader.read_to64()
                val = raw_val
                for i in src[8:]:
                    assert ((val & 0xff)) == i, f"{src}: {hex(raw_val)}: {val & 0xff} != {i}"
                    reader.advance(1)
                    val >>= 8
            assert val == 0, f"{hex(raw_val)}: {hex(val)}"

    @add
    def _test_reader_read_n():
        buffer = MemoryReader(b'abacuscounter1')
        a = bytes(buffer.read_n(6))
        assert a == b'abacus', a
        b = bytes(buffer.read_n(7))
        assert b == b'counter', b
        import pytest
        with pytest.raises(ValueError):
            buffer.read_n(2)
