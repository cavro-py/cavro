from collections import defaultdict, namedtuple
from pathlib import Path
import os
import json
import random
import time
import numpy
from benchmark import simple, many_numbers, complex, pypifile, promotion
import cProfile
import click

try:
    import avro_compat
    HAVE_AVRO_COMPAT = True
except ImportError:
    HAVE_AVRO_COMPAT = False
    adapt_compat = None
else:
    from benchmark.adapt import adapt_compat


def run_test(tester, name, fn, fail):
    label = f'| {tester.NAME} {name}: '
    print(label, end='', flush=True)
    try:
        before = time.perf_counter()
        fn()
        after = time.perf_counter()
    except Exception:
        print("FAIL".ljust(59 - len(label)) + "|")
        if fail:
            raise
    else:
        taken = after - before
        rest = "%.2fs" % taken
        print((rest).ljust(59 - len(label)) + "|")
        return taken

METHODS = ['avro', 'cavro', 'fastavro']

if HAVE_AVRO_COMPAT:
    METHODS += ['avro_compat', 'fastavro_compat']


def run_benchmark(test_classes, methods, num, mul, fail, prof):
    results = defaultdict(lambda: defaultdict(list))
    testers = [t(mul) for t in test_classes]
    warmups = []
    test_methods = []
    for tester in testers:
        for method_name in methods:
            test_method = getattr(tester, method_name)
            record = (tester, method_name, test_method)
            warmups.append(record)
            n_runs = tester.NUM_RUNS if num is None else num
            test_methods.extend([record] * n_runs)

    random.shuffle(test_methods)
    print(f" {len(warmups)} Warmups ".center(60, '='))
    for tester, name, fn in warmups:
        run_test(tester, name, fn, False)

    if prof:
        pr = cProfile.Profile()
        pr.enable()

    print(f" Running {len(test_methods)} tests ".center(60, '='))
    for tester, name, fn in test_methods:
        results[tester.NAME][name].append(run_test(tester, name, fn, fail))
    print("".center(60, "="))
    if prof:
        pr.disable()
        pr.print_stats(sort=prof)

    return {k: dict(v) for k, v in results.items()}


def print_results(results):
    print("Benchmark results")
    print(f'Library Versions:')
    for lib, version in results['versions'].items():
        print(f"\t{lib}: \x1b[31;1m{version}\x1b[0m")

    for test, test_results in results['results'].items():
        print(f"\x1b[1m{test}:\x1b[0m")
        for library, results in test_results.items():
            result_str = ', '.join([f'{r:.2f}s' for r in sorted(results)])
            print(f"\t\x1b[1;1m{library}: {result_str}\x1b[0m")


def _make_blob(repo, data):
    data_str = json.dumps(data, indent=2)
    blob_ref = repo.create_blob(data_str)
    return blob_ref


def _make_gh_blob(repo, data):
    data_str = json.dumps(data, indent=2)
    blob = repo.create_git_blob(data_str, 'utf-8')
    return blob.sha


def wrap_results(results):
    out = {}
    out['now'] = time.time()
    out['versions'] = {}
    for lib in libs:
        mod = __import__(lib)
        out['versions'][lib] = mod.__version__
    out['results'] = results
    return out

ALL_TEST_CLASSES = [
    many_numbers.ManyNumbersEncode,
    many_numbers.ManyNumbersDecode,
    complex.ComplexSchema,
    pypifile.PypiFile,
    simple.SimpleRecordEncode,
    simple.SimpleRecordEncodeDict,
    simple.SimpleRecordDecode,
    simple.SimpleRecordDecodeDict,
    promotion.SchemaPromotion,
    promotion.ContainerSchemaPromotion,
]
libs = ['avro', 'cavro', 'fastavro']
if HAVE_AVRO_COMPAT:
    libs += ['avro_compat']


@click.command()
@click.option('--method', '-m', multiple=True, help="Run only the specified method(s)")
@click.option('--test', '-t', multiple=True, help="Run only the specified test(s)")
@click.option('--num', '-n', type=int, help="Number of times to run each test", default=None)
@click.option('--mul', type=float, help="Ask test runners to multiply their runtime by this factor", default=1.)
@click.option('--fail', is_flag=True, help="Fail on first error", default=False)
@click.option('--prof', help="Profile with specified sort", default=None)
@click.option('--output', '-o', help="Write results to file", type=click.Path(dir_okay=False, writable=True, path_type=Path), default=None)
def main(method, test, num, mul, fail, prof, output):
    if test:
        test_classes = [t for t in ALL_TEST_CLASSES if t.NAME in test]
    else:
        test_classes = ALL_TEST_CLASSES

    if not method:
        method = METHODS

    if HAVE_AVRO_COMPAT:
        for cls in test_classes:
            for name in ['avro', 'fastavro']:
                meth = getattr(cls, name)
                setattr(cls, f'{name}_compat', adapt_compat(meth))

    all_results = run_benchmark(test_classes, method, num, mul, fail, prof)
    out = wrap_results(all_results)

    if output is not None:
        if output.exists():
            existing_results = json.loads(output.read_text())
        else:
            existing_results = []
        existing_results.append(out)
        output.write_text(json.dumps(existing_results))

    print_results(out)


if __name__ == '__main__':
    main()