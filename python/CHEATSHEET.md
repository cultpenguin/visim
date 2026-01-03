# VISIM Python Module - Cheat Sheet

## Which Function for Which File?

| File Type | Extension | Function | Returns |
|-----------|-----------|----------|---------|
| Conditioning data | `.eas` | `read_eas()` | Dict with data array |
| VISIM output | `.out` | `read_visim_output()` | Dict with realizations |
| Estimation output | `visim_estimation_*.out` | `read_estimation_output()` | Dict with mean/variance |
| Parameter file | `.par` | `VisimParams()` | Parameter object |

## Quick Examples

```python
from visim import VisimParams, read_eas, read_visim_output
from visim.output import read_estimation_output

# Read conditioning data (.eas)
data = read_eas('conditioning_data.eas')
print(data['data'])  # NumPy array (n_points, 4)

# Read simulation output (.out)  
result = read_visim_output('conditional_simulation.out')
print(result['data'].shape)  # (n_realizations, n_nodes)

# Read estimation output (visim_estimation_*.out)
est = read_estimation_output('visim_estimation_conditional_estimation.out')
print(est['mean'], est['variance'])

# Read parameter file (.par)
params = VisimParams('conditional_estimation.par')
print(params.nx, params.ny, params.nz)
```

## Common Mistakes

❌ **WRONG:**
```python
# Don't use read_eas() for .out files
result = read_eas('simulation.out')  # ERROR!
```

✅ **CORRECT:**
```python
# Use read_visim_output() for .out files
result = read_visim_output('simulation.out')
```

## File Extensions Guide

- **`.eas`** - GEO-EAS format (data/geometry)
  - `conditioning_data.eas`
  - `dummy_volgeom.eas`
  - `reference.eas`
  
- **`.par`** - VISIM parameter file
  - `conditional_estimation.par`
  - `conditional_simulation.par`
  
- **`.out`** - VISIM output
  - `conditional_simulation.out` (simulation)
  - `conditional_estimation.out` (estimation)
  - `visim_estimation_*.out` (estimation with variance)

## Import Shortcuts

```python
# Import everything you need
from visim import (
    VisimParams,           # For .par files
    read_eas,              # For .eas files
    write_eas,             # Write .eas files
    read_visim_output,     # For .out files
    read_estimation_output # For visim_estimation_*.out
)
from visim.output import reshape_to_grid, get_statistics
```

## Running Simulations

```python
from visim import run_visim, find_visim_executable

# Find VISIM executable
exe = find_visim_executable()  # Returns path or None

# Run simulation
result = run_visim('simulation.par')
# or specify executable
result = run_visim('simulation.par', visim_exe='/path/to/visim_f90')

# Check result
if result['success']:
    print(f"Completed in {result['runtime']:.1f}s")
    print(f"Output: {result['output_file']}")
```

## Complete Workflow

```python
from visim import (VisimParams, write_eas, run_visim, 
                   read_visim_output, get_statistics)
import numpy as np

# 1. Create data
data = np.array([[10, 10, 0.5, 12.3],
                 [20, 30, 0.5, 8.5]])
write_eas('data.eas', data, var_names=['x','y','z','value'])

# 2. Create parameters
params = VisimParams()
params.nx, params.ny, params.nz = 40, 40, 1
params.nsim = 100
params.datafl = 'data.eas'
params.write('simulation.par')

# 3. Run simulation
result = run_visim('simulation.par')

# 4. Analyze results
if result['success']:
    output = read_visim_output(result['output_file'])
    stats = get_statistics(output['data'])
    print(f"Mean: {stats['mean']:.2f}")
```
