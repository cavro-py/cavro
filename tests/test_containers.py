import cavro
import pytest

from pathlib import Path


def test_container_reading():
	here = Path(__file__).parent
	container_file = here / 'data' / 'weather.avro'
	container = cavro.Container(container_file.open('rb'))
	print(container)