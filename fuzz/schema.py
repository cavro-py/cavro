from functools import partial
import json
import sys

from numpy import random
import cavro

from fuzz.rand import percent, weighted, make_name, make_name_ns, make_rand_str

class Context:
    def __init__(self, _created=None, namespace=None, parent_names=frozenset()):
        self.created = set() if _created is None else _created
        self.namespace = namespace
        self.parent_names = parent_names

    def sub(self, namespace, parent_name):
        new_parents = self.parent_names | {parent_name}
        return Context(self.created, namespace, new_parents)

    def for_spec(self, spec):
        if 'name' in spec:
            ns = spec.get('namespace', self.namespace)
            return self.sub(ns, self._get_name(spec))
        return self

    def _get_name(self, spec):
        name = spec['name']
        namespace = spec.get('namespace', self.namespace)
        if '.' in name or namespace is None:
            return name
        return f'{namespace}.{name}'

    def add_name(self, spec):
        full_name = self._get_name(spec)
        self.created.add(full_name)


def make_simple(name):
    def maker(energy, context):
        if percent(70):
            return name
        return {"type": name}
    return maker


make_null = make_simple('null')
make_bool = make_simple('boolean')
make_int = make_simple('int')
make_long = make_simple('long')
make_float = make_simple('float')
make_double = make_simple('double')
make_bytes = make_simple('bytes')
make_string = make_simple('string')


def make_ns():
    val = {
        'name': make_name_ns(),
    }
    if percent(40):
        val['namespace'] = ".".join([make_name() for _ in range(random.randint(1, 5))])
    if percent(10):
        val['namespace'] = make_name(random.randint(10, 150))
    if percent(20):
        val['aliases'] = [make_name() for _ in range(random.randint(0, 7))]
    return val


def make_fixed(energy, context):
    spec = make_ns()
    context.add_name(spec)
    spec['type'] = 'fixed'
    spec['size'] = random.randint(0, 40)
    return spec


def make_field(energy, context):
    val = {
        'name': make_name_ns(),
        'type': make_type(energy - 1, without=set(), context=context),
    }
    if percent(20):
        val['aliases'] = [make_name() for _ in range(random.randint(0, 7))]
    if percent(10):
        val['order'] = weighted({'ascending': 1, 'descending': 2, 'ignore': 1})
    if percent(40):
        val['doc'] = make_rand_str(100)
    return val


def make_record(energy, context):
    val = make_ns()
    context.add_name(val)
    val['type'] = 'record'
    val['fields'] = [make_field(energy, context.for_spec(val)) for _ in range(random.randint(0, energy*2))]
    return val


def make_enum(energy, context):
    val = make_ns()
    context.add_name(val)
    val['type'] = 'enum'
    num_syms = max(2, energy * 2)
    val['symbols'] = [make_name() for _ in range(random.randint(1, num_syms))]
    return val


def make_array(energy, context):
    return {'type': 'array', 'items': make_type(energy - 1, set(), context)}


def make_map(energy, context):
    return {"type": "map", "values": make_type(energy - 1, set(), context)}


def make_union(energy, context):
    bad = {make_union}
    bad.update(set(context.parent_names))
    num_types = max(2, energy * 1)
    union_def = []
    for _ in range(random.randint(1, num_types)):
        maker = choose_type(energy - 1, without=bad, context=context)
        named = maker in [make_fixed, make_enum, make_record]
        if not named:
            bad.add(maker)
        made = maker(energy-1, context)
        union_def.append(made)
        if named:
            name = context._get_name(made)
            bad.add(name)
    return union_def


def make_created(name, energy, context):
    if name in context.parent_names:
        return [name, 'null']
    return name


def choose_type(energy, without=frozenset(), context=None):
    if context is None:
        context = Created()
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
        make_enum: 4,
    }
    previous_budget = 2
    for previous in context.created:
        if previous not in without:
            makers[partial(make_created, previous)] = previous_budget / len(context.created)
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


def make_type(energy, without=frozenset(), context=None):
    if context is None:
        context = Context()
    return choose_type(energy, without, context)(energy, context)


def make_schema_json(energy=10):
    return json.dumps(make_type(energy), indent=2)


def main():
    for i in range(100):
        schema_json = make_schema_json(10)
        try:
            sch = cavro.Schema(schema_json)
        except:
            print(schema_json)
            raise


if __name__ == '__main__':
    sys.exit(main())