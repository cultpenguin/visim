# VISIM Python Module - Quick Start

## Installation (One Command)

```bash
cd python && pip install -e .
```

## Quick Reference

### Read Parameter File
```python
from visim import VisimParams
params = VisimParams('simulation.par')
print(params.nx, params.ny, params.nz)  # Grid dimensions
print(params.nsim)                       # Number of realizations
```

### Modify and Save
```python
params.nsim = 100
params.gmean = 10.0
params.gvar = 9.0
params.write('new_params.par')
```

### Read Data File
```python
from visim import read_eas
data = read_eas('conditioning_data.eas')
print(data['data'])  # NumPy array with x, y, z, value
```

### Write Data File
```python
from visim import write_eas
import numpy as np

points = np.array([[10, 10, 0.5, 12.3],
                   [20, 30, 0.5, 8.5]])
write_eas('data.eas', points, var_names=['x','y','z','value'])
```

### Read Simulation Output
```python
from visim import read_visim_output
result = read_visim_output('simulation.out')

print(result['n_realizations'])  # e.g., 100
print(result['nx'], result['ny'], result['nz'])
print(result['data'].shape)      # e.g., (100, 1600)
```

### Get Statistics
```python
from visim.output import get_statistics
stats = get_statistics(result['data'])

print(f"Mean: {stats['mean']:.2f}")
print(f"Std:  {stats['std']:.2f}")
print(f"Min:  {stats['min']:.2f}")
print(f"Max:  {stats['max']:.2f}")
```

### Reshape to 3D Grid
```python
from visim.output import reshape_to_grid

# Get first realization as 3D grid
grid = reshape_to_grid(result['data'][0], 
                       result['nx'], result['ny'], result['nz'])

# Access specific node
value = grid[10, 10, 0]  # Value at (x=10, y=10, z=0)
```

## Complete Workflow Example

```python
import numpy as np
from visim import VisimParams, write_eas, read_visim_output
from visim.output import get_statistics

# 1. Create conditioning data
data = np.array([[10, 10, 0.5, 12.3],
                 [20, 30, 0.5, 8.5]])
write_eas('my_data.eas', data, 
          var_names=['x', 'y', 'z', 'value'])

# 2. Create parameter file
params = VisimParams()
params.nx = 40
params.ny = 40
params.nz = 1
params.nsim = 100
params.gmean = 10.0
params.gvar = 9.0
params.datafl = 'my_data.eas'
params.outfl = 'my_simulation.out'
params.write('my_params.par')

# 3. Run VISIM (in shell)
#    $ visim_f90 my_params.par

# 4. Read and analyze results
result = read_visim_output('my_simulation.out')
stats = get_statistics(result['data'])

print(f"Completed {result['n_realizations']} realizations")
print(f"Mean: {stats['mean']:.2f}, Std: {stats['std']:.2f}")
```

## Test It Works

```bash
cd python
python3 test_visim.py
# Should see: ALL TESTS PASSED ✓
```

## Get Help

```python
from visim import VisimParams
help(VisimParams)

from visim import read_eas
help(read_eas)
```

See `README.md` for full documentation.
