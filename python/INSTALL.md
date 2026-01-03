# Installation Guide

## Prerequisites

- Python 3.7 or higher
- NumPy 1.20.0 or higher

## Installation

### Option 1: Development Installation (Recommended)

Install in editable mode so changes to the code are immediately available:

```bash
cd python
pip install -e .
```

### Option 2: Standard Installation

```bash
cd python
pip install .
```

### Option 3: Direct Use Without Installation

You can use the module without installing by adding the directory to your Python path:

```python
import sys
sys.path.insert(0, '/path/to/visim/python')
import visim
```

## Verification

Test the installation:

```bash
cd python
python3 test_visim.py
```

All tests should pass.

## Usage

Once installed, you can import the module from anywhere:

```python
from visim import VisimParams, read_eas, read_visim_output

# Read parameter file
params = VisimParams('visim.par')

# Read data file
data = read_eas('conditioning_data.eas')

# Read output
result = read_visim_output('simulation.out')
```

## Examples

See the `examples/` directory for usage examples:

```bash
cd python/examples
python3 example_basic_usage.py
```

## Troubleshooting

### ImportError: No module named 'numpy'

Install NumPy:
```bash
pip install numpy
```

### ModuleNotFoundError: No module named 'visim'

Make sure you've installed the package or added it to your Python path.

### Permission denied

Use `--user` flag:
```bash
pip install --user -e .
```

## Uninstallation

If installed with pip:
```bash
pip uninstall visim
```

If using development mode, just delete the egg-link file or run:
```bash
pip uninstall visim
```
