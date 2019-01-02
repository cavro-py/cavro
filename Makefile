test: cavro.cpython-36m-darwin.so
	PYTHONPATH=. pytest -svx

data-test: cavro.cpython-36m-darwin.so
	PYTHONPATH=. python3 tmp/read_data.py

benchmark: cavro.cpython-36m-darwin.so
	PYTHONPATH=. python3 benchmark/bench.py

perf: cavro.cpython-36m-darwin.so
	PYTHONPATH=. python3 perf.py

fuzz: cavro.cpython-36m-darwin.so
	(cd fuzz && PYTHONPATH=.. python3 values.py)

cavro.pyx: src/* src/tests/*
	touch cavro.pyx

cavro.cpython-36m-darwin.so: cavro.pyx
	python3 setup.py build_ext --inplace

clean:
	rm -rf build
	rm -rf afl/a.out*
	- rm afl/cavro*.so
	- rm cavro*.so
	#find ./ -name __pycache__ -exec rm -rf '{}' \;

.PHONY: test clean benchmark