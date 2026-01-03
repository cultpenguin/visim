"""
Module for running VISIM simulations from Python.
"""

import subprocess
import os
import time
from pathlib import Path


def run_visim(parfile, visim_exe='visim_f90', working_dir=None, verbose=True):
    """
    Run VISIM simulation from Python.
    
    Parameters
    ----------
    parfile : str
        Path to VISIM parameter file (.par)
    visim_exe : str, optional
        Path to VISIM executable. Default: 'visim_f90' (assumes in PATH)
        Can also be full path like '/path/to/src_f90/visim_f90'
    working_dir : str, optional
        Working directory for simulation. If None, uses directory of parfile
    verbose : bool, optional
        Print simulation output in real-time. Default: True
        
    Returns
    -------
    result : dict
        Dictionary containing:
        - 'success': bool, whether simulation completed successfully
        - 'returncode': int, process return code (0 = success)
        - 'stdout': str, captured standard output
        - 'stderr': str, captured standard error
        - 'runtime': float, execution time in seconds
        - 'output_file': str, path to output file (if found in stdout)
        
    Examples
    --------
    >>> # Basic usage
    >>> result = run_visim('simulation.par')
    >>> if result['success']:
    ...     print(f"Simulation completed in {result['runtime']:.1f}s")
    
    >>> # Specify executable location
    >>> result = run_visim('simulation.par', 
    ...                    visim_exe='../src_f90/visim_f90')
    
    >>> # Run silently
    >>> result = run_visim('simulation.par', verbose=False)
    >>> print(result['stdout'])
    
    >>> # Complete workflow
    >>> from visim import VisimParams, run_visim, read_visim_output
    >>> params = VisimParams('template.par')
    >>> params.nsim = 100
    >>> params.write('my_sim.par')
    >>> result = run_visim('my_sim.par')
    >>> if result['success']:
    ...     output = read_visim_output(result['output_file'])
    """
    # Resolve paths
    parfile = str(Path(parfile).resolve())
    
    if not os.path.exists(parfile):
        raise FileNotFoundError(f"Parameter file not found: {parfile}")
    
    # Determine working directory
    if working_dir is None:
        working_dir = os.path.dirname(parfile)
        parfile_name = os.path.basename(parfile)
    else:
        working_dir = str(Path(working_dir).resolve())
        parfile_name = parfile
    
    # Build command
    cmd = [visim_exe, parfile_name]
    
    if verbose:
        print(f"Running VISIM...")
        print(f"  Executable: {visim_exe}")
        print(f"  Parameter file: {parfile_name}")
        print(f"  Working directory: {working_dir}")
        print(f"  Command: {' '.join(cmd)}")
        print("-" * 60)
    
    # Run simulation
    start_time = time.time()
    
    try:
        if verbose:
            # Real-time output
            process = subprocess.Popen(
                cmd,
                cwd=working_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                bufsize=1
            )
            
            stdout_lines = []
            stderr_lines = []
            
            # Read output in real-time
            for line in process.stdout:
                print(line, end='')
                stdout_lines.append(line)
            
            # Wait for completion
            process.wait()
            
            # Get any stderr
            stderr = process.stderr.read()
            if stderr:
                stderr_lines.append(stderr)
                print(stderr, end='')
            
            stdout = ''.join(stdout_lines)
            stderr = ''.join(stderr_lines)
            returncode = process.returncode
            
        else:
            # Silent execution
            process = subprocess.run(
                cmd,
                cwd=working_dir,
                capture_output=True,
                text=True
            )
            stdout = process.stdout
            stderr = process.stderr
            returncode = process.returncode
        
        runtime = time.time() - start_time
        
        # Parse output file from stdout
        output_file = None
        for line in stdout.split('\n'):
            if 'Output written to:' in line or 'file for output' in line:
                parts = line.split(':')
                if len(parts) > 1:
                    output_file = parts[-1].strip()
                    # Make it absolute path
                    if output_file and not os.path.isabs(output_file):
                        output_file = os.path.join(working_dir, output_file)
        
        success = (returncode == 0)
        
        if verbose:
            print("-" * 60)
            if success:
                print(f"✓ Simulation completed successfully in {runtime:.1f}s")
                if output_file:
                    print(f"  Output: {output_file}")
            else:
                print(f"✗ Simulation failed (return code: {returncode})")
        
        return {
            'success': success,
            'returncode': returncode,
            'stdout': stdout,
            'stderr': stderr,
            'runtime': runtime,
            'output_file': output_file
        }
        
    except FileNotFoundError:
        raise FileNotFoundError(
            f"VISIM executable not found: {visim_exe}\n"
            f"Make sure visim_f90 is in your PATH or provide full path"
        )
    except Exception as e:
        raise RuntimeError(f"Error running VISIM: {e}")


def run_visim_batch(parfiles, visim_exe='visim_f90', working_dir=None, verbose=True):
    """
    Run multiple VISIM simulations in sequence.
    
    Parameters
    ----------
    parfiles : list of str
        List of parameter file paths
    visim_exe : str, optional
        Path to VISIM executable
    working_dir : str, optional
        Working directory for simulations
    verbose : bool, optional
        Print output for each simulation
        
    Returns
    -------
    results : list of dict
        List of result dictionaries (see run_visim)
        
    Examples
    --------
    >>> # Run multiple simulations
    >>> parfiles = ['sim1.par', 'sim2.par', 'sim3.par']
    >>> results = run_visim_batch(parfiles)
    >>> 
    >>> # Check which succeeded
    >>> for i, result in enumerate(results):
    ...     if result['success']:
    ...         print(f"Simulation {i+1}: SUCCESS")
    ...     else:
    ...         print(f"Simulation {i+1}: FAILED")
    """
    results = []
    
    if verbose:
        print(f"\n{'='*60}")
        print(f"Running batch of {len(parfiles)} simulations")
        print(f"{'='*60}\n")
    
    for i, parfile in enumerate(parfiles):
        if verbose:
            print(f"\n[{i+1}/{len(parfiles)}] {parfile}")
        
        result = run_visim(parfile, visim_exe, working_dir, verbose)
        results.append(result)
        
        if not result['success'] and verbose:
            print(f"Warning: Simulation {i+1} failed, continuing...")
    
    # Summary
    if verbose:
        n_success = sum(1 for r in results if r['success'])
        n_failed = len(results) - n_success
        total_time = sum(r['runtime'] for r in results)
        
        print(f"\n{'='*60}")
        print(f"Batch Summary:")
        print(f"  Total: {len(results)}")
        print(f"  Success: {n_success}")
        print(f"  Failed: {n_failed}")
        print(f"  Total time: {total_time:.1f}s")
        print(f"{'='*60}\n")
    
    return results


def find_visim_executable():
    """
    Try to find VISIM executable in common locations.
    
    Returns
    -------
    exe_path : str or None
        Path to VISIM executable if found, None otherwise
        
    Examples
    --------
    >>> exe = find_visim_executable()
    >>> if exe:
    ...     print(f"Found VISIM at: {exe}")
    """
    # Common locations to check
    search_paths = [
        'visim_f90',  # In PATH
        './visim_f90',  # Current directory
        '../src_f90/visim_f90',  # Relative to examples
        '../../src_f90/visim_f90',  # From examples subdirectory
        '../visim_f90',  # Parent directory
        './src_f90/visim_f90',  # From repo root
    ]
    
    for path in search_paths:
        # Check if in PATH
        if path == 'visim_f90':
            try:
                result = subprocess.run(['which', 'visim_f90'], 
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    return result.stdout.strip()
            except:
                pass
        
        # Check if file exists
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return str(Path(path).resolve())
    
    return None
