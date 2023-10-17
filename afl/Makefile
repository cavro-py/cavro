test: test.o cavro.o
	afl-gcc-fast -o test test.o cavro.o $$(python3-config --ldflags --embed)

test.o: test.c cavro.h
	afl-gcc-fast -c test.c -o test.o $$(python3-config --cflags --embed)

cavro.o: ../cavro.c
	afl-gcc-fast -c ../cavro.c -o cavro.o $$(python3-config --cflags --embed)


cavro-san.o: ../cavro.c
	#AFL_USE_ASAN=1 AFL_USE_UBSAN=1 AFL_USE_CFISAN=1 afl-gcc-fast -c ../cavro.c -o cavro-san.o $$(python3-config --cflags --embed)
	AFL_USE_ASAN=1 AFL_USE_UBSAN=1 afl-gcc-fast -c ../cavro.c -o cavro-san.o $$(python3-config --cflags --embed)

test-san.o: test.c cavro.h
	#AFL_USE_ASAN=1 AFL_USE_UBSAN=1 AFL_USE_CFISAN=1 afl-gcc-fast -c test.c -o test-san.o $$(python3-config --cflags --embed)
	AFL_USE_ASAN=1 AFL_USE_UBSAN=1 afl-gcc-fast -c test.c -o test-san.o $$(python3-config --cflags --embed)

test-san: test-san.o cavro-san.o
	#AFL_USE_ASAN=1 AFL_USE_UBSAN=1 AFL_USE_CFISAN=1 afl-gcc-fast -o test-san test-san.o cavro-san.o $$(python3-config --ldflags --embed)
	AFL_USE_ASAN=1 AFL_USE_UBSAN=1 afl-gcc-fast -o test-san test-san.o cavro-san.o $$(python3-config --ldflags --embed)