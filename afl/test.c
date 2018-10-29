#include <Python.h>

int main() {
    Py_Initialize();
    PyRun_SimpleString("import os, sys\n"
                       "sys.path.insert(0, os.getcwd())\n"
                       "import cavro\n"
                       "sch=cavro.Schema('[\"int\", \"long\", \"float\", \"double\", \"bytes\", \"string\", \"bool\", \"null\"]')\n"
                       "sch.binary_decode(sys.stdin.buffer.read())");
    return 0;
}