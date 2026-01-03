#!/usr/bin/env python3
"""
Basic usage examples for the VISIM Python module.
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import numpy as np
from visim import VisimParams, read_eas, write_eas, read_visim_output
from visim.output import reshape_to_grid, get_statistics


def example1_read_results():
    """Example 1: Read and analyze VISIM results."""
    print("\n" + "=" * 70)
    print("EXAMPLE 1: Reading VISIM Results")
    print("=" * 70)
    
    result = read_visim_output('../../src_f90/conditional_simulation.out')
    stats = get_statistics(result['data'])
    
    print(f"\nSimulation: {result['n_realizations']} realizations")
    print(f"Grid: {result['nx']} x {result['ny']} x {result['nz']}")
    print(f"Mean: {stats['mean']:.4f}, Std: {stats['std']:.4f}")


def example2_modify_params():
    """Example 2: Modify parameter file."""
    print("\n" + "=" * 70)
    print("EXAMPLE 2: Modifying Parameters")
    print("=" * 70)
    
    params = VisimParams('../../examples/02_conditional/conditional_estimation.par')
    params.nsim = 50
    params.outfl = 'my_simulation.out'
    params.write('/tmp/modified_params.par')
    print(f"✓ Created /tmp/modified_params.par with {params.nsim} realizations")


def example3_create_data():
    """Example 3: Create conditioning data."""
    print("\n" + "=" * 70)
    print("EXAMPLE 3: Creating Conditioning Data")
    print("=" * 70)
    
    np.random.seed(42)
    x = np.random.uniform(0, 40, 5)
    y = np.random.uniform(0, 40, 5)
    z = np.full(5, 0.5)
    values = np.random.normal(10.0, 3.0, 5)
    
    data = np.column_stack([x, y, z, values])
    write_eas('/tmp/my_data.eas', data, 
              title='My Data', var_names=['x', 'y', 'z', 'value'])
    print(f"✓ Created 5 conditioning points")


if __name__ == '__main__':
    print("\nVISIM Python Module - Examples")
    try:
        example1_read_results()
        example2_modify_params()
        example3_create_data()
        print("\n✓ All examples completed!\n")
    except FileNotFoundError as e:
        print(f"\nNote: Some files not found: {e}")
        print("Run VISIM simulations first.\n")
