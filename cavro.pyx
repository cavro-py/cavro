
cimport cython
from cpython.object cimport Py_SIZE
from libc.stdint cimport *
from libc.string cimport memcmp

from cpython cimport array
import array

from libc.string cimport memcpy

ctypedef bint bool


__tests = {}
def _tests(fn):
    def add(test, *args):
        name = test.__name__
        if args:
            name += '-' + ('-'.join(str(a) for a in args))
        __tests[name] = (test, ) + args
    fn(add)
    return _tests

__perf_tests = {}
def _perf(fn):
    def add(test, *args):
        name = test.__name__
        if args:
            name += '-' + ('-'.join(str(a) for a in args))
        __perf_tests[name] = (test, ) + args
    fn(add)
    return _perf


include "src/io.pxi"
include "src/buffer.pxi"
include "src/zigzag.pxi"

include "src/tests/test_zigzag.pxi"
include "src/tests/test_buffer.pxi"
include "src/tests/test_perf.pxi"

include "src/array.pxi"
include "src/enum.pxi"
include "src/map.pxi"
include "src/null.pxi"
include "src/numeric_types.pxi"
include "src/record.pxi"
include "src/string_types.pxi"
include "src/union.pxi"

include "src/type.pxi"
include "src/schema.pxi"

include "src/container.pxi"
