from itertools import count

import cavro


SCHEMA = [
    'null',
    'boolean',
    'int',
    'long',
    'float',
    'double',
    'bytes',
    'string',
    {'type': 'fixed', 'size': 2, 'name': 'Fixed'},
    {'type': 'enum', 'name': 'Enum', 'symbols': ['A', 'B', 'C']},
    {'type': 'array', 'items': 'string'},
    {'type': 'map', 'values': 'long'},
    {'type': 'record', 'name': 'Record', 'fields':[
        {'name': 'int', 'type': 'int'},
        {'name': 'bool', 'type': 'boolean'},
        {'name': 'string', 'type': 'string'},
    ]},
    {'type': 'record', 'name': 'Rec2', 'fields':[
        {'name': 'rec', 'type': ['null', 'Record']},
        {'name': 'rec2', 'type': ['null', 'Rec2']},
    ]},
]

_INPUT_COUNT = count(1)


def make_input(sch_src, value, codec):

    buf = cavro.MemoryWriter()

    try:
        schema = cavro.Schema(sch_src, parse_json=False)
        with cavro.ContainerWriter(buf, schema, codec=codec) as container:
            container.write_one(value)
    except Exception as e:
        print(e)
        return

    filename = f'inputs/{next(_INPUT_COUNT)}'
    with open(filename, 'wb') as fh:
        fh.write(buf.buffer[:buf.len])
    


def main():
    for i, value in enumerate([
        None,
        False,
        1,
        1.1,
        'abc',
        ['a', 'b', 'c'],
        {'a': 1, 'b': 2},
        {'int': 100, 'bool': False, 'string': 'foobar'},
        {"rec": {"int": 1, "bool": True, "string": "spoon"}, "rec2": {"rec": None, "rec2": {"rec": None, "rec2": None}}},
    ]):
        for codec in ['null', 'bzip2', 'snappy']:
            make_input(SCHEMA, value, codec)
            for subtype in SCHEMA:
                make_input(subtype, value, codec)


if __name__ == '__main__':
    main()