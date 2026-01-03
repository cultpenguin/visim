#!/usr/bin/env python3
"""
Test script for the VISIM Python module.
"""

import sys
import os
import numpy as np

# Add current directory to path for testing
sys.path.insert(0, os.path.dirname(__file__))

from visim import VisimParams, read_eas, write_eas, read_visim_output
from visim.output import reshape_to_grid, get_statistics
from visim.data import read_conditioning_data


def test_parameter_reading():
    """Test reading a parameter file."""
    print("=" * 60)
    print("TEST 1: Reading Parameter File")
    print("=" * 60)
    
    parfile = '../examples/02_conditional/conditional_estimation.par'
    
    if not os.path.exists(parfile):
        print(f"SKIP: {parfile} not found")
        return
    
    params = VisimParams(parfile)
    print(f"✓ Loaded: {parfile}")
    print(f"  Grid: {params.nx} x {params.ny} x {params.nz}")
    print(f"  Realizations: {params.nsim}")
    print(f"  Global mean: {params.gmean}")
    print(f"  Global variance: {params.gvar}")
    print(f"  Variogram: nst={params.nst}, nugget={params.c0}")
    print(f"  Range: {params.aa[0]}")
    print(f"  Output file: {params.outfl}")
    print()


def test_parameter_writing():
    """Test writing a parameter file."""
    print("=" * 60)
    print("TEST 2: Writing Parameter File")
    print("=" * 60)
    
    # Create new params
    params = VisimParams()
    params.nx = 50
    params.ny = 50
    params.nz = 1
    params.nsim = 10
    params.gmean = 5.0
    params.gvar = 4.0
    params.outfl = 'test_output.out'
    
    # Write to file
    outfile = '/tmp/test_params.par'
    params.write(outfile)
    print(f"✓ Written: {outfile}")
    
    # Read it back
    params2 = VisimParams(outfile)
    print(f"✓ Read back successfully")
    print(f"  Grid: {params2.nx} x {params2.ny} x {params2.nz}")
    print(f"  Realizations: {params2.nsim}")
    print(f"  Global mean: {params2.gmean}")
    
    # Verify
    assert params2.nx == 50
    assert params2.ny == 50
    assert params2.nsim == 10
    assert params2.gmean == 5.0
    print("✓ All values match!")
    print()


def test_eas_reading():
    """Test reading GEO-EAS files."""
    print("=" * 60)
    print("TEST 3: Reading GEO-EAS File")
    print("=" * 60)
    
    datafile = '../examples/02_conditional/conditioning_data.eas'
    
    if not os.path.exists(datafile):
        print(f"SKIP: {datafile} not found")
        return
    
    data = read_eas(datafile)
    print(f"✓ Loaded: {datafile}")
    print(f"  Title: {data['title']}")
    print(f"  Variables: {data['var_names']}")
    print(f"  Data shape: {data['data'].shape}")
    print(f"  Data:\n{data['data']}")
    
    # Test convenience function
    points = read_conditioning_data(datafile)
    print(f"✓ Using read_conditioning_data():")
    print(f"  Number of points: {points['n_points']}")
    print(f"  X: {points['x']}")
    print(f"  Y: {points['y']}")
    print(f"  Values: {points['value']}")
    print()


def test_eas_writing():
    """Test writing GEO-EAS files."""
    print("=" * 60)
    print("TEST 4: Writing GEO-EAS File")
    print("=" * 60)
    
    # Create test data
    data = np.array([[1.0, 2.0, 0.5, 10.5],
                     [3.0, 4.0, 0.5, 12.3],
                     [5.0, 6.0, 0.5, 8.7]])
    
    outfile = '/tmp/test_data.eas'
    write_eas(outfile, data,
              title='Test Data',
              var_names=['x', 'y', 'z', 'value'])
    
    print(f"✓ Written: {outfile}")
    
    # Read it back
    data2 = read_eas(outfile)
    print(f"✓ Read back successfully")
    print(f"  Shape: {data2['data'].shape}")
    print(f"  Data:\n{data2['data']}")
    
    # Verify
    assert np.allclose(data, data2['data'])
    print("✓ Data matches!")
    print()


def test_output_reading():
    """Test reading VISIM output files."""
    print("=" * 60)
    print("TEST 5: Reading VISIM Output")
    print("=" * 60)
    
    # Test estimation output
    est_file = '../src_f90/conditional_estimation.out'
    if os.path.exists(est_file):
        result = read_visim_output(est_file)
        print(f"✓ Loaded: {est_file}")
        print(f"  Realizations: {result['n_realizations']}")
        print(f"  Grid: {result['nx']} x {result['ny']} x {result['nz']}")
        print(f"  Nodes: {result['n_nodes']}")
        print(f"  Data shape: {result['data'].shape}")
        
        # Get statistics
        stats = get_statistics(result['data'])
        print(f"  Mean: {stats['mean']:.4f}")
        print(f"  Std: {stats['std']:.4f}")
        print(f"  Min: {stats['min']:.4f}")
        print(f"  Max: {stats['max']:.4f}")
        
        # Test grid reshaping
        grid = reshape_to_grid(result['data'], result['nx'], result['ny'], result['nz'])
        print(f"✓ Reshaped to grid: {grid.shape}")
        print(f"  Value at (10,10,0): {grid[10, 10, 0]:.4f}")
        print(f"  Value at (20,30,0): {grid[20, 30, 0]:.4f}")
    else:
        print(f"SKIP: {est_file} not found")
    
    print()
    
    # Test simulation output
    sim_file = '../src_f90/conditional_simulation.out'
    if os.path.exists(sim_file):
        result = read_visim_output(sim_file)
        print(f"✓ Loaded: {sim_file}")
        print(f"  Realizations: {result['n_realizations']}")
        print(f"  Grid: {result['nx']} x {result['ny']} x {result['nz']}")
        print(f"  Data shape: {result['data'].shape}")
        
        # Get statistics
        stats = get_statistics(result['data'])
        print(f"  Overall mean: {stats['mean']:.4f}")
        print(f"  Overall std: {stats['std']:.4f}")
        print(f"  Realization means (first 5): {stats['realization_means'][:5]}")
        print(f"  Realization stds (first 5): {stats['realization_stds'][:5]}")
    else:
        print(f"SKIP: {sim_file} not found")
    
    print()


def test_complete_workflow():
    """Test complete workflow: create params and data."""
    print("=" * 60)
    print("TEST 6: Complete Workflow")
    print("=" * 60)
    
    # Create conditioning data
    print("Creating conditioning data...")
    data = np.array([[15.0, 15.0, 0.5, 11.0],
                     [25.0, 25.0, 0.5, 9.0]])
    
    datafile = '/tmp/test_conditioning.eas'
    write_eas(datafile, data,
              title='Test Conditioning Data',
              var_names=['x', 'y', 'z', 'value'])
    print(f"✓ Written: {datafile}")
    
    # Create parameter file
    print("Creating parameter file...")
    params = VisimParams()
    params.nx = 30
    params.ny = 30
    params.nz = 1
    params.nsim = 5
    params.gmean = 10.0
    params.gvar = 9.0
    params.datafl = 'test_conditioning.eas'
    params.outfl = 'test_simulation.out'
    params.radius = 15.0
    params.radius1 = 15.0
    params.radius2 = 5.0
    
    parfile = '/tmp/test_simulation.par'
    params.write(parfile)
    print(f"✓ Written: {parfile}")
    
    # Verify by reading back
    params2 = VisimParams(parfile)
    data2 = read_eas(datafile)
    
    print(f"✓ Verification:")
    print(f"  Grid: {params2.nx} x {params2.ny} x {params2.nz}")
    print(f"  Conditioning points: {data2['data'].shape[0]}")
    print(f"  Ready to run: visim_f90 {parfile}")
    print()


def main():
    """Run all tests."""
    print("\n" + "=" * 60)
    print("VISIM Python Module Test Suite")
    print("=" * 60 + "\n")
    
    try:
        test_parameter_reading()
        test_parameter_writing()
        test_eas_reading()
        test_eas_writing()
        test_output_reading()
        test_complete_workflow()
        
        print("=" * 60)
        print("ALL TESTS PASSED ✓")
        print("=" * 60)
        
    except Exception as e:
        print(f"\n✗ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
