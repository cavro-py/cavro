import json

import avro.io
import fastavro
import cavro
import numpy.random
from io import BytesIO

SCHEMA = """{
    "type": "array",
    "items": "long"
}"""


class ManyNumbersBase:
    NUM_RUNS = 3

    def __init__(self):
        self.raw_values = [int(i) for i in numpy.random.randint((2**63)-1, size=100_000)]


class ManyNumbersDecode(ManyNumbersBase):

    """
    Given a large, single array of `long` values encoded in the avro binary format,
    measure the time taken to decode them into python ints.
    """

    NUM_RUNS = 3
    NAME = "many_numbers_decode"

    def __init__(self):
        super().__init__()
        schema = cavro.Schema(SCHEMA)
        self.value = schema.binary_encode(self.raw_values)

    def avro(self):
        schema = avro.schema.Parse(SCHEMA)
        reader = avro.io.DatumReader(schema)
        value_buf = BytesIO(self.value)
        decoder = avro.io.BinaryDecoder(value_buf)
        decoded = reader.read(decoder)

    def fastavro(self):
        schema = fastavro.schema.parse_schema(json.loads(SCHEMA))
        value_buf = BytesIO(self.value)
        decoded = fastavro.schemaless_reader(value_buf, schema)

    def cavro(self):
        schema = cavro.Schema(SCHEMA)
        decoded = schema.binary_decode(self.value)


class ManyNumbersEncode(ManyNumbersBase):

    """
    Given a large, single array of `long` values,
    measure the time taken to encode them in the avro binary format
    """

    NAME = "many_numbers_encode"

    def __init__(self):
        super().__init__()
        self.values = self.raw_values

    def avro(self):
        schema = avro.schema.Parse(SCHEMA)
        writer = avro.io.DatumWriter(schema)
        output_buf = BytesIO()
        encoder = avro.io.BinaryEncoder(output_buf)
        encoded = writer.write(self.values, encoder)

    def fastavro(self):
        schema = fastavro.schema.parse_schema(json.loads(SCHEMA))
        output_buf = BytesIO()
        fastavro.schemaless_writer(output_buf, schema, self.values)

    def cavro(self):
        schema = cavro.Schema(SCHEMA)
        encoded = schema.binary_encode(self.values)
