import math
import json
import string
import struct
import sys
import io
from numpy.testing import assert_almost_equal

import cavro

from numpy import random
from fuzz import schema
from fuzz.rand import percent, weighted, make_rand_str, randint


def make_map_val(ty, energy):
    out = {}
    for i in range(randint(0, energy * 2)):
        out[make_rand_str()] = make_value_for_type(ty.value_type, energy-1)
    return out


def make_array_val(ty, energy):
    return [make_value_for_type(ty.item_type, energy-1) for _ in range(randint(0, energy * 2))]


def make_enum_val(ty, energy):
    return random.choice(ty.symbols)


def make_union_val(ty, energy):
    if energy < 2:
        simple = [t for t in ty.union_types if t not in {cavro.RecordType, cavro.ArrayType, cavro.MapType}]
        if simple:
            return make_value_for_type(random.choice(simple), energy-1)
    return make_value_for_type(random.choice(ty.union_types), energy-1)


def make_fixed_val(ty, energy):
    return random.bytes(ty.size)

def make_record_val(ty, energy):
    return ty.record({f.name: make_value_for_type(f.type, energy-1) for f in ty.fields})

def make_value_for_type(ty, energy):
    makers = {
        cavro.NullType: lambda x, e: None,
        cavro.BoolType: lambda x, e: bool(random.choice([False, True])),
        cavro.IntType: lambda x, e: random.randint(-2**30, 2**30),
        cavro.LongType: lambda x, e: random.randint(-2**62, 2**62),
        cavro.FloatType: lambda x, e:  struct.unpack('f', random.bytes(4))[0],
        cavro.DoubleType: lambda x, e:  struct.unpack('d', random.bytes(8))[0],
        cavro.BytesType: lambda x, e: random.bytes(randint(1, e * 3)),
        cavro.StringType: lambda x, e: random.bytes(randint(1, e * 3)).decode('utf-8', 'ignore'),

        cavro.MapType: make_map_val,
        cavro.EnumType: make_enum_val,
        cavro.FixedType: make_fixed_val,
        cavro.UnionType: make_union_val,
        cavro.ArrayType: make_array_val,
        cavro.RecordType: make_record_val,
    }
    return makers[type(ty)](ty, energy)

def de_record(val):
    if isinstance(val, cavro.Record):
        return de_record(val._asdict())
    elif isinstance(val, dict):
        return {k: de_record(v) for k, v in val.items()}
    elif isinstance(val, (list, tuple)):
        return [de_record(v) for v in val]
    elif isinstance(val, float) and math.isnan(val):
        return "NAN"
    elif isinstance(val, float) and math.isinf(val):
        return "INF"
    return val

def almost_equal(a, b, diffval=None):
    if diffval is None:
        diffval = []
    if not isinstance(a, type(b)) and not isinstance(b, type(a)):
        diffval.append(('types', type(a), type(b), a, b))
        return False
    if isinstance(a, list):
        return all(almost_equal(ca, cb, diffval) for ca, cb in zip(a, b))
    if isinstance(a, dict):
        if set(a.keys()) != set(b.keys()):
            diffval.append(('keys', a.keys(), b.keys()))
            return False
        for key in a.keys():
            if not almost_equal(a[key], b[key], diffval):
                diffval.append(('values', a[key], b[key]))
                return False
        return True
    if isinstance(a, float):
        if abs(b-a) > 1e-10 and abs(b-a) > (max(abs(a), abs(b)) * 0.01):
            diffval.append(('float', a, b, abs(b-a)))
            return False
        return True
    else:
        if b != a:
            diffval.append(('value', type(a), a, b))
            return False
        return True


def main():
    num = 0
    while True:
        try:
            tmp = io.StringIO()
            sch_json = schema.make_schema_json(5)
            sch = cavro.Schema(sch_json)
            value = make_value_for_type(sch.type, 5)
            try:
                encoded = sch.binary_encode(value)
            except:
                print(sch_json)
                print(value)
                raise
            try:
                decoded = sch.binary_decode(encoded)
            except:
                print(sch_json, value, encoded)
                raise
            de_recorded = de_record(decoded)
            info = []
            equal = almost_equal(de_recorded, de_record(value), info)
            if not equal:
                print("----------- SCHEMA -------------")
                print(sch_json)
                print("\n----------- VALUE ---------------")
                print(value)
                print("\n----------- DECODED ---------------")
                print(decoded)
                print("\n----------- DECODED DATA ---------------")
                print(de_recorded)
                print("\n----------- INFO ---------------")
                print(info)
                return
        except:
            print(tmp.getvalue())
            raise
        num += 1
        if num % 10_000 == 0:
            print(f"Fuzz count {num}")

if __name__ == '__main__':
    sys.exit(main())