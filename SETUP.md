# Python Environment Setup

Etna uses separate Python environments for the experiment driver and the
Haskell BST Fandango generator. Keeping them separate avoids mixing the
driver's pinned dependencies with the Python version embedded by the Haskell
workload.

Run the commands below from the repository root.

## Experiment driver

The experiment driver uses Python 3.10.5 and the packages pinned in
`tool/requirements.txt`.

```sh
python3.10 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r tool/requirements.txt
python -m pip install -e tool
```

Keep `.venv` active when running Etna commands such as `make collect4.1` and
`make analyze4.1`, since those commands invoke `python3`.

## Haskell BST Fandango generator

The BST Fandango bridge embeds Python 3.14 and expects the Fandango package in
its own virtual environment. Create that environment and install Fandango:

```sh
python3.14 -m venv workloads/Haskell/BST/.py_conn_ffi-venv
workloads/Haskell/BST/.py_conn_ffi-venv/bin/python -m pip install --upgrade pip
workloads/Haskell/BST/.py_conn_ffi-venv/bin/python -m pip install fandango
```

Set `PY_CONN_FFI_VENV` to that environment when building or running the BST
Fandango workload:

```sh
export PY_CONN_FFI_VENV="$PWD/workloads/Haskell/BST/.py_conn_ffi-venv"
```

The bridge is linked against CPython 3.14. `workloads/Haskell/BST/stack.yaml`
contains the Python include and library directories used for that link, as well
as local LLVM tool paths. `workloads/Haskell/BST/src/py_conn_ffi.c` also has a
local absolute path to `gen.py`. Update these paths to match the checkout and
installed tools before building on another machine.

## Activating an environment

Activate only the environment needed for the command being run:

```sh
# Etna experiment driver
source .venv/bin/activate

# Haskell BST Fandango workload
export PY_CONN_FFI_VENV="$PWD/workloads/Haskell/BST/.py_conn_ffi-venv"
```

The Fandango environment does not need to be activated as the shell's current
environment. The bridge uses `PY_CONN_FFI_VENV` to select its interpreter and
site-packages directory.
