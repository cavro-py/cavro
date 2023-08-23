
cimport cython
from cpython.object cimport Py_SIZE
from libc.stdint cimport *
from libc.string cimport memcmp
import dataclasses
import datetime
import re
import decimal
import enum
from cpython cimport array
from cython cimport bint
import uuid
import math
from types import MappingProxyType
from cpython.dict cimport PyDictProxy_New

from cython.view cimport array as cvarray

from libc.string cimport memcpy

ctypedef bint bool

if cython.sizeof(Py_ssize_t) == 8:
    SSIZE_TYPECODE = b'q'
elif cython.sizeof(Py_ssize_t) == 4:
    SSIZE_TYPECODE = b"l"
else:
    SSIZE_TYPECODE = "UNKNOWN"

# TODO: automate this!
__version__ = "0.2.0"

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

include "src/error.pxi"
include "src/option.pxi"
include "src/io.pxi"
include "src/buffer.pxi"
include "src/zigzag.pxi"
include "src/rabin.pxi"

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

include "src/logical.pxi"

include "src/codec.pxi"
include "src/container.pxi"

include "src/promotions.pxi"

