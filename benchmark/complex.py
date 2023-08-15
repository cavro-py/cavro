import os
import json
import random
from time import perf_counter

from fuzz.values import make_value_for_type

import avro.datafile
import avro.io
import fastavro
import cavro
from io import BytesIO

SCHEMA = open(os.path.join(os.path.dirname(__file__), 'complex_schema.json')).read()

class ComplexSchema:
    """
    Measure the time taken to decode and re-encode 1,000 values, randomly
    generated to match a 70 kb schema
    """

    NUM_RUNS = 3
    NAME = "complex_schema"

    def __init__(self, mul):
        schema = cavro.Schema(SCHEMA)
        raw_values = [make_value_for_type(schema.type, 5) for _ in range(int(1000 * mul))]
        self.values = [schema.binary_encode(value) for value in raw_values]

    def avro(self):
        schema = avro.schema.Parse(SCHEMA)
        reader = avro.io.DatumReader(schema)
        writer = avro.io.DatumWriter(schema)
        for encoded_value in self.values:
            value_buf = BytesIO(encoded_value)
            output_buf = BytesIO()
            decoder = avro.io.BinaryDecoder(value_buf)
            encoder = avro.io.BinaryEncoder(output_buf)
            decoded = reader.read(decoder)
            encoded = writer.write(decoded, encoder)

    def fastavro(self):
        schema = fastavro.schema.parse_schema(json.loads(SCHEMA))
        for encoded_value in self.values:
            value_buf = BytesIO(encoded_value)
            decoded = fastavro.schemaless_reader(value_buf, schema)
            output_buf = BytesIO()
            fastavro.schemaless_writer(output_buf, schema, decoded)

    def cavro(self):
        schema = cavro.Schema(SCHEMA)
        for encoded_value in self.values:
            decoded = schema.binary_decode(encoded_value)
            encoded = schema.binary_encode(decoded)
