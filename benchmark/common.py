from collections import defaultdict
import time
from functools import wraps
import random
from time import perf_counter

NUM_RUNS = 3
def compare(name, *fns):
    fns = list(fns)
    print(f"------------ {name} -----------")
    for i in range(NUM_RUNS):
        print(f"-- RUN {i} of {NUM_RUNS} --")
        random.shuffle(fns)
        for fn in fns:
            print(f'{fn.__name__}: ', end='', flush=True)
            fn()


def time_it(fn):
    @wraps(fn)
    def wrapper(*a ,**kw):
        before = perf_counter()
        rv = fn(*a, **kw)
        after = perf_counter()
        print(f"{after - before} s")
        return rv
    return wrapper


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
        results[tester.name][name].add(run_test(tester, name, fn))
    print("".center(60, "="))