---
sidebar_position: 1
---

# 1 Minute Introduction to cavro

## Installation

Install cavro using pip:

```bash
$ pip install cavro
```

or

```bash
$ python3 -m pip install cavro
```


## Basic Usage

### Decoding AVRO objects

If you have a schema and an avro object in `bytes`, then decoding it is simple:

```python
import cavro

schema = cavro.Schema('{"type": "int"}')
encoded_avro = b'\x8a1'

decoded = schema.binary_decode(encoded_avro)
assert decoded == 3141
```

### Encoding AVRO objects

Encoding values to avro is the opposite:

```python
import cavro

schema = cavro.Schema('{"type": "int"}')
value = 3141

encoded = schema.binary_encode(value)
assert encoded == b'\x8a1'
```

## Reading & Writing Files

cavro supports reading and writing avro binary content from files, both as raw avro objects, and from the avro object container format.

### Decoding Raw AVRO from a file

If you have a file (or file-like object) containing the avro data, this can be decoded directly.

cavro just reads a single value from the stream, and does not seek, or check if any more objects are on the stream.
Serial reading/writing and checking for extra data can easily be added in the calling code.

```python
import cavro

schema = cavro.Schema('{"type": "long"}')

with open('my-file.bin', 'rb') as fh:
    reader = cavro.FileReader(fh)
    print(schema.binary_read(reader))
```

### Encoding Raw AVRO to a file

```python
import cavro

schema = cavro.Schema({"type": "long"})

with open('my-file.bin', 'wb') as fh:
    writer = cavro.FileWriter(fh)
    schema.binary_write(writer, 3141)
```

### Reading AVRO object container files

Files that are in the [avro object container format](https://avro.apache.org/docs/1.11.1/specification/#object-container-files) can be read directly:

```
import cavro

for obj in cavro.ContainerReader('file.avro'):
    print(obj)
```

### Writing AVRO object container files

To write a container format file:

```
import cavro

schema = cavro.Schema(...)
with cavro.ContainerWriter('file.avro', schema, codec='snappy') as writer:
    writer.write_many(values_to_write)
```

