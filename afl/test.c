#include <Python.h>

//#include "../cavro.c"
#include "cavro.h"

__AFL_FUZZ_INIT();

#define MULTILINE(...) #__VA_ARGS__

int main() {
    Py_Initialize();

    PyObject *cavro = PyInit_cavro();
    PyObject *mod = PyModule_New("cavro");
    PyModule_ExecDef(mod, (PyModuleDef*)cavro);

    if (!mod) {
        printf("Failed to find cavro module\n");
        PyErr_Print();
        exit(1);
    }

    #ifdef __AFL_HAVE_MANUAL_CONTROL
    __AFL_INIT();
    #endif

    unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;

    while (__AFL_LOOP(10000)) {

        int len = __AFL_FUZZ_TESTCASE_LEN;  // don't use the macro directly in a
                                            // call!


        PyObject * data = PyBytes_FromStringAndSize((const char *)buf, len);
        
        PyObject * container = __pyx_tp_new_5cavro_ContainerReader((PyTypeObject *)&__pyx_type_5cavro_ContainerReader, NULL, NULL);
        PyObject * init_args = PyTuple_Pack(1, data);
        __pyx_pw_5cavro_15ContainerReader_1__init__(container, init_args, NULL);
        Py_DECREF(data);
        Py_DECREF(init_args);
        
        if(PyErr_Occurred()) {
            printf("Failed to create container\n");
            PyErr_Print();
            exit(1);
        }

        while(1) {
            PyObject * obj = __pyx_pf_5cavro_15ContainerReader_4next_object((struct __pyx_obj_5cavro_ContainerReader*)container);
            if (!obj) {
                if (PyErr_Occurred()) {
                    PyErr_Clear();
                }
                break;
            }
            Py_DECREF(obj);
        }

        Py_DECREF(container);
    }

    return 0;
}