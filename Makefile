PYVER=$(shell python3 -c 'import sys;v=sys.version_info;print(f"{v.major}{v.minor}")')
SOFILE=cavro.cpython-$(PYVER)m-darwin.so

test: $(SOFILE)
	PYTHONPATH=. pytest -sv

data-test: $(SOFILE)
	PYTHONPATH=. python3 tmp/read_data.py

benchmark: $(SOFILE)
	PYTHONPATH=. python3 benchmark/main.py

upload_benchmark_docker:
	apk add freetype-dev libpng-dev
	pip3 install --upgrade numpy
	pip3 install jinja2 matplotlib
	git fetch -v origin +refs/perf/\*:refs/perf/\*
	PYTHONPATH=. python3 benchmark/update_docs.py

upload_benchmark:
	PYTHONPATH=. python3 benchmark/update_docs.py


perf: $(SOFILE)
	PYTHONPATH=. python3 perf.py

fuzz: fuzz-values fuzz-container


fuzz-values: $(SOFILE)
	(cd fuzz && PYTHONPATH=.. python3 values.py 100000)

fuzz-container: $(SOFILE)
	(cd fuzz && PYTHONPATH=.. python3 container.py 1000)

cavro.pyx: src/* src/tests/*
	touch cavro.pyx

$(SOFILE): cavro.pyx
	python3 setup.py build_ext --inplace

clean:
	rm -rf build
	rm -rf afl/a.out*
	- rm afl/cavro*.so
	- rm cavro.c
	- rm cavro*.so
	- find ./ -name __pycache__ -exec rm -rf '{}' \;

.PHONY: test clean benchmark fuzz fuzz-container fuzz-values