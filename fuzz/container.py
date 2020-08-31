import click
import itertools
import tqdm

import io

from fuzz import schema, values
from fuzz.rand import percent, weighted, make_rand_str, randint

import cavro

@click.command()
@click.argument('count', type=int, default=-1)
def main(count):
    if count < 0:
        counter = itertools.count()
    else:
        counter = range(count)
    for it in tqdm.tqdm(counter):
        try:
            tmp = io.BytesIO()
            sch_json = schema.make_schema_json(5)
            sch = cavro.Schema(sch_json)
            
            vals = [values.make_value_for_type(sch.type, 5) for _ in range(randint(0, 2000))]
            with cavro.ContainerWriter(tmp, sch) as writer:
                writer.write_many(vals)

            tmp.seek(0)
            reader = cavro.ContainerReader(tmp)
            decoded = [values.de_record(v) for v in reader]
            expected = [values.de_record(v) for v in vals]

            info = []
            equal = values.almost_equal(decoded, expected, info)

            if not equal:
                print("----------- SCHEMA -------------")
                print(sch_json)
                # print("\n----------- VALUE ---------------")
                # print(value)
                # print("\n----------- DECODED ---------------")
                # print(decoded)
                # print("\n----------- DECODED DATA ---------------")
                # print(de_recorded)
                print("\n----------- INFO ---------------")
                print(info)
                return
        except:
            print(tmp.getvalue())
            raise

if __name__ == '__main__':
    main()