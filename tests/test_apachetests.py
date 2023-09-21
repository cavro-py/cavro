import json
from pathlib import Path

import pytest

import cavro

DATA_DIR = Path(__file__).parent / 'data'

WEATHER_SCHEMA = '{"name":"test.Weather","type":"record","fields":[{"name":"station","type":"string"},{"name":"time","type":"long"},{"name":"temp","type":"int"}]}'

EXPECTED_FILE = DATA_DIR / 'weather.json'

WEATHER_EXTS = [".avro"]
if cavro.HAVE_SNAPPY:
    WEATHER_EXTS.append("-snappy.avro")

@pytest.mark.parametrize('ext', WEATHER_EXTS)
def test_weather(ext):
    container = cavro.ContainerReader((DATA_DIR / f'weather{ext}').open('rb'))
    schema = container.schema
    assert schema.canonical_form == WEATHER_SCHEMA
    records = list(schema.json_encode(r) for r in container)
    expected = EXPECTED_FILE.read_text().splitlines()
    assert records == expected
