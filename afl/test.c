#include <Python.h>

#define MULTILINE(...) #__VA_ARGS__

int main() {
    Py_Initialize();
    PyRun_SimpleString("import os, sys\n"
                       "sys.path.insert(0, os.getcwd())\n"
                       "import cavro\n"
                       "sch=cavro.Schema("
                       MULTILINE(
                            [
                                'null',
                                'bool',
                                'int',
                                'long',
                                'float',
                                'double',
                                'bytes',
                                'string',
                                {'type': 'fixed', 'size': 2, 'name': 'Fixed'},
                                {'type': 'enum', 'name': 'Enum', 'symbols': ['A', '', 'C']},
                                {'type': 'array', 'items': 'string'},
                                {'type': 'map', 'values': 'long'},
                                {'type': 'record', 'name': 'Record', 'fields':[
                                    {'name': 'int', 'type': 'int'},
                                    {'name': 'bool', 'type': 'bool'},
                                    {'name': 'string', 'type': 'string'},
                                ]},
                            ]
                        )
                       ")\n"
                       "sch.binary_decode(sys.stdin.buffer.read())");
    return 0;
}