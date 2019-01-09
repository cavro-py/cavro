from collections import defaultdict, namedtuple
import os
import json
import random
import time
import numpy
from benchmark.bulk import Bulk


def run_test(tester, name, fn):
    label = f'| {tester.NAME} {name}: '
    print(label, end='', flush=True)
    before = time.perf_counter()
    fn()
    after = time.perf_counter()
    taken = after - before
    rest = "%.2fs" % taken
    print((rest).ljust(59 - len(label)) + "|")
    return taken


NUM_RUNS = 2
METHODS = ['avro', 'cavro', 'fastavro']
def run_benchmark(test_classes):
    results = defaultdict(lambda: defaultdict(set))
    testers = [t() for t in test_classes]
    methods = [(t, n, getattr(t, n)) for t in testers for n in METHODS]
    warmups = methods
    tests = methods * NUM_RUNS
    random.shuffle(tests)
    print(f" {len(warmups)} Warmups ".center(60, '='))
    for tester, name, fn in warmups:
        run_test(tester, name, fn)
    print(f" Running {len(tests)} tests ".center(60, '='))
    for tester, name, fn in tests:
        results[tester.NAME][name].add(run_test(tester, name, fn))
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
            min_val, std_val = summarize(results)
            result = Result(min_val, std_val, min_val/avro_time, tuple(results))
            test_results[test][library] = result._asdict()
    return test_results

def print_results(results):
    print("Benchmark results")
    for test, test_results in results.items():
        print(f"\x1b[1m{test}:\x1b[0m")
        for library, result in sorted(test_results.items()):
            norm_speed = result['normalized']
            color = 1 if norm_speed == 1 else 31 if norm_speed > 1 else 32
            print(f"\t\x1b[{color};1m{library}: {norm_speed:.2f}x\x1b[0m")

def store_results(results):
    from github import Github
    g = Github(os.environ['GITHUB_TOKEN'])
    results_str = json.dumps(results, indent=2)
    #repo = g.get_user('stestagg').get_repo('cavro')
    #master = repo.get_git_ref('heads/master')
    #blob = repo.create_git_blob(results_str, 'utf-8')
    #import ipdb; ipdb.set_trace()



def main():
    all_results = run_benchmark([Bulk])
    print_results(all_results)
    if 'GITHUB_TOKEN' in os.environ:
        store_results(all_results)


if __name__ == '__main__':
    main()