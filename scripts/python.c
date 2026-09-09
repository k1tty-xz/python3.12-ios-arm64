#include <Python.h>

int main(int argc, char **argv)
{
    PyConfig config;
    PyConfig_InitPythonConfig(&config);
    config.use_system_logger = 0;
    PyStatus status = PyConfig_SetBytesArgv(&config, argc, argv);
    if (!PyStatus_Exception(status)) {
        status = Py_InitializeFromConfig(&config);
    }
    PyConfig_Clear(&config);
    if (PyStatus_Exception(status)) {
        Py_ExitStatusException(status);
    }
    return Py_RunMain();
}
