import cavro


SCHEMA = [
    'null',
    'bool',
    'int',
    'long',
    'float',
    'double',
    'bytes',
    'string',
    {'type': 'fixed', 'size': 2, 'name': 'Fixed'},
    {'type': 'enum', 'name': 'Enum', 'symbols': ['A', '', 'C']},
    {'type': 'array', 'items': 'string'},
    {'type': 'map', 'values': 'long'},
    {'type': 'record', 'name': 'Record', 'fields':[
        {'name': 'int', 'type': 'int'},
        {'name': 'bool', 'type': 'bool'},
        {'name': 'string', 'type': 'string'},
    ]},
]


def main():
    schema = cavro.Schema(SCHEMA)

    for i, value in enumerate([
        None,
        False,
        1,
        1.1,
        'abc',
        ['a', 'b', 'c'],
        {'a': 1, 'b': 2},
        {'int': 100, 'bool': False, 'string': 'foobar'}
    ]):
        with open(f'inputs/{i+1}', 'wb') as fh:
            fh.write(schema.binary_encode(value))


if __name__ == '__main__':
    main()