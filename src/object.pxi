
OBJECT_SCHEMA = {
    "type": "record",
    "name": "org.apache.avro.file.Header",
    "fields" : [
       {"name": "magic", "type": {"type": "fixed", "name": "Magic", "size": 4}},
       {"name": "meta", "type": {"type": "map", "values": "bytes"}},
       {"name": "sync", "type": {"type": "fixed", "name": "Sync", "size": 16}},
    ]
}

def read_obj_file(filename):
    with open(filename, 'rb') as stream:
        yield from read_obj(stream)

def read_obj(stream):
    