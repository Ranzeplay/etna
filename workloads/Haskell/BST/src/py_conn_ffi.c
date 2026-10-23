#include "py_conn_ffi.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <Python.h>

static const char *default_python_venv_root = "/Users/jeb/Repos/etna/workloads/Haskell/BST/.py_conn_ffi-venv";

static const char *get_python_venv_root(void) {
    const char *python_venv_root = getenv("PY_CONN_FFI_VENV");
    if (python_venv_root && python_venv_root[0] != '\0') {
        return python_venv_root;
    }
    return default_python_venv_root;
}

static int run_python_script(const char *script_path) {
    printf("=== Running Python script: %s\n", script_path);
    FILE *script_file = fopen(script_path, "r");
    if (!script_file) {
        printf("Failed to open script: %s\n", script_path);
        return -1;
    }

    int result = PyRun_SimpleFileEx(script_file, script_path, 1);
    if (result != 0) {
        printf("Failed to run script: %s\n", script_path);
        PyErr_Print();
        return -1;
    }

    printf("=== Finished running script: %s\n", script_path);

    return 0;
}

static int redirect_python_stdout(void) {
    // In Python 3.13+, PyFile_FromFd was removed. Skip stdout redirection
    // as it's not critical for basic functionality.
    printf("Note: Python 3.13+ detected. Skipping stdout redirection.\n");
    return 0;
}

static void report_python_status(const char *context, PyStatus status) {
    if (PyStatus_IsExit(status)) {
        printf("%s: Python requested exit with code %d\n", context, status.exitcode);
        return;
    }

    if (status.func && status.err_msg) {
        printf("%s: %s in %s\n", context, status.err_msg, status.func);
    } else if (status.err_msg) {
        printf("%s: %s\n", context, status.err_msg);
    } else if (status.func) {
        printf("%s: failed in %s\n", context, status.func);
    } else {
        printf("%s: unknown Python status error\n", context);
    }
}

PyObject *fuzz_next = NULL;
PyObject *gen_module = NULL;

int setup() {
    FILE *debug_log = freopen("/tmp/py_conn_ffi.log", "a", stdout);
    if (!debug_log) {
        printf("Failed to redirect stdout to py_conn_ffi.log\n");
    } else {
        setvbuf(stdout, NULL, _IONBF, 0);
        printf("=== Redirected stdout to py_conn_ffi.log ===\n");
    }

    FILE *debug_err = freopen("/tmp/py_conn_ffi.log", "a", stderr);
    if (!debug_err) {
        printf("Failed to redirect stderr to py_conn_ffi.log\n");
    } else {
        setvbuf(stderr, NULL, _IONBF, 0);
        printf("=== Redirected stderr to py_conn_ffi.log ===\n");
    }

    PyConfig config;
    PyStatus status;
    PyConfig_InitPythonConfig(&config);

    char python_executable_path[PATH_MAX];
    snprintf(
        python_executable_path,
        sizeof(python_executable_path),
        "%s/bin/python",
        get_python_venv_root()
    );

    wchar_t *python_executable = Py_DecodeLocale(python_executable_path, NULL);
    if (!python_executable) {
        printf("Failed to decode Python executable for isolated venv\n");
        PyConfig_Clear(&config);
        goto error;
    }

    status = PyConfig_SetString(&config, &config.program_name, python_executable);
    if (PyStatus_Exception(status)) {
        printf("Failed to set Python program name to isolated venv interpreter\n");
        PyMem_RawFree(python_executable);
        PyConfig_Clear(&config);
        goto error;
    }

    status = PyConfig_SetString(&config, &config.executable, python_executable);
    PyMem_RawFree(python_executable);
    if (PyStatus_Exception(status)) {
        printf("Failed to set Python executable to isolated venv interpreter\n");
        PyConfig_Clear(&config);
        goto error;
    }

    char *cwd = getcwd(NULL, 0);
    if (cwd) {
        printf("cwd: %s\n", cwd);
    } else {
        printf("Failed to get cwd\n");
    }

    // Initialize Python with default configuration
    status = Py_InitializeFromConfig(&config);
    PyConfig_Clear(&config);
    if (PyStatus_Exception(status) || !Py_IsInitialized()) {
        report_python_status("Failed to initialize Python", status);
        if (cwd) free(cwd);
        return 1;
    }

    if (redirect_python_stdout() != 0) {
        goto error;
    }
    PyRun_SimpleString("print('Hello, World')");

    if (cwd) {
        PyObject *sys_path = PySys_GetObject("path");
        if (!sys_path) {
            printf("Failed to get sys.path\n");
            goto error;
        }

        char venv_site_packages_path[PATH_MAX];
        snprintf(
            venv_site_packages_path,
            sizeof(venv_site_packages_path),
            "%s/lib/python3.14/site-packages",
            get_python_venv_root()
        );

        PyObject *venv_site_packages = PyUnicode_FromString(venv_site_packages_path);
        if (!venv_site_packages || PyList_Insert(sys_path, 0, venv_site_packages) != 0) {
            printf("Failed to update sys.path with isolated venv site-packages\n");
            PyErr_Print();
            Py_XDECREF(venv_site_packages);
            goto error;
        }
        Py_DECREF(venv_site_packages);

        // Also add cwd itself
        PyObject *cwd_py = PyUnicode_FromString(cwd);
        if (!cwd_py || PyList_Insert(sys_path, 0, cwd_py) != 0) {
            printf("Failed to update sys.path with cwd\n");
            PyErr_Print();
            Py_XDECREF(cwd_py);
            goto error;
        }
        Py_DECREF(cwd_py);
    }

    if (run_python_script("/Users/jeb/Repos/etna/workloads/Haskell/BST/gen.py") != 0) {
        goto error;
    }

    gen_module = PyImport_ImportModule("gen");
    if (!gen_module) {
        printf("Failed to import gen module\n");
        PyErr_Print();
        goto error;
    }

    PyObject *gen_fandango_path = PyObject_GetAttrString(gen_module, "fandango_file_path");
    if (!gen_fandango_path) {
        printf("Failed to get fandango_file_path from gen.py\n");
        PyErr_Print();
        goto error;
    }

    const char *gen_fandango_path_utf8 = PyUnicode_AsUTF8(gen_fandango_path);
    if (!gen_fandango_path_utf8) {
        printf("Failed to convert fandango_file_path to UTF-8\n");
        PyErr_Print();
        Py_DECREF(gen_fandango_path);
        goto error;
    }

    printf("gen.py fandango_file_path = %s\n", gen_fandango_path_utf8);
    Py_DECREF(gen_fandango_path);

    fuzz_next = PyObject_GetAttrString(gen_module, "fuzz_next");
    if (!fuzz_next || !PyCallable_Check(fuzz_next)) {
        printf("Failed to get fuzz_next() method\n");
        PyErr_Print();
        Py_XDECREF(fuzz_next);
        fuzz_next = NULL;
        goto error;
    }

    if (cwd) {
        free(cwd);
    }
    return 0;

error:
    if (cwd) {
        free(cwd);
    }
    if (fuzz_next) {
        Py_DECREF(fuzz_next);
        fuzz_next = NULL;
    }
    if (gen_module) {
        Py_DECREF(gen_module);
        gen_module = NULL;
    }
    if (Py_IsInitialized()) {
        Py_Finalize();
    }
    return 1;
}

static char* inc_gen_impl(const char* start_symbol) {
    if (!fuzz_next) {
        printf("Python not initialized (fuzz_next is NULL)\n");
        return NULL;
    }

    PyObject *start_obj = PyUnicode_FromString(start_symbol ? start_symbol : "<tree>");
    if (!start_obj) {
        printf("Failed to create start symbol string\n");
        PyErr_Print();
        return NULL;
    }

    PyObject *count_obj = PyLong_FromLong(1);
    if (!count_obj) {
        printf("Failed to create count value\n");
        PyErr_Print();
        Py_DECREF(start_obj);
        return NULL;
    }

    PyObject *next_args = PyTuple_Pack(2, start_obj, count_obj);
    Py_DECREF(start_obj);
    Py_DECREF(count_obj);
    if (!next_args) {
        printf("Failed to build fuzz_next arguments\n");
        PyErr_Print();
        return NULL;
    }

    PyObject *next_list = PyObject_CallObject(fuzz_next, next_args);
    Py_DECREF(next_args);
    if (!next_list) {
        printf("Failed to call fuzz_next()\n");
        PyErr_Print();
        return NULL;
    }

    PyObject *next_seq = PySequence_Fast(next_list, "fuzz_next result is not a sequence");
    Py_DECREF(next_list);
    if (!next_seq) {
        printf("Failed to convert fuzz_next result to sequence\n");
        PyErr_Print();
        return NULL;
    }

    PyObject *item = PySequence_Fast_GET_ITEM(next_seq, 0);
    PyObject *str_obj = PyObject_Str(item);
    if (!str_obj) {
        printf("Failed to stringify fuzz_next result\n");
        PyErr_Print();
        Py_DECREF(next_seq);
        return NULL;
    }

    const char *utf8 = PyUnicode_AsUTF8(str_obj);
    if (!utf8) {
        printf("Failed to convert fuzz_next result to UTF-8\n");
        PyErr_Print();
        Py_DECREF(str_obj);
        Py_DECREF(next_seq);
        return NULL;
    }

    printf("result = %s\n", utf8);
    Py_DECREF(str_obj);
    Py_DECREF(next_seq);

    return strdup(utf8);
}

char* inc_gen_with_start(const char* start_symbol) {
    return inc_gen_impl(start_symbol);
}

char* inc_gen() {
    return inc_gen_impl("<tree>");
}

int teardown() {
    if (fuzz_next) {
        Py_DECREF(fuzz_next);
        fuzz_next = NULL;
    }
    if (gen_module) {
        Py_DECREF(gen_module);
        gen_module = NULL;
    }

    if (Py_IsInitialized()) {
        Py_Finalize();
    }
    return 0;
}
