import time
import json

import avro.io
import fastavro
import cavro
import numpy.random
from io import BytesIO

SCHEMA = json.dumps({
    'doc': 'A weather reading.',
    'name': 'Weather',
    'namespace': 'test',
    'type': 'record',
    'fields': [
        {'name': 'station', 'type': 'string'},
        {'name': 'time', 'type': 'long'},
        {'name': 'temp', 'type': 'int'},
    ],
})

STATIONS = (
    "BOL", "PIK", "IPW", "BRR", "BBP", "EXT", "FFD", "MAN",
    "DOC", "LDY", "BOH", "ADV", "ABB", "FEA", "LMO", "GQJ",
    "CVT", "ZEP", "HLY", "CAX", "CWL", "LBA",
)

def make_readings(num):
    readings = []
    now = time.time() * 1000
    for _ in range(int(num)):
        readings.append({
            'station': numpy.random.choice(STATIONS),
            'time': int(now - (numpy.random.rand() * 10_000)),
            'temp': int(numpy.random.gamma(7, 4))
        })
    return readings

class SimpleRecordEncodeDict:

    """
    Measure the time taken to encode 100,000 dicts using a simple (3 field)
    record schema.
    """

    NUM_RUNS = 3
    NAME = "simple_record_encode_dict"

    def __init__(self, mul=1):
        self.values = make_readings(100_000 * mul)

    def avro(self):
        schema = avro.schema.parse(SCHEMA)
        writer = avro.io.DatumWriter(schema)
        for value in self.values:
            output_buf = BytesIO()
            encoder = avro.io.BinaryEncoder(output_buf)
            encoded = writer.write(value, encoder)

    def fastavro(self):
        schema = fastavro.schema.parse_schema(json.loads(SCHEMA))
        for value in self.values:
            output_buf = BytesIO()
            fastavro.schemaless_writer(output_buf, schema, value)

    def cavro(self):
        schema = cavro.Schema(SCHEMA)
        for value in self.values:
            encoded = schema.binary_encode(value)


class SimpleRecordEncode(SimpleRecordEncodeDict):

    """
    Measure the time taken to encode 100,000 records using a simple (3 field)
    record schema. This takes advantage of cavro's class-based record types
    """

    NAME = "simple_record_encode"

    def __init__(self, mul=1):
        super().__init__(mul)
        schema = cavro.Schema(SCHEMA)
        # TODO: make this nicer in the API
        record_type = schema.named_types['test.Weather'].record
        self.cavro_values = [(record_type(v)) for v in self.values]

    def cavro(self):
        schema = cavro.Schema(SCHEMA)
        for value in self.cavro_values:
            encoded = schema.binary_encode(value)


class SimpleRecordDecode:

    """
    Measure the time taken to decode 100,000 binary-encoded records using
    the simple schema, to each library's native record format
    """

    NUM_RUNS = 3
    NAME = "simple_record_decode"

    def __init__(self, mul=1):
        raw = make_readings(100_000 * mul)
        schema = cavro.Schema(SCHEMA)
        self.values = [schema.binary_encode(r) for r in raw]

    def avro(self):
        schema = avro.schema.parse(SCHEMA)
        reader = avro.io.DatumReader(schema)
        for value in self.values:
            input_buf = BytesIO(value)
            decoder = avro.io.BinaryDecoder(input_buf)
            decoded = reader.read(decoder)

    def fastavro(self):
        schema = fastavro.schema.parse_schema(json.loads(SCHEMA))
        for value in self.values:
            input_buf = BytesIO(value)
            fastavro.schemaless_reader(input_buf, schema)

    def cavro(self):
        schema = cavro.Schema(SCHEMA)
        for value in self.values:
            decoded = schema.binary_decode(value)


class SimpleRecordDecodeDict(SimpleRecordDecode):

    """
    Measure the time taken to decode 100,000 binary-encoded records using
    the simple schema, to a dict
    """

    NAME = "simple_record_decode_dict"

    def cavro(self):
        schema = cavro.Schema(SCHEMA)
        for value in self.values:
            record = schema.binary_decode(value)
            decoded = record._asdict()