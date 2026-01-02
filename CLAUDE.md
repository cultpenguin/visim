# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

VISIM (Volume Integration SIMulation) is a Fortran-based geostatistical simulation program for conditional simulation on 3D rectangular grids with volume integration support. It's part of the GSLIB (Geostatistical Software Library) family and is designed for applications like cross-borehole tomography and subsurface modeling.

## Build System

### Prerequisites
- Fortran compiler: gfortran or Intel Fortran (gfortran recommended)
- Make utility

### Building VISIM

The build process has two stages due to the dependency on the gslib library:

```bash
# Step 1: Build the gslib library
cd gslib
make
cd ..

# Step 2: Build the main VISIM binary
make
```

This creates the `visim` executable in the current directory.

### Build Configuration

Before building, edit the `COMP` variable in both Makefiles to match your Fortran compiler:
- `gslib/Makefile` - for the gslib library
- `Makefile` - for the main VISIM program

Current compiler flags:
- **Windows/Linux**: `-fallow-argument-mismatch -O3`
- **OSX**: `-O3` (uncomment if needed)

### Building Multiple Configurations

VISIM can be compiled with different dimension parameters. Multiple `.inc` files exist for different grid sizes:

```bash
# Build all configurations (Linux/Unix)
./make_all

# Build all configurations (Windows with MATLAB)
# Run make_all_windows.m in MATLAB
```

The `make_all` script iterates through different include files (like `visim_101_101_1_2000_199.inc`) to build specialized binaries for various grid dimensions.

### Cleaning

```bash
make clean           # Clean main build artifacts
cd gslib && make clean  # Clean library artifacts
```

## Architecture

### Core Program Structure

1. **Main Program** (`visim.f`):
   - Entry point that orchestrates the simulation process
   - Reads parameters via `readparm` subroutine
   - Opens output files and file handles
   - Loops through multiple realizations (`nsim`)
   - Calls the main `visim` subroutine for each realization

2. **Parameter File System**:
   - Uses parameter files (default: `visim.par`) for configuration
   - Parameters can be passed via command line: `visim visim.par`
   - Without arguments, prompts user interactively
   - If `visim.par` doesn't exist, creates blank template via `makepar`

3. **Include File System** (`visim.inc`):
   - Defines critical compile-time parameters via Fortran PARAMETER statements
   - Controls grid dimensions (`MAXX`, `MAXY`, `MAXZ`)
   - Sets volume neighborhood limits (`MAXVOLS`, `MAXDINVOL`)
   - **Important**: Must be properly configured before compilation
   - Multiple pre-configured include files exist for common dimension combinations

### Key Subroutines and Modules

- **Parameter Handling**:
  - `visim_readpar.f`: Reads and validates parameter file
  - `visim_makepar.f`: Creates blank parameter file template

- **Kriging and Estimation**:
  - `visim_krige.f`: Builds and solves kriging system for point locations
  - `visim_krige_volume.f`: Kriging for volume averages
  - `visim_setup_krgvar.f`: Sets up kriging variance matrices

- **Covariance Calculations**:
  - `visim_cov_vol2vol.f`: Volume-to-volume covariance
  - `visim_cov_data2vol.f`: Data-to-volume covariance
  - `visim_cov_data2data.f`: Data-to-data covariance
  - `visim_ctable.f`: Covariance table construction

- **Simulation Core**:
  - `visim_visim.f`: Main conditional simulation routine
  - `visim_simu.f`: Draws from local conditional distribution
  - `visim_randpath.f`: Generates random path through simulation grid
  - `visim_condtab.f`: Creates conditional probability lookup tables

- **Search and Neighborhood**:
  - `visim_srchnd.f`: Searches for nearby data points
  - `visim_nhoodvol.f`: Handles volume neighborhood searches

- **Transformations and Utilities**:
  - `visim_trans.f`: Data transformations
  - `visim_getz.f`: Gets Z values from grid

### GSLIB Library

The `gslib/` directory contains the core geostatistical library with utilities for:
- Random number generation (`acorni.f`, `rand.f`)
- Covariance functions (`cova3.f`)
- Matrix operations (`ksol.f`, `ktsol.f`)
- Data transformations (`nscore.f`, `backtr.f`)
- Searching and sorting (`locate.f`, `sortem.f`, `dsortem.f`)
- Rotation matrices (`setrot.f`)

### Data Flow

1. Read parameter file and input data
2. Initialize covariance lookup tables (can be read from disk or computed)
3. Create conditional probability lookup tables (if using DSSIM mode)
4. For each realization:
   - Generate random path through grid
   - For each grid node (in random order):
     - Search for nearby data and simulated values
     - Perform kriging to get conditional mean/variance
     - Draw simulated value from conditional distribution
     - Add simulated value to conditioning dataset
5. Write results to output file

### File I/O System

- **Input**: EAS-formatted data files (common in geostatistics)
- **Output**: GEOEAS files with simulated values ordered by x, y, z, then simulation number
- **Lookup Tables**: Binary unformatted Fortran files for covariance matrices (`.out` format)
  - `cv2v_*.out`: Volume-to-volume covariance
  - `cd2v_*.out`: Data-to-volume covariance
  - `lambda_*.out`: Kriging weights
  - `volnh_*.out`: Volume neighborhood information
  - `randpath_*.out`: Random path for reproducibility
- **Mask Support**: Optional `visim_mask.out` file to simulate only part of model space

### Special Features

- **Volume Integration**: Unique capability to integrate volume average data
- **DSSIM Mode**: Direct Sequential Simulation with histogram reproduction
- **Masking**: Selective simulation using mask files (version 1.8+)
- **Conditional Simulation**: Honors local data through kriging

## Important Constraints

1. **Maximum Files Limit**: Cannot use more than 399 files (related to datacov operations)

2. **Compile-Time Dimension Parameters** in `visim.inc`:
   - Grid dimensions must fit within `MAXX`, `MAXY`, `MAXZ`
   - Volume neighborhood must fit within `MAXVOLS`, `MAXDINVOL`
   - `UNEST` parameter must be appropriately low for unsampled data points

3. **Array Sizing**: All arrays are statically allocated at compile time, so include file must be configured for your maximum expected grid size before compilation

## Integration with mGstat

The README mentions mGstat (http://mgstat.sourceforge.net/), a MATLAB interface that provides:
- Parameter file editing
- Visualization of simulation results
- Tools for cross-borehole tomography inversions
- High/finite frequency sensitivity kernels

## Version History

- v1.6 (Jan 2010): Improved DSSIM for highly skewed histograms
- v1.7 (Jan 2010): Fixed file opening issues with gfortran
- v1.8 (Feb 2010): Added mask file support for selective simulation
