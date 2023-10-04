from collections import defaultdict, namedtuple
import os
import json
import random
import time
import numpy
from benchmark import simple, many_numbers, complex, pypifile, promotion

import github
import pygit2
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


def run_benchmark(test_classes, methods, num, mul, fail):
    results = defaultdict(lambda: defaultdict(set))
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
    print(f" Running {len(test_methods)} tests ".center(60, '='))
    for tester, name, fn in test_methods:
        results[tester.NAME][name].add(run_test(tester, name, fn, fail))
    print("".center(60, "="))
    return interpret_raw_results(results)


def summarize(vals):
    a = numpy.array(list(vals))
    return a.min(), a.std()


Result = namedtuple("Result", ['min', 'std', 'normalized', 'timings'])
def interpret_raw_results(results):
    test_results = defaultdict(dict)
    for test, lib_results in results.items():
        avro_time, _ = summarize(lib_results['avro'])
        for library, results in lib_results.items():
            results = {r for r in results if r is not None}
            if results:
                min_val, std_val = summarize(results)
                result = Result(min_val, std_val, min_val/avro_time, tuple(results))
                test_results[test][library] = result._asdict()
    return test_results


def print_results(results):
    print("Benchmark results")
    for test, test_results in results.items():
        print(f"\x1b[1m{test}:\x1b[0m")
        for library, result in sorted(test_results.items()):
            norm_speed = 1/result['normalized']
            print(f"\t\x1b[1;1m{library}: {norm_speed:.2f}x\x1b[0m faster")


def _make_blob(repo, data):
    data_str = json.dumps(data, indent=2)
    blob_ref = repo.create_blob(data_str)
    return blob_ref


def _make_gh_blob(repo, data):
    data_str = json.dumps(data, indent=2)
    blob = repo.create_git_blob(data_str, 'utf-8')
    return blob.sha


def store_results(results):
    results['now'] = time.time()
    repo = pygit2.Repository('.')
    for filepath, status in repo.status().items():
        # This is a bad way of checking flags, but seems sufficient for now..
        if status not in (pygit2.GIT_STATUS_CURRENT, pygit2.GIT_STATUS_IGNORED):
            print(f"Working directory not clean: {filepath}: {status}, refusing to store results")
            return
    commit_hash = repo.head.target
    ref_name = f'refs/perf/{commit_hash}'
    if 'GITHUB_TOKEN' in os.environ:
        print("Storing results in github repo")
        g = github.Github(os.environ['GITHUB_TOKEN'])
        g.FIX_REPO_GET_GIT_REF = False
        gh_repo = g.get_user('stestagg').get_repo('cavro')
        try:
            existing_ref = gh_repo.get_git_ref(ref_name)
        except github.UnknownObjectException:
            gh_repo.create_git_ref(ref_name, _make_gh_blob(gh_repo, results))
        else:
            results['previous'] = existing_ref.object.sha
            existing_ref.edit(_make_gh_blob(gh_repo, results))
    else:
        print("Storing results in local repo")
        try:
            existing_ref = repo.references[ref_name]
        except KeyError:
            repo.create_reference(ref_name, _make_blob(repo, results))
        else:
            results['previous'] = existing_ref.target.hex
            existing_ref.set_target(_make_blob(repo, results))


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


@click.command()
@click.option('--method', '-m', multiple=True, help="Run only the specified method(s)")
@click.option('--test', '-t', multiple=True, help="Run only the specified test(s)")
@click.option('--no-store', '-x', is_flag=True, help="Don't store results", default=False)
@click.option('--num', '-n', type=int, help="Number of times to run each test", default=None)
@click.option('--mul', type=float, help="Ask test runners to multiply their runtime by this factor", default=1.)
@click.option('--fail', is_flag=True, help="Fail on first error", default=False)
def main(method, test, no_store, num, mul, fail):
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

    all_results = run_benchmark(test_classes, method, num, mul, fail)
    print_results(all_results)
    if not no_store:
        store_results(all_results)


if __name__ == '__main__':
    main()