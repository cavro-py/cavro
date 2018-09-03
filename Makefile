test: cavro.cpython-36m-darwin.so
	PYTHONPATH=. pytest -vs

cavro.pyx: src/*
	touch cavro.pyx

cavro.cpython-36m-darwin.so: cavro.pyx
	CFLAGS='-Wno-nullability-completeness -Wno-unused-function' cythonize -3 -i cavro.pyx


.PHONY: test