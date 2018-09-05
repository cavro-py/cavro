
_tests = {}

def ctest(fn):
    _tests[fn.__name__] = fn
    return fn


include "src/buffer.pxi"
include "src/zigzag.pxi"

include "src/type.pxi"
include "src/schema.pxi"

