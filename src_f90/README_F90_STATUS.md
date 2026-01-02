# VISIM F90 Conversion Status

**Last Updated:** 2026-01-02
**Status:** Framework complete, simulation subroutines pending

---

## ✅ Completed Components

### Phase 1: Module Infrastructure (COMPLETE)
- **visim_modules.f90** - All 9 modules defined with ALLOCATABLE arrays:
  - `visim_params_mod` - Constants and scalar parameters
  - `visim_data_mod` - Conditioning data arrays
  - `visim_grid_mod` - Simulation grid arrays
  - `visim_volume_mod` - Volume integration data
  - `visim_covariance_mod` - Covariance tables and lookup structures
  - `visim_kriging_mod` - Kriging system arrays
  - `visim_search_mod` - Search parameters and super blocks
  - `visim_histogram_mod` - DSSIM and transformation arrays
  - `visim_random_mod` - RNG state (fixed size)

### Phase 2: Allocation System (COMPLETE)
- **visim_allocate.f90** - Dynamic memory management:
  - `allocate_all_arrays()` - Centralized allocation
  - `deallocate_all_arrays()` - Cleanup
  - `estimate_memory_requirements()` - Pre-allocation estimate
  - `validate_dimensions()` - Runtime dimension checking

### Phase 3: Parameter Reading (SKELETON)
- **visim_readpar_v2.f90** - Two-pass parameter reader:
  - ✅ `readparm_get_dimensions()` - Extract dimension requirements
  - ✅ `detect_format()` - Auto-detect old vs new format
  - ✅ `read_dimensions_legacy()` - Legacy format support
  - ✅ `read_dimensions_keyword()` - New keyword format support
  - ⚠️ `readparm_populate()` - **SKELETON ONLY** (needs full implementation)
  - ✅ `makepar_v2()` - Create blank parameter file (new format)

### Phase 4: Main Program (COMPLETE)
- **visim_main.f90** - Entry point with 5-phase structure:
  1. Read parameters to determine dimensions
  2. Allocate arrays based on dimensions
  3. Populate arrays with data
  4. Run simulation loop (placeholder)
  5. Cleanup and exit

### Phase 5: Build System (COMPLETE)
- **Makefile** - Automated build:
  - Compiles all modules in correct order
  - Links with GSLIB library
  - Provides `make test` for compilation check
  - Clean targets for build artifacts

---

## ⚠️ Pending Components

### Critical: Complete Parameter Population
**File:** `visim_readpar_v2.f90` - `readparm_populate()` function

**Current Status:** Skeleton placeholder only

**Required Implementation:**
1. Re-open parameter file
2. Read all 40+ parameters into module variables:
   - File names (data, volgeom, volsum, output, etc.)
   - Transformation parameters (tmin, tmax, ltail, utail, etc.)
   - Variogram model (nst, it, c0, cc, aa, ang1-3, anis1-2)
   - Search parameters (radius, sang1-3, sanis1-2, ndmin, ndmax)
   - Volume parameters (musevols, nusevols, accept_fract, etc.)
   - DSSIM parameters (n_Gmean, n_Gvar, min/max ranges, etc.)
3. Read conditioning data from files:
   - Point data (x, y, z, vr) from data file
   - Volume geometry (volx, voly, volz, voll) from volgeom file
   - Volume observations (volobs, volvar) from volsum file
4. Perform data transformations if needed
5. Validate data against allocated array sizes

**Approach:** Reference original `visim_readpar.f` (lines 98-700+) and systematically convert each read statement to use module variables instead of COMMON blocks.

### Phase 4A: Convert Low-Level Utilities (4 files)

**Priority:** Medium
**Complexity:** Low
**Dependencies:** None

1. **visim_makepar.f → visim_makepar.f90**
   - Remove `include 'visim.inc'`
   - Add `use visim_params_mod`
   - Update parameter file creation for new keyword format

2. **visim_srchnd.f → visim_srchnd.f90**
   - Add module usage: `visim_params_mod`, `visim_data_mod`, `visim_grid_mod`, `visim_search_mod`
   - Remove COMMON block declarations
   - Arrays accessed via modules

3. **visim_trans.f → visim_trans.f90**
   - Add module usage: `visim_params_mod`, `visim_data_mod`, `visim_histogram_mod`
   - Transform data arrays in place

4. **visim_simu.f → visim_simu.f90**
   - Add module usage: `visim_params_mod`, `visim_grid_mod`, `visim_histogram_mod`
   - Draw from conditional distribution

### Phase 4B: Convert Covariance & Kriging (7 files)

**Priority:** HIGH - Critical for simulation
**Complexity:** High
**Dependencies:** Low-level utilities

1. **visim_cov_vol2vol.f → visim_cov_vol2vol.f90**
2. **visim_cov_data2vol.f → visim_cov_data2vol.f90**
3. **visim_cov_data2data.f → visim_cov_data2data.f90**
4. **visim_ctable.f → visim_ctable.f90**
5. **visim_krige.f → visim_krige.f90**
6. **visim_krige_volume.f → visim_krige_volume.f90**
7. **visim_setup_krgvar.f → visim_setup_krgvar.f90**

**Conversion Pattern:**
```fortran
subroutine krige(ix, iy, iz, xx, yy, zz, lktype, gmean, cmean, cstdev)
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_covariance_mod
  use visim_kriging_mod
  implicit none

  ! Keep same subroutine signature
  integer, intent(in) :: ix, iy, iz, lktype
  real, intent(in) :: xx, yy, zz, gmean
  real, intent(out) :: cmean, cstdev

  ! Remove: include 'visim.inc'
  ! Remove: Local declarations of COMMON block variables

  ! Arrays accessed from modules (no changes to algorithm)
  ! ...
end subroutine krige
```

### Phase 4C: Convert High-Level Routines (4 files)

**Priority:** HIGH
**Complexity:** Very High
**Dependencies:** All previous

1. **visim_nhoodvol.f → visim_nhoodvol.f90**
   - Volume neighborhood selection
   - Uses: `visim_volume_mod`, `visim_covariance_mod`

2. **visim_randpath.f → visim_randpath.f90**
   - Random path generation
   - Uses: `visim_grid_mod`, `visim_volume_mod`, `visim_random_mod`

3. **visim_condtab.f → visim_condtab.f90**
   - Create conditional lookup tables for DSSIM
   - Uses: `visim_histogram_mod`, `visim_data_mod`

4. **visim_visim.f → visim_visim.f90** (MOST CRITICAL)
   - Main simulation loop
   - Calls all other subroutines
   - Uses: ALL modules

---

## 🔨 How to Continue the Conversion

### Step 1: Complete Parameter Population (IMMEDIATE)
Edit `visim_readpar_v2.f90::readparm_populate()`:

```fortran
subroutine readparm_populate()
  ! Open parameter file again
  open(lin, file=parfile_name, status='OLD')

  ! Find START marker (legacy) or parse keywords (new)
  if (format_type == 1) then
    call populate_legacy()
  else
    call populate_keyword()
  end if

  ! Read data files
  call read_data_file()
  call read_volume_files()

  ! Validate
  call validate_dimensions()

  close(lin)
end subroutine
```

### Step 2: Convert Subroutines One at a Time

**For each `.f` file in `src/`:**

1. Copy to `src_f90/` with `.f90` extension
2. Add module usage at top:
   ```fortran
   use visim_params_mod
   use visim_data_mod
   ! ... other needed modules
   implicit none
   ```
3. Remove `include 'visim.inc'`
4. Remove COMMON block variable declarations
5. Arrays are now accessed via modules (no code changes needed)
6. Test compilation: `gfortran -c -Wall <file>.f90`

### Step 3: Update Makefile

Add converted subroutines to `Makefile`:

```makefile
SUBS = visim_krige.f90 visim_krige_volume.f90 visim_randpath.f90 \
       visim_nhoodvol.f90 visim_ctable.f90 visim_srchnd.f90 \
       visim_trans.f90 visim_simu.f90 visim_visim.f90 \
       visim_condtab.f90 visim_cov_vol2vol.f90 \
       visim_cov_data2vol.f90 visim_cov_data2data.f90 \
       visim_setup_krgvar.f90

SUB_OBJ = $(SUBS:.f90=.o)

$(PROG): $(MOD_OBJ) $(HELPER_OBJ) $(SUB_OBJ) $(MAIN_OBJ) $(LIBGS)
    $(COMP) $(FFLAGS) -o $@ $^
```

### Step 4: Implement Simulation Loop in Main

In `visim_main.f90`, replace placeholder with:

```fortran
! Create conditional probability lookup table (if DSSIM)
if (idrawopt == 1) then
  call create_condtab()
end if

! Open output file
open(lout, file=outfl, status='UNKNOWN')
write(lout, '(a)') 'VISIM Realizations'
write(lout, '(a)') '1'
write(lout, '(a)') 'value'

! Main simulation loop
do isim = 1, nsim
  call visim()  ! Main simulation subroutine
end do

close(lout)
```

### Step 5: Test and Validate

1. **Compile:** `make`
2. **Run with test data:** `./visim_f90 test.par`
3. **Compare with F77 version:**
   ```bash
   ./visim_f77 test.par
   mv visim.out visim_f77.out
   ./visim_f90 test.par
   diff visim_f77.out visim.out
   ```
4. **Numerical validation (Python):**
   ```python
   import numpy as np
   f77 = np.loadtxt('visim_f77.out', skiprows=3)
   f90 = np.loadtxt('visim.out', skiprows=3)
   assert np.allclose(f77, f90, rtol=1e-10)
   ```

---

## 📊 Progress Summary

| Component | Status | Files | Lines |
|-----------|--------|-------|-------|
| Modules | ✅ Complete | 1 | 800+ |
| Allocation | ✅ Complete | 1 | 200+ |
| Parameter Reader | ⚠️ Skeleton | 1 | 400+ |
| Main Program | ✅ Complete | 1 | 150+ |
| Utilities | ⏸️ Pending | 4 | ~600 |
| Covariance/Kriging | ⏸️ Pending | 7 | ~2000 |
| High-Level | ⏸️ Pending | 4 | ~1500 |
| **TOTAL** | **~30% complete** | **19** | **~5650** |

---

## 🚀 Quick Start for Testing Current Framework

Even without full simulation, you can test the framework:

```bash
cd /mnt/d/PROGRAMMING/visim/src_f90

# Create a simple test parameter file
cat > test_minimal.par << 'EOF'
# VISIM Test Parameter File

[GRID]
nx = 10
ny = 10
nz = 1
xmin = 0.0
ymin = 0.0
zmin = 0.0
xsize = 1.0
ysize = 1.0
zsize = 1.0

[SEARCH]
ndmax = 8
nodmax = 12
EOF

# Build (modules and framework only)
make test

# Eventually run (once simulation is implemented):
# ./visim_f90 test_minimal.par
```

---

## 📝 Notes for Future Development

1. **Memory Estimation:** The framework provides upfront memory estimates - critical for large grids

2. **Error Handling:** All allocation routines include detailed error messages with memory requirements

3. **Python Integration:** Keyword parameter format is designed for easy Python parsing:
   ```python
   params = configparser.ConfigParser()
   params.read('visim.par')
   nx = params.getint('GRID', 'nx')
   ```

4. **Backward Compatibility:** Legacy parameter file format is fully supported via auto-detection

5. **Testing Strategy:** Each converted subroutine should be unit-tested against F77 version before integration

---

## 🎯 Next Immediate Actions

1. **Implement `readparm_populate()`** - Most critical missing piece
2. **Convert `visim_krige.f`** - Core kriging routine, representative of conversion pattern
3. **Convert `visim_visim.f`** - Main simulation loop
4. **Test end-to-end** with simplest case (unconditional simulation, no volumes)
5. **Iteratively add complexity** (conditioning data, volumes, DSSIM, etc.)

---

**For questions or issues, refer to the original plan at:**
`/home/tmeha/.claude/plans/resilient-marinating-ritchie.md`
