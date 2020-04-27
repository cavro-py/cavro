import cavro
import pytest

from pathlib import Path


SIMPLE_CONTAINER = b'Obj\x01\x04\x14avro.codec\x08null\x16avro.schema\x0a"int"\x00aaaaaaaaaaaaaaaa\x02\x02\x02aaaaaaaaaaaaaaaa'

def test_simplest_container_invalid_magic():
    container = cavro.Container(SIMPLE_CONTAINER)
    assert list(container) == [1]


def test_container_invalid_magic():
    bad_container = b"Obj\x02" + SIMPLE_CONTAINER[4:]
    with pytest.raises(ValueError, match="Invalid file header"):
        cavro.Container(bad_container)

def test_container_invalid_codec():
    bad_container = SIMPLE_CONTAINER.replace(b'null', b'xxxx')
    with pytest.raises(ValueError, match=r"Unsupported codec: 'xxxx'"):
        cavro.Container(bad_container)


def test_container_reading_from_fileobj():
    here = Path(__file__).parent
    container_file = here / 'data' / 'weather.avro'
    print(container_file.read_bytes())
    container = cavro.Container(container_file.open('rb'))
    assert list(container)[2].temp == -11