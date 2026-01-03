# Example 2: Conditional Estimation and Simulation

This example demonstrates both conditional kriging estimation and conditional simulation with 2 data points on a 2D grid.

## Two Variants

1. **conditional_estimation.par** - Kriging estimation only (nsim = 0)
2. **conditional_simulation.par** - 100 conditional realizations (nsim = 100)

## Parameters

- **Grid**: 40 × 40 × 1 (1600 nodes)
- **Cell size**: 1.0 × 1.0 × 1.0
- **Global mean**: 10.0
- **Global std**: 3.0 (variance = 9.0)

## Conditioning Data

Two data points are provided:

| Point | X    | Y    | Z   | Value | Original Distribution |
|-------|------|------|-----|-------|----------------------|
| 1     | 10.0 | 10.0 | 0.5 | 12.3  | N(12, 1²)           |
| 2     | 20.0 | 30.0 | 0.5 | 8.5   | N(9, 2²)            |

The values were sampled from their respective distributions to represent measurements with uncertainty.

## Variogram Model

- **Type**: Spherical (it=1)
- **Nugget**: 0.10
- **Sill**: 0.90 (total sill = 1.0)
- **Ranges**:
  - Major axis (a_hmax): 10.0
  - Minor axis (a_hmin): 10.0
  - Vertical (a_vert): 5.0

## Kriging Parameters

- **Type**: Simple Kriging (ktype = 0)
- **Search radius**: 20.0 × 20.0 × 10.0
- **Max data for kriging**: 12
- **Max previously simulated nodes**: 12

## Running the Examples

### Estimation Mode (Kriging)

From the `src_f90` directory:

```bash
cp ../examples/02_conditional/conditional_estimation.par .
cp ../examples/02_conditional/*.eas .
./visim_f90 conditional_estimation.par
```

**Output**: `conditional_estimation.out` (1600 kriged estimates)

### Simulation Mode (100 Realizations)

From the `src_f90` directory:

```bash
cp ../examples/02_conditional/conditional_simulation.par .
cp ../examples/02_conditional/*.eas .
./visim_f90 conditional_simulation.par
```

**Output**: `conditional_simulation.out` (160,000 values = 100 realizations × 1600 nodes)

## Expected Output

### Estimation Mode

`conditional_estimation.out` contains 1600 kriged estimates:
- At data locations: values = 12.3 and 8.5 (exact)
- Near data points: values influenced by nearby data
- Far from data: values approach global mean (10.0)
- Kriging variance increases with distance from data

An additional file `visim_estimation_conditional_estimation.out` contains both the kriged mean and variance at each location.

### Simulation Mode

`conditional_simulation.out` contains 100 realizations (160,000 values total):
- Each realization honors the 2 conditioning data points exactly
- Different realizations show different spatial patterns
- All realizations follow the specified variogram model
- Average of all realizations ≈ kriged estimate

## Comparing with F77 Version

This example produces **identical** results to the F77 version:

```bash
# Run F77 version
cd ../../src
cp ../examples/02_conditional/*.eas .
cp ../examples/02_conditional/conditional_estimation.par .
./visim conditional_estimation.par

# Compare outputs
diff conditional_estimation.out ../src_f90/conditional_estimation.out
# Should show no differences (except header)
```

## Files

- `conditional_estimation.par` - Parameter file for estimation (nsim=0)
- `conditional_simulation.par` - Parameter file for simulation (nsim=100)
- `conditioning_data.eas` - 2 conditioning data points
- `dummy_volgeom.eas` - Empty volume geometry
- `dummy_volsum.eas` - Empty volume summary
- `reference.eas` - Reference histogram (not used in Gaussian mode)
