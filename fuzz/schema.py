import json
import sys

from numpy import random
import cavro

from rand import percent, weighted, make_name


def make_simple(name):
    def maker(energy):
        if percent(70):
            return name
        return {"type": name}
    return maker


make_null = make_simple('null')
make_bool = make_simple('bool')
make_int = make_simple('int')
make_long = make_simple('long')
make_float = make_simple('float')
make_double = make_simple('double')
make_bytes = make_simple('bytes')
make_string = make_simple('string')


def make_ns():
    val = {
        'name': make_name(),
    }
    if percent(40):
        val['namespace'] = ".".join([make_name() for _ in range(random.randint(1, 5))])
    if percent(10):
        val['namespace'] = make_name(random.randint(10, 150))
    if percent(20):
        val['aliases'] = [make_name() for _ in range(random.randint(0, 7))]
    return val


def make_fixed(energy):
    return {"type": "fixed", "size": random.randint(0, 40), "name": make_name()}


def make_field(energy):
    val = {
        'name': make_name(),
        'type': make_type(energy - 1),
    }
    if percent(20):
        val['aliases'] = [make_name() for _ in range(random.randint(0, 7))]
    if percent(10):
        val['order'] = weighted({'ascending': 1, 'descending': 2, 'ignore': 1})
    if percent(40):
        val['doc'] = make_name(100)
    return val


def make_record(energy):
    val = make_ns()
    val['type'] = 'record'
    val['fields'] = [make_field(energy) for _ in range(random.randint(0, energy*2))]
    return val


def make_enum(energy):
    val = make_ns()
    val['type'] = 'enum'
    num_syms = max(2, energy * 2)
    val['symbols'] = [make_name() for _ in range(random.randint(1, num_syms))]
    return val


def make_array(energy):
    return {'type': 'array', 'items': make_type(energy - 1)}


def make_map(energy):
    return {"type": "map", "values": make_type(energy - 1)}


def make_union(energy):
    bad = {make_union}
    num_types = max(2, energy * 1)
    union_def = []
    for _ in range(random.randint(1, num_types)):
        maker = choose_type(energy - 1, without=bad)
        if maker not in [make_fixed, make_enum, make_record]:
            bad.add(maker)
        union_def.append(maker(energy-1))
    return union_def

def choose_type(energy, without=frozenset()):
    makers = {
        make_null: 1,
        make_bool: 2,
        make_int: 2,
        make_long: 2,
        make_float: 2,
        make_double: 2,
        make_bytes: 3,
        make_string: 3,
        make_fixed: 1,
        make_enum: 4
    }
    if energy:
        makers.update({
            make_record: energy * 2.5,
            make_array: energy * 1.5,
            make_map: energy * 1.5,
            make_union: energy * 1.5
        })
    for w in without:
        if w in makers:
            del makers[w]

    return weighted(makers)


def make_type(energy, without=frozenset()):
    return choose_type(energy, without)(energy)


def make_schema_json(energy=10):
    return json.dumps(make_type(energy))


def main():
    for i in range(100):
        schema_json = make_schema_json(5)
        try:
            sch = cavro.Schema(schema_json)
        except:
            print(schema_json)
            raise
        print(sch)


if __name__ == '__main__':
    sys.exit(main())