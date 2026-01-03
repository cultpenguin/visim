"""
Module for reading VISIM simulation and estimation output files.
"""

import numpy as np


def read_visim_output(filename):
    """
    Read VISIM simulation or estimation output file.
    
    Parameters
    ----------
    filename : str
        Path to VISIM output file (*.out)
        
    Returns
    -------
    result : dict
        Dictionary containing:
        - 'n_realizations': int, number of realizations
        - 'nx', 'ny', 'nz': int, grid dimensions
        - 'n_nodes': int, total number of grid nodes
        - 'data': numpy array of shape (n_realizations, n_nodes)
                  For single realization: shape (n_nodes,)
        
    Examples
    --------
    >>> # Read estimation output (1 realization)
    >>> result = read_visim_output('conditional_estimation.out')
    >>> print(f"Grid: {result['nx']} x {result['ny']} x {result['nz']}")
    >>> print(f"Values shape: {result['data'].shape}")
    
    >>> # Read simulation output (100 realizations)
    >>> result = read_visim_output('conditional_simulation.out')
    >>> print(f"Number of realizations: {result['n_realizations']}")
    >>> print(f"Shape: {result['data'].shape}")  # (100, 1600)
    """
    with open(filename, 'r') as f:
        # Skip title line
        title = f.readline().strip()
        
        # Read number of realizations
        line = f.readline().strip()
        n_real = int(line.split(':')[1].strip())
        
        # Read grid dimensions
        line = f.readline().strip()
        parts = line.split(':')[1].strip().split('x')
        nx = int(parts[0].strip())
        ny = int(parts[1].strip())
        nz = int(parts[2].strip())
        
        n_nodes = nx * ny * nz
        
        # Read data
        values = []
        for line in f:
            line = line.strip()
            if line and not line.startswith('*'):
                try:
                    values.append(float(line))
                except ValueError:
                    # Skip lines that can't be converted to float
                    pass
        
        data = np.array(values)
        
        # Reshape data
        if n_real == 1:
            # Single realization - return 1D array
            if len(data) != n_nodes:
                raise ValueError(f"Expected {n_nodes} values, got {len(data)}")
        else:
            # Multiple realizations - return 2D array
            expected_total = n_real * n_nodes
            if len(data) != expected_total:
                raise ValueError(f"Expected {expected_total} values, got {len(data)}")
            data = data.reshape(n_real, n_nodes)
    
    return {
        'n_realizations': n_real,
        'nx': nx,
        'ny': ny,
        'nz': nz,
        'n_nodes': n_nodes,
        'data': data
    }


def read_estimation_output(filename):
    """
    Read VISIM estimation output file (with mean and variance).
    
    The estimation output file contains both kriged mean and variance.
    
    Parameters
    ----------
    filename : str
        Path to estimation output file (visim_estimation_*.out)
        
    Returns
    -------
    result : dict
        Dictionary containing:
        - 'n_nodes': int, number of grid nodes
        - 'mean': numpy array of kriged means
        - 'variance': numpy array of kriging variances
        
    Examples
    --------
    >>> result = read_estimation_output('visim_estimation_conditional_estimation.out')
    >>> print(f"Mean values: {result['mean']}")
    >>> print(f"Variance: {result['variance']}")
    >>> print(f"Std dev: {np.sqrt(result['variance'])}")
    """
    with open(filename, 'r') as f:
        # Read header
        title = f.readline().strip()
        n_vars = int(f.readline().strip())
        
        var_names = []
        for _ in range(n_vars):
            var_names.append(f.readline().strip())
        
        # Read data
        mean_list = []
        var_list = []
        for line in f:
            line = line.strip()
            if line:
                values = [float(x) for x in line.split()]
                if len(values) >= 2:
                    mean_list.append(values[0])
                    var_list.append(values[1])
        
        mean = np.array(mean_list)
        variance = np.array(var_list)
    
    return {
        'n_nodes': len(mean),
        'mean': mean,
        'variance': variance
    }


def reshape_to_grid(data, nx, ny, nz):
    """
    Reshape 1D VISIM output to 3D grid.
    
    VISIM stores data in column-major order (Fortran style):
    fastest varying index is X, then Y, then Z.
    
    Parameters
    ----------
    data : numpy array
        1D array of values
    nx, ny, nz : int
        Grid dimensions
        
    Returns
    -------
    grid : numpy array
        3D array of shape (nx, ny, nz)
        
    Examples
    --------
    >>> result = read_visim_output('simulation.out')
    >>> grid = reshape_to_grid(result['data'], 
    ...                        result['nx'], result['ny'], result['nz'])
    >>> print(grid.shape)  # (40, 40, 1)
    >>> print(grid[10, 10, 0])  # Value at grid node (10, 10, 0)
    """
    # VISIM uses Fortran ordering (column-major)
    return data.reshape((nx, ny, nz), order='F')


def get_statistics(data):
    """
    Calculate statistics from VISIM output.
    
    Parameters
    ----------
    data : numpy array
        Can be 1D (single realization) or 2D (multiple realizations)
        
    Returns
    -------
    stats : dict
        Dictionary containing:
        - 'mean': overall mean
        - 'std': overall standard deviation
        - 'var': overall variance
        - 'min': minimum value
        - 'max': maximum value
        - For multiple realizations also includes:
          - 'realization_means': mean of each realization
          - 'realization_stds': std of each realization
          
    Examples
    --------
    >>> result = read_visim_output('conditional_simulation.out')
    >>> stats = get_statistics(result['data'])
    >>> print(f"Overall mean: {stats['mean']:.2f}")
    >>> print(f"Overall std: {stats['std']:.2f}")
    >>> print(f"Mean per realization: {stats['realization_means']}")
    """
    stats = {
        'mean': np.mean(data),
        'std': np.std(data),
        'var': np.var(data),
        'min': np.min(data),
        'max': np.max(data)
    }
    
    # For multiple realizations
    if data.ndim == 2:
        stats['realization_means'] = np.mean(data, axis=1)
        stats['realization_stds'] = np.std(data, axis=1)
    
    return stats
