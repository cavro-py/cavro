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
    schema = cavro.Schema(schema_text, permissive=True)
    assert schema.canonical_form == canonical
    assert schema.fingerprint().hexdigest() == fingerprint
