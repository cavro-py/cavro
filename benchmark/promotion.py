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

WRITER_SCHEMA = open(os.path.join(os.path.dirname(__file__), 'complex_schema.json')).read()
READER_SCHEMA = open(os.path.join(os.path.dirname(__file__), 'complex_schema_read.json')).read()


class SchemaPromotion:
    """
    Measure the time taken to decode 1,000 values, randomly
    generated to match a 70 kb schema, using different reader/writer schemas.
    """

    NUM_RUNS = 3
    NAME = "schema_promotion"

    def __init__(self, mul):
        schema = cavro.Schema(WRITER_SCHEMA)
        self.raw_values = [make_value_for_type(schema.type, 5) for _ in range(int(1000 * mul))]
        self.values = [schema.binary_encode(value) for value in self.raw_values]

    def avro(self):
        reader_schema = avro.schema.parse(READER_SCHEMA)
        writer_schema = avro.schema.parse(WRITER_SCHEMA)
        reader = avro.io.DatumReader(writer_schema, reader_schema)
        for encoded_value in self.values:
            value_buf = BytesIO(encoded_value)
            decoder = avro.io.BinaryDecoder(value_buf)
            decoded = reader.read(decoder)

    def fastavro(self):
        reader_schema = fastavro.schema.parse_schema(json.loads(READER_SCHEMA))
        writer_schema = fastavro.schema.parse_schema(json.loads(WRITER_SCHEMA))
        for encoded_value in self.values:
            value_buf = BytesIO(encoded_value)
            decoded = fastavro.schemaless_reader(
                value_buf, 
                writer_schema=writer_schema, 
                reader_schema=reader_schema
            )


    def cavro(self):
        writer_schema = cavro.Schema(WRITER_SCHEMA)
        reader_schema = cavro.Schema(READER_SCHEMA).reader_for_writer(writer_schema)
        
        for encoded_value in self.values:
            decoded = reader_schema.binary_decode(encoded_value)


class ContainerSchemaPromotion:
    """
    Measure the time taken to decode 1,000 values from an object container,
    randomly generated to match a 70 kb schema, using different reader/writer schemas.
    """

    NUM_RUNS = 3
    NAME = "schema_promotion_container"

    def __init__(self, mul):
        schema = cavro.Schema(WRITER_SCHEMA)
        raw_values = [make_value_for_type(schema.type, 5) for _ in range(int(1000 * mul))]
        self.buf = BytesIO()
        writer = cavro.ContainerWriter(self.buf, schema, max_blocksize=200)
        writer.write_many(raw_values)
        writer.close()
        self.buf.seek(0)

    def avro(self):
        self.buf.seek(0)
        reader_schema = avro.schema.parse(READER_SCHEMA)
        reader = avro.io.DatumReader(reader_schema)
        file_reader = avro.datafile.DataFileReader(self.buf, avro.io.DatumReader())
        for value in file_reader:
            pass

    def fastavro(self):
        self.buf.seek(0)
        reader_schema = fastavro.schema.parse_schema(json.loads(READER_SCHEMA))
        reader = fastavro.reader(self.buf, reader_schema)
        for value in reader:
            pass

    def cavro(self):
        self.buf.seek(0)
        reader_schema = cavro.Schema(READER_SCHEMA)
        reader = cavro.ContainerReader(self.buf, reader_schema)
        for value in reader:
            pass
