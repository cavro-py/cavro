from pathlib import Path
import cavro

DATA_DIR = Path(__file__).parent / 'data'

WEATHER_SCHEMA = '{"name":"test.Weather","type":"record","fields":[{"name":"station","type":"string"},{"name":"time","type":"long"},{"name":"temp","type":"int"}]}'

def test_weather():
    exts = [".avro", "-snappy.avro"]
    records = {}
    for ext in exts:
        container = cavro.Container((DATA_DIR / f'weather{ext}').open('rb'))
        schema = container.schema
        assert schema.canonical_form == WEATHER_SCHEMA
        records[ext] = list({schema.json_encode(r) for r in container})
    baseline = list(records.values())[0]
    for ext, record in records.items():
        assert record == baseline

def test_weather_sorted():
    container = cavro.Container(DATA_DIR / f'weather-sorted.avro')
