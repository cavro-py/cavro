from collections import defaultdict
import time
from functools import wraps
import random
from time import perf_counter


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