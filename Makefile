test: cavro.cpython-36m-darwin.so
	PYTHONPATH=. pytest -svx

perf: cavro.cpython-36m-darwin.so
	PYTHONPATH=. python perf.py

fuzz: cavro.cpython-36m-darwin.so
	(cd fuzz && PYTHONPATH=.. python values.py)

cavro.pyx: src/* src/tests/*
	touch cavro.pyx

cavro.cpython-36m-darwin.so: cavro.pyx
	python setup.py build_ext --inplace

clean:
	rm -rf build
	rm -rf afl/a.out*
	rm afl/cavro*.so
	rm cavro*.so

.PHONY: test clean