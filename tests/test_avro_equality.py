from io import BytesIO
import datetime
import pytest
import cavro
import avro.io
import avro.schema
import avro.timezones


IS_DODGY_AVRO_VERSION = avro.__version__.rsplit('.', 1)[0] in ('1.12', '1.11')

@pytest.mark.parametrize('schema, value', [
    ('"long"', 1),
    ('"long"', -1),
    ('"long"', 2**32),
    ('"long"', (2**63)-1),
    ('"long"', -(2**63)),
    ('"long"', -2**32),
    ('"int"', 1),
    ('"int"', -1),
    ('"int"', (2**31)-1),
    ('"int"', -(2**31)),
    ('"float"', -(2**31)),
    ('"float"', -(2**31)),
    (
        '{"type": "int", "logicalType": "date"}',
        datetime.date(9999, 12, 31),
    ),
    (
        '{"type": "long", "logicalType": "timestamp-micros"}',
        datetime.datetime(2014, 1, 1, 1, 1, 1, 500, tzinfo=avro.timezones.utc),
    ),
    (
        '{"type": "long", "logicalType": "timestamp-micros"}',
        datetime.datetime(9999, 12, 31, 23, 59, 59, 999999, tzinfo=avro.timezones.utc),
    ),
    (
        '{"type": "long", "logicalType": "timestamp-micros"}',
        
        datetime.datetime(2000, 1, 18, 2, 2, 1, 123499, tzinfo=avro.timezones.tst),
    ),  
    (
        '{"type": "long", "logicalType": "timestamp-millis"}',
        datetime.datetime(9999, 12, 31, 23, 59, 59, 999999, tzinfo=avro.timezones.utc),
    ),
])
def test_encoding(schema, value):
    cavro_schema = cavro.Schema(schema, alternate_timestamp_millis_encoding=IS_DODGY_AVRO_VERSION)
    avro_schema = avro.schema.parse(schema)
    cavro_encoded = cavro_schema.binary_encode(value)

    buf = BytesIO()
    avro_encoder = avro.io.BinaryEncoder(buf)
    avro_writer = avro.io.DatumWriter(avro_schema)
    avro_writer.write(value, avro_encoder)
    avro_encoded = buf.getvalue()

    assert cavro_encoded == avro_encoded


def test_sus_default_value_behaviour():
    reader_src = '''{
        "type": "record",
        "name": "Test",
        "fields": [
            {
                "name": "H",
                "type": "bytes",
                "default": "\u00ff\u00ff"
            }
        ]
    }'''
    writer_src = '''{
        "type": "record",
        "name": "Test",
        "fields": [
            {"name": "A", "type": "int"}
        ]
    }'''
    cavro_default_reader = cavro.Schema(reader_src, record_decodes_to_dict=True)
    cavro_reader = cavro.Schema(reader_src, record_decodes_to_dict=True, bytes_default_value_utf8=True)
    cavro_writer = cavro.Schema(writer_src)
    avro_reader = avro.schema.parse(reader_src)
    avro_writer = avro.schema.parse(writer_src)
    encoded = cavro_writer.binary_encode({"A": 1})
    reader_writer = cavro_reader.reader_for_writer(cavro_writer)
    default_reader_writer = cavro_default_reader.reader_for_writer(cavro_writer)
    avro_buf = BytesIO(encoded)
    avro_decoder = avro.io.BinaryDecoder(avro_buf)
    avro_reader = avro.io.DatumReader(avro_writer, avro_reader)
    avro_decoded = avro_reader.read(avro_decoder)

    # decoded should be {"H": b"\xff\xff"}:
    assert default_reader_writer.binary_decode(encoded) == {'H': b'\xff\xff'}

    if IS_DODGY_AVRO_VERSION:
        # but avro some library versions utf-8 encode default bytes values, so it ends up being...
        assert avro_decoded == {'H': b'\xc3\xbf\xc3\xbf'}
    assert reader_writer.binary_decode(encoded) == {'H': b'\xc3\xbf\xc3\xbf'}

