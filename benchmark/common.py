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

