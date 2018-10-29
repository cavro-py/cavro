import cavro
import pytest

import struct


@pytest.mark.parametrize("name, spec", cavro.__tests.items())
def test_c_test(name, spec):
    fn = spec[0]
    args = spec[1:]
    fn(*args)