# VISIM Python Package

Python interface for VISIM (Volume Integration Sequential Simulation).

## Installation

```bash
cd python
pip install -e .
```

## Quick Start - Which Function?

| File Type | Use This |
|-----------|----------|
| `.eas` files (data) | `read_eas()` |
| `.out` files (VISIM output) | `read_visim_output()` |
| `.par` files (parameters) | `VisimParams()` |

```python
from visim import VisimParams, read_eas, read_visim_output

# Read .eas file (conditioning data)
data = read_eas('conditioning_data.eas')

# Read .out file (simulation output)  
result = read_visim_output('conditional_simulation.out')

# Read .par file (parameters)
params = VisimParams('conditional_estimation.par')
```

**See `CHEATSHEET.md` for complete reference.**

## Features

- Read and write VISIM parameter files (`.par`)
- Read and write GEO-EAS data files (`.eas`)
- Read VISIM simulation/estimation output (`.out`)
- Utilities for data manipulation and statistics

## Examples

### Reading Different File Types

```python
from visim import read_eas, read_visim_output, VisimParams

# 1. Read conditioning data (.eas)
data = read_eas('conditioning_data.eas')
print(f"Points: {data['data'].shape[0]}")
print(f"Data:\n{data['data']}")

# 2. Read VISIM output (.out)
result = read_visim_output('conditional_simulation.out')
print(f"Realizations: {result['n_realizations']}")
print(f"Grid: {result['nx']}x{result['ny']}x{result['nz']}")
print(f"Mean: {result['data'].mean():.2f}")

# 3. Read parameters (.par)
params = VisimParams('conditional_estimation.par')
print(f"Grid: {params.nx}x{params.ny}x{params.nz}")
print(f"Realizations: {params.nsim}")
```

### Modifying Parameters

```python
from visim import VisimParams

# Read, modify, write
params = VisimParams('conditional_estimation.par')
params.nsim = 100
params.outfl = 'new_simulation.out'
params.write('new_params.par')
```

### Creating Data Files

```python
from visim import write_eas
import numpy as np

# Create conditioning data
data = np.array([[10.0, 10.0, 0.5, 12.3],
                 [20.0, 30.0, 0.5, 8.5]])
write_eas('my_data.eas', data,
          title='My Data',
          var_names=['x', 'y', 'z', 'value'])
```

### Analyzing Results

```python
from visim import read_visim_output
from visim.output import reshape_to_grid, get_statistics

result = read_visim_output('conditional_simulation.out')

# Get statistics
stats = get_statistics(result['data'])
print(f"Mean: {stats['mean']:.2f}")
print(f"Std: {stats['std']:.2f}")

# Reshape to 3D grid
grid = reshape_to_grid(result['data'][0], 
                       result['nx'], result['ny'], result['nz'])
print(f"Value at (10,10,0): {grid[10, 10, 0]}")
```

## Testing

```bash
cd python
python3 test_visim.py
```

All tests should pass ✓

## Documentation

- **CHEATSHEET.md** - Quick reference for file types
- **QUICKSTART.md** - Fast introduction
- **INSTALL.md** - Installation guide
- **SUMMARY.md** - Feature overview
- **examples/** - Usage examples

## API Reference

### Reading Functions

- `read_eas(filename)` - Read `.eas` files (GEO-EAS format)
- `read_visim_output(filename)` - Read `.out` files (VISIM output)
- `read_estimation_output(filename)` - Read `visim_estimation_*.out` files

### Writing Functions

- `write_eas(filename, data, title, var_names)` - Write `.eas` files

### Classes

- `VisimParams(filename)` - Read/write `.par` files

### Utilities

- `reshape_to_grid(data, nx, ny, nz)` - Reshape to 3D
- `get_statistics(data)` - Calculate stats

## Common Issues

**Q: `read_eas('simulation.out')` gives an error**

A: Use `read_visim_output()` for `.out` files, not `read_eas()`:
```python
result = read_visim_output('simulation.out')  # Correct
```

**Q: How do I read conditioning data?**

A: Use `read_eas()`:
```python
data = read_eas('conditioning_data.eas')
```

## Requirements

- Python 3.7+
- NumPy 1.20.0+

## License

Same as VISIM (see main repository)
