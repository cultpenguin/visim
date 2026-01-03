# VISIM Python Examples

## Available Examples

### 1. example_basic_usage.py
Basic usage of the VISIM Python module:
- Reading parameter files
- Reading data files  
- Reading VISIM output
- Modifying parameters
- Creating conditioning data

```bash
python3 example_basic_usage.py
```

### 2. example_run_simulation.py
Running VISIM simulations from Python:
- Running existing parameter files
- Creating and running new simulations
- Batch processing multiple simulations
- Complete end-to-end workflow

```bash
python3 example_run_simulation.py
```

## Quick Examples

### Read and Analyze Output

```python
from visim import read_visim_output
from visim.output import get_statistics

result = read_visim_output('simulation.out')
stats = get_statistics(result['data'])
print(f"Mean: {stats['mean']:.2f}, Std: {stats['std']:.2f}")
```

### Run a Simulation

```python
from visim import run_visim

result = run_visim('simulation.par')
if result['success']:
    print(f"Completed in {result['runtime']:.1f}s")
```

### Complete Workflow

```python
from visim import VisimParams, write_eas, run_visim, read_visim_output
import numpy as np

# 1. Create data
data = np.array([[10, 10, 0.5, 12.3]])
write_eas('data.eas', data, var_names=['x','y','z','value'])

# 2. Setup parameters
params = VisimParams()
params.nx = params.ny = 40
params.nz = 1
params.nsim = 50
params.datafl = 'data.eas'
params.write('sim.par')

# 3. Run
result = run_visim('sim.par')

# 4. Analyze
if result['success']:
    output = read_visim_output(result['output_file'])
    print(f"Mean: {output['data'].mean():.2f}")
```

## Prerequisites

- VISIM executable (`visim_f90`) must be available
- Either in PATH or specify location with `visim_exe` parameter
- Use `find_visim_executable()` to locate it automatically

## Common Issues

**Q: "VISIM executable not found"**

A: Specify the full path:
```python
result = run_visim('sim.par', visim_exe='/path/to/visim_f90')
```

Or find it:
```python
from visim import find_visim_executable
exe = find_visim_executable()
if exe:
    result = run_visim('sim.par', visim_exe=exe)
```

**Q: How do I run simulations in a different directory?**

A: Use the `working_dir` parameter:
```python
result = run_visim('sim.par', working_dir='/path/to/workdir')
```

## See Also

- `../CHEATSHEET.md` - Quick reference
- `../README.md` - Full documentation
- `../QUICKSTART.md` - Getting started guide
