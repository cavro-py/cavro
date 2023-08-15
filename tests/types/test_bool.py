import cavro
import pytest
import numpy

import struct

FALSEY_VALUES = (None, 0, 0.0, '', [], {}, tuple(), set(), 1e-500)
TRUTHY_VALUES = (
    ' ', 'True', 't', 1, 100, -1, 1.1, 'Yes',
    [True], {True: True}, (True, ), {True}
)
OTHER_OPTIONS = (
    'False', 'No', 'f',
)


def givens(*examples):
    return pytest.mark.parametrize('given', examples)


@givens(False, numpy.False_)
def test_false_encoding(given):
    schema = cavro.Schema('"boolean"')
    assert schema.can_encode(given)
    assert schema.binary_encode(given) == b'\x00'

@givens(True, numpy.True_)
def test_true_encoding(given):
    schema = cavro.Schema('"boolean"')
    assert schema.can_encode(given)
    assert schema.binary_encode(given) == b'\x01'


@givens(*FALSEY_VALUES + TRUTHY_VALUES + OTHER_OPTIONS)
def test_invalid_value_can_encode(given):
    schema = cavro.Schema('"boolean"')
    assert schema.can_encode(given) == False


@givens(*TRUTHY_VALUES)
def test_coerce_true_encoding(given):
    schema = cavro.Schema('"boolean"', cavro.Options(coerce_values_to_boolean=True))
    assert schema.can_encode(given) == True
    assert schema.binary_encode(given) == b'\x01'


@givens(*FALSEY_VALUES)
def test_coerce_false_encoding(given):
    schema = cavro.Schema('"boolean"', cavro.Options(coerce_values_to_boolean=True))
    assert schema.can_encode(given) == True
    assert schema.binary_encode(given) == b'\x00'


@givens(*FALSEY_VALUES)
def test_false_json_encoding(given):
    schema = cavro.Schema('"boolean"')
    coerce_schema = cavro.Schema('"boolean"', cavro.Options(coerce_values_to_boolean=True))
    with pytest.raises(ValueError):
        schema.json_encode(given)
    assert coerce_schema.json_encode(given) == 'false'


@givens(*TRUTHY_VALUES)
def test_true_json_encoding(given):
    schema = cavro.Schema('"boolean"')
    coerce_schema = cavro.Schema('"boolean"', cavro.Options(coerce_values_to_boolean=True))
    with pytest.raises(ValueError):
        schema.json_encode(given)
    assert coerce_schema.json_encode(given) == 'true'


def test_json_decoding():
    schema = cavro.Schema('"boolean"')
    assert schema.json_decode('true') == True
    assert schema.json_decode('false') == False
    with pytest.raises(TypeError):
        schema.json_decode('1')