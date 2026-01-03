# VISIM Python Module - Summary

## Overview

A Python interface for VISIM (Volume Integration Sequential Simulation) that enables:
- Reading and writing VISIM parameter files
- Reading and writing GEO-EAS data files
- Reading VISIM simulation and estimation output
- Data analysis and manipulation

## Installation

```bash
cd python
pip install -e .
```

## Package Structure

```
python/
├── setup.py              # Package installation configuration
├── README.md             # User documentation
├── INSTALL.md           # Installation guide
├── SUMMARY.md           # This file
├── test_visim.py        # Test suite
├── visim/               # Main package
│   ├── __init__.py      # Package initialization
│   ├── parameters.py    # VisimParams class for .par files
│   ├── data.py          # GEO-EAS file I/O
│   └── output.py        # VISIM output reading and analysis
└── examples/            # Usage examples
    └── example_basic_usage.py
```

## Key Components

### 1. VisimParams Class (parameters.py)

Read, modify, and write VISIM parameter files:

```python
from visim import VisimParams

# Read existing file
params = VisimParams('simulation.par')

# Modify
params.nsim = 100
params.gmean = 10.0
params.gvar = 9.0

# Write
params.write('new_simulation.par')
```

**Attributes:** icond, nsim, nx, ny, nz, gmean, gvar, datafl, outfl, and all other VISIM parameters

### 2. Data I/O Functions (data.py)

Read and write GEO-EAS formatted files:

```python
from visim import read_eas, write_eas

# Read
data = read_eas('conditioning_data.eas')
print(data['title'])
print(data['data'])  # NumPy array

# Write
import numpy as np
coords = np.array([[x, y, z, value], ...])
write_eas('output.eas', coords, 
          var_names=['x', 'y', 'z', 'value'])
```

**Functions:**
- `read_eas(filename)` → dict with 'data', 'title', 'var_names'
- `write_eas(filename, data, title, var_names)`
- `read_conditioning_data(filename)` → dict with 'x', 'y', 'z', 'value'

### 3. Output Reading (output.py)

Read and analyze VISIM simulation/estimation results:

```python
from visim import read_visim_output
from visim.output import reshape_to_grid, get_statistics

# Read output
result = read_visim_output('simulation.out')
print(result['n_realizations'])  # e.g., 100
print(result['data'].shape)      # e.g., (100, 1600)

# Statistics
stats = get_statistics(result['data'])
print(stats['mean'], stats['std'])

# Reshape to grid
grid = reshape_to_grid(result['data'][0], 
                       result['nx'], result['ny'], result['nz'])
print(grid[10, 10, 0])  # Value at grid node (10,10,0)
```

**Functions:**
- `read_visim_output(filename)` → dict with simulation data
- `read_estimation_output(filename)` → dict with mean and variance
- `reshape_to_grid(data, nx, ny, nz)` → 3D NumPy array
- `get_statistics(data)` → dict with mean, std, min, max, etc.

## Testing

Run the test suite:

```bash
cd python
python3 test_visim.py
```

Tests verify:
- Parameter file reading and writing
- GEO-EAS file I/O
- VISIM output reading
- Data manipulation functions
- Round-trip consistency

## Examples

Run the example script:

```bash
cd python/examples
python3 example_basic_usage.py
```

Examples demonstrate:
1. Reading and analyzing VISIM results
2. Modifying existing parameter files
3. Creating conditioning data programmatically

## Common Use Cases

### Use Case 1: Batch Processing

```python
from visim import VisimParams

# Create multiple parameter files with different seeds
base = VisimParams('template.par')
for i in range(10):
    base.ixv = 10000 + i
    base.outfl = f'simulation_{i:03d}.out'
    base.write(f'params_{i:03d}.par')
```

### Use Case 2: Post-Processing

```python
from visim import read_visim_output
from visim.output import get_statistics
import numpy as np

# Read simulation
result = read_visim_output('simulation.out')

# Calculate E-type (expected value)
etype = np.mean(result['data'], axis=0)

# Calculate uncertainty
std = np.std(result['data'], axis=0)

print(f"Mean: {np.mean(etype):.2f}")
print(f"Average uncertainty: {np.mean(std):.2f}")
```

### Use Case 3: Creating Synthetic Data

```python
from visim import write_eas
import numpy as np

# Generate random conditioning points
np.random.seed(42)
n = 20
x = np.random.uniform(0, 100, n)
y = np.random.uniform(0, 100, n)
z = np.full(n, 0.5)
values = np.random.normal(10, 3, n)

data = np.column_stack([x, y, z, values])
write_eas('synthetic_data.eas', data,
          title='Synthetic Conditioning Data',
          var_names=['x', 'y', 'z', 'porosity'])
```

## Requirements

- Python 3.7+
- NumPy 1.20.0+

## License

Same as VISIM (see main repository)

## Version

2.0.0 - Matches VISIM F90 version
