from io import BytesIO
import uuid
import cavro
import pytest

from pathlib import Path


SIMPLE_CONTAINER = b'Obj\x01\x04\x14avro.codec\x08null\x16avro.schema\x0a"int"\x00aaaaaaaaaaaaaaaa\x02\x02\x02aaaaaaaaaaaaaaaa'


def test_simplest_container_invalid_magic():
    container = cavro.ContainerReader(SIMPLE_CONTAINER)
    assert list(container) == [1]


def test_container_invalid_magic():
    bad_container = b"Obj\x02" + SIMPLE_CONTAINER[4:]
    with pytest.raises(ValueError, match="Invalid file header"):
        cavro.ContainerReader(bad_container)


def test_container_invalid_codec():
    bad_container = SIMPLE_CONTAINER.replace(b'null', b'xxxx')
    with pytest.raises(ValueError, match=r"Unsupported codec: 'xxxx'"):
        cavro.ContainerReader(bad_container)


def test_container_reading_from_fileobj():
    here = Path(__file__).parent
    container_file = here / 'data' / 'weather.avro'
    container = cavro.ContainerReader(container_file.open('rb'))
    assert list(container)[2].temp == -11


class FakeUUID:

    HEADER = b'Obj\x01\x04\x16avro.schema\n"int"\x14avro.codec\x08null\x00abcdefghijklmnop'
    bytes = b'abcdefghijklmnop'


def test_writing_empty(monkeypatch):
    monkeypatch.setattr(uuid, 'uuid4', FakeUUID)
    buf = BytesIO()
    sch = cavro.Schema('"int"')
    writer = cavro.ContainerWriter(buf, sch)
    writer.close()
    assert buf.getvalue() == b'Obj\x01\x04\x16avro.schema\n"int"\x14avro.codec\x08null\x00abcdefghijklmnop\x00\x00abcdefghijklmnop'


def test_writing_empty_no_close(monkeypatch):
    monkeypatch.setattr(uuid, 'uuid4', FakeUUID)
    buf = BytesIO()
    sch = cavro.Schema('"int"')
    writer = cavro.ContainerWriter(buf, sch)
    del writer
    assert buf.getvalue() == b'Obj\x01\x04\x16avro.schema\n"int"\x14avro.codec\x08null\x00abcdefghijklmnop\x00\x00abcdefghijklmnop'


def test_writing_one_int(monkeypatch):
    monkeypatch.setattr(uuid, 'uuid4', FakeUUID)
    buf = BytesIO()
    sch = cavro.Schema('"int"')
    writer = cavro.ContainerWriter(buf, sch)
    writer.write_one(1)
    writer.close()
    assert buf.getvalue() == FakeUUID.HEADER + b'\x02\x02\x02' + FakeUUID.bytes


def test_writing_one_int_no_close(monkeypatch):
    monkeypatch.setattr(uuid, 'uuid4', FakeUUID)
    buf = BytesIO()
    sch = cavro.Schema('"int"')
    writer = cavro.ContainerWriter(buf, sch)
    writer.write_one(1)
    assert buf.getvalue() == b''
    del writer
    assert buf.getvalue() == FakeUUID.HEADER + b'\x02\x02\x02' + FakeUUID.bytes


def test_writing_bigger_int(monkeypatch):
    monkeypatch.setattr(uuid, 'uuid4', FakeUUID)
    buf = BytesIO()
    sch = cavro.Schema('"int"')
    writer = cavro.ContainerWriter(buf, sch)
    writer.write_one(64)
    writer.close()
    assert buf.getvalue() == FakeUUID.HEADER + b'\x02\x04\x80\x01' + FakeUUID.bytes


def test_writing_two_ints(monkeypatch):
    monkeypatch.setattr(uuid, 'uuid4', FakeUUID)
    buf = BytesIO()
    sch = cavro.Schema('"int"')
    writer = cavro.ContainerWriter(buf, sch)
    writer.write_one(64)
    writer.write_one(1)
    writer.close()
    assert buf.getvalue() == FakeUUID.HEADER + b'\x04\x06\x80\x01\x02' + FakeUUID.bytes


def test_writing_two_blocks_of_ints(monkeypatch):
    monkeypatch.setattr(uuid, 'uuid4', FakeUUID)
    buf = BytesIO()
    sch = cavro.Schema('"int"')
    writer = cavro.ContainerWriter(buf, sch, max_blocksize=1)
    writer.write_one(64)
    assert buf.getvalue() == b''
    writer.write_one(1)
    assert buf.getvalue() == FakeUUID.HEADER + b'\x02\x04\x80\x01' + FakeUUID.bytes
    writer.close()
    assert buf.getvalue() == FakeUUID.HEADER + b'\x02\x04\x80\x01' + FakeUUID.bytes + b'\x02\x02\x02' + FakeUUID.bytes


def test_cannot_write_after_close():
    buf = BytesIO()
    sch = cavro.Schema('"int"')
    writer = cavro.ContainerWriter(buf, sch)
    writer.write_one(1)
    writer.close()
    with pytest.raises(ValueError):
        writer.write_one(2)


def test_writing_two_ints_context(monkeypatch):
    monkeypatch.setattr(uuid, 'uuid4', FakeUUID)
    buf = BytesIO()
    sch = cavro.Schema('"int"')
    with cavro.ContainerWriter(buf, sch) as writer:
        writer.write_one(64)
        writer.write_one(1)
    assert buf.getvalue() == FakeUUID.HEADER + b'\x04\x06\x80\x01\x02' + FakeUUID.bytes

@pytest.mark.parametrize('source_vals,schema', [
    ([1], '"int"'),
    (["The", "Cat", "Sat", "on", "the", "mat"], '"string"'),
    (["Apples"] * 10_000, '"string"'),
])
def test_round_tripping(source_vals, schema):
    for codec in ['null', 'deflate', 'snappy']:
        buf = BytesIO()
        sch = cavro.Schema(schema)
        with cavro.ContainerWriter(buf, sch, codec) as writer:
            writer.write_many(source_vals)
        buf.seek(0)
        reader = cavro.ContainerReader(buf)
        obs = list(reader)
        assert obs == source_vals