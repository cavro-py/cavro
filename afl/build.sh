#!/bin/bash

(
    cd ..
    env CC=afl-clang CFLAGS='-mbmi -mbmi2 -Wno-nullability-completeness -Wno-unused-function' cythonize -3 -i cavro.pyx
    cp cavro.cpython-36m-darwin.so afl/
)

afl-clang -I/Users/stephenstagg/.pyenv/versions/3.6.4/include/python3.6m \
     -I/Users/stephenstagg/.pyenv/versions/3.6.4/include/python3.6m \
     -Wno-unused-result -Wsign-compare -Wunreachable-code -DNDEBUG -g \
     -fwrapv -O3 -Wall -Wstrict-prototypes \
     -I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.13.sdk/usr/include -I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.13.sdk/usr/include\
     -L/Users/stephenstagg/.pyenv/versions/3.6.4/lib/python3.6/config-3.6m-darwin\
     -lpython3.6m -ldl -framework CoreFoundation -Wl,-stack_size,1000000 -framework CoreFoundation test.c