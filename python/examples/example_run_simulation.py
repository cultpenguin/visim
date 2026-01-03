#!/usr/bin/env python3
"""
Example: Running VISIM from Python

This script demonstrates how to run VISIM simulations directly from Python.
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import numpy as np
from visim import (VisimParams, write_eas, run_visim, 
                   read_visim_output, find_visim_executable)
from visim.output import get_statistics


def example1_basic_run():
    """Example 1: Run existing parameter file."""
    print("\n" + "=" * 70)
    print("EXAMPLE 1: Run Existing Parameter File")
    print("=" * 70)
    
    # Find VISIM executable
    exe = find_visim_executable()
    if exe:
        print(f"Found VISIM at: {exe}")
    else:
        exe = '../../src_f90/visim_f90'
        print(f"Using: {exe}")
    
    # Run simulation
    result = run_visim(
        '../../examples/02_conditional/conditional_estimation.par',
        visim_exe=exe,
        verbose=True
    )
    
    if result['success']:
        print(f"\n✓ Simulation completed in {result['runtime']:.1f}s")
        
        # Read results
        if result['output_file']:
            output = read_visim_output(result['output_file'])
            stats = get_statistics(output['data'])
            print(f"  Mean: {stats['mean']:.4f}")
            print(f"  Std: {stats['std']:.4f}")
    else:
        print(f"\n✗ Simulation failed")


def example2_create_and_run():
    """Example 2: Create parameter file and run."""
    print("\n" + "=" * 70)
    print("EXAMPLE 2: Create Parameter File and Run")
    print("=" * 70)
    
    # Create conditioning data
    np.random.seed(42)
    x = np.random.uniform(0, 30, 5)
    y = np.random.uniform(0, 30, 5)
    z = np.full(5, 0.5)
    values = np.random.normal(10.0, 2.0, 5)
    
    data = np.column_stack([x, y, z, values])
    write_eas('/tmp/test_data.eas', data,
              title='Test Data',
              var_names=['x', 'y', 'z', 'value'])
    
    print(f"✓ Created {len(data)} conditioning points")
    
    # Create parameter file
    params = VisimParams()
    params.nx = 30
    params.ny = 30
    params.nz = 1
    params.nsim = 10
    params.icond = 1
    params.gmean = 10.0
    params.gvar = 4.0
    params.datafl = 'test_data.eas'
    params.outfl = 'test_output.out'
    params.write('/tmp/test_params.par')
    
    print(f"✓ Created parameter file")
    print(f"  Grid: {params.nx}x{params.ny}x{params.nz}")
    print(f"  Realizations: {params.nsim}")

    # Data file is already in /tmp, no need to copy

    # Copy required dummy files
    import shutil
    for f in ['dummy_volgeom.eas', 'dummy_volsum.eas', 'reference.eas']:
        src = f'../../examples/02_conditional/{f}'
        dst = '/tmp/'
        if os.path.exists(src):
            shutil.copy(src, dst)

    # Run simulation
    exe = find_visim_executable()
    if not exe:
        exe = '../../src_f90/visim_f90'
    
    result = run_visim(
        '/tmp/test_params.par',
        visim_exe=exe,
        verbose=False  # Silent mode
    )
    
    if result['success']:
        print(f"\n✓ Simulation completed in {result['runtime']:.1f}s")
        
        # Read and analyze
        output = read_visim_output(result['output_file'])
        stats = get_statistics(output['data'])
        
        print(f"\nResults:")
        print(f"  Realizations: {output['n_realizations']}")
        print(f"  Mean: {stats['mean']:.4f} (target: {params.gmean})")
        print(f"  Std: {stats['std']:.4f} (target: {np.sqrt(params.gvar):.1f})")
    else:
        print(f"\n✗ Simulation failed")
        print(result['stderr'])


def example3_batch_run():
    """Example 3: Run multiple simulations."""
    print("\n" + "=" * 70)
    print("EXAMPLE 3: Batch Run Multiple Simulations")
    print("=" * 70)
    
    # Create multiple parameter files with different seeds
    base = VisimParams('../../examples/02_conditional/conditional_estimation.par')
    
    parfiles = []
    for i in range(3):
        base.ixv = 10000 + i
        base.outfl = f'batch_output_{i}.out'
        parfile = f'/tmp/batch_params_{i}.par'
        base.write(parfile)
        parfiles.append(parfile)
    
    print(f"✓ Created {len(parfiles)} parameter files")

    # Copy data files if they don't exist
    import shutil
    for f in ['conditioning_data.eas', 'dummy_volgeom.eas',
              'dummy_volsum.eas', 'reference.eas']:
        src = f'../../examples/02_conditional/{f}'
        dst = f'/tmp/{f}'
        if os.path.exists(src) and not os.path.exists(dst):
            shutil.copy(src, '/tmp/')
    
    # Run batch
    exe = find_visim_executable()
    if not exe:
        exe = '../../src_f90/visim_f90'
    
    from visim import run_visim_batch
    results = run_visim_batch(parfiles, visim_exe=exe, verbose=False)
    
    print(f"\nBatch Results:")
    for i, result in enumerate(results):
        status = "SUCCESS" if result['success'] else "FAILED"
        print(f"  Simulation {i+1}: {status} ({result['runtime']:.1f}s)")


def main():
    """Run all examples."""
    print("\n" + "=" * 70)
    print("VISIM Python Module - Running Simulations")
    print("=" * 70)
    
    try:
        example1_basic_run()
        example2_create_and_run()
        example3_batch_run()
        
        print("\n" + "=" * 70)
        print("All examples completed!")
        print("=" * 70 + "\n")
        
    except FileNotFoundError as e:
        print(f"\nError: {e}")
        print("\nMake sure:")
        print("  1. VISIM executable exists (visim_f90)")
        print("  2. Example files exist in ../../examples/")
        print("  3. You have write permissions for /tmp/\n")
    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()
