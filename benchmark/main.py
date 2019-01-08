from collections import defaultdict
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


NUM_RUNS = 3
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
    interpret_results(results)


def summarize(vals):
    a = numpy.array(list(vals))
    return a.min(), a.std()


def interpret_results(results):
    now = time.time()
    for test, method_results in results.items():
        summaries = {meth: summarize(r) for meth, r in method_results.items()}
        print(summaries)


def main():
    run_benchmark([Bulk])


if __name__ == '__main__':
    main()