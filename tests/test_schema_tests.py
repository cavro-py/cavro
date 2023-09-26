import hashlib
import cavro
import pytest
import re

from pathlib import Path

PATTERN_1 = re.compile(r"""\
<<INPUT ([^\n]+)
<<canonical ([^\n]+)(?:
<<fingerprint ([^\n]+))?
""")

PATTERN_2 = re.compile(r"""\
<<INPUT
(.*?)
INPUT
<<canonical ([^\n]+)(?:
<<fingerprint ([^\n]+))?
""", re.S)

def read_tests():
    tests_file = Path(__file__).parent / 'data' / 'schema-tests.txt'
    with tests_file.open() as fh:
        source = fh.read()
    return PATTERN_1.findall(source) + PATTERN_2.findall(source)

TESTS = read_tests()

@pytest.mark.parametrize("schema_text, canonical, fingerprint", TESTS)
def test_avro_schema_tests(schema_text, canonical, fingerprint):
    schema = cavro.Schema(schema_text, cavro.PERMISSIVE_OPTIONS)
    assert schema.canonical_form == canonical
    for method in ['sha256', 'md5']:
        assert (
            schema.fingerprint(method).hexdigest() 
            == hashlib.new(method, canonical.encode()).hexdigest()
        )
    if fingerprint:
        assert schema.fingerprint().value == int(fingerprint)


def test_wrapping():
    schema = cavro.Schema('[{"type": "int"}, {"type": "string"}]')
    assert schema.schema == ['int', 'string']
    int_schema = schema._wrap_type(schema.type.union_types[0])
    assert int_schema.schema == 'int'
    str_schema = cavro.Schema._wrap_type(schema.type.union_types[1])
    assert str_schema.schema == 'string'