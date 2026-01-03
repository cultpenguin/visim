"""
Module for reading and writing GEO-EAS formatted data files.
"""

import numpy as np


def read_eas(filename):
    """
    Read a GEO-EAS formatted data file.
    
    Parameters
    ----------
    filename : str
        Path to the GEO-EAS file
        
    Returns
    -------
    data : dict
        Dictionary containing:
        - 'title': str, title line from file
        - 'n_vars': int, number of variables
        - 'var_names': list of str, variable names
        - 'data': numpy array of shape (n_points, n_vars)
        
    Examples
    --------
    >>> data = read_eas('conditioning_data.eas')
    >>> print(data['title'])
    >>> print(data['var_names'])
    >>> print(data['data'])
    """
    with open(filename, 'r') as f:
        # Read title
        title = f.readline().strip()
        
        # Read number of variables
        n_vars = int(f.readline().strip())
        
        # Read variable names
        var_names = []
        for _ in range(n_vars):
            var_names.append(f.readline().strip())
        
        # Read data
        data_list = []
        for line in f:
            line = line.strip()
            if line:  # Skip empty lines
                values = [float(x) for x in line.split()]
                data_list.append(values)
        
        data_array = np.array(data_list)
    
    return {
        'title': title,
        'n_vars': n_vars,
        'var_names': var_names,
        'data': data_array
    }


def write_eas(filename, data, title=None, var_names=None):
    """
    Write data to a GEO-EAS formatted file.
    
    Parameters
    ----------
    filename : str
        Path to output file
    data : numpy array
        Data array of shape (n_points, n_vars) or (n_points,)
    title : str, optional
        Title line for the file. Default: "Data"
    var_names : list of str, optional
        Variable names. Default: ['var1', 'var2', ...]
        
    Examples
    --------
    >>> import numpy as np
    >>> data = np.array([[1.0, 2.0, 3.0, 10.5],
    ...                  [4.0, 5.0, 6.0, 12.3]])
    >>> write_eas('output.eas', data, 
    ...           title='My Data',
    ...           var_names=['x', 'y', 'z', 'value'])
    """
    # Handle 1D arrays
    if data.ndim == 1:
        data = data.reshape(-1, 1)
    
    n_points, n_vars = data.shape
    
    # Set defaults
    if title is None:
        title = "Data"
    if var_names is None:
        var_names = [f'var{i+1}' for i in range(n_vars)]
    
    # Write file
    with open(filename, 'w') as f:
        # Write title
        f.write(f"{title}\n")
        
        # Write number of variables
        f.write(f"{n_vars}\n")
        
        # Write variable names
        for name in var_names:
            f.write(f"{name}\n")
        
        # Write data
        for row in data:
            f.write(' '.join([f'{x:.10f}' for x in row]) + '\n')


def read_conditioning_data(filename):
    """
    Read conditioning data from a GEO-EAS file.
    
    Convenience function that returns data in a more accessible format.
    
    Parameters
    ----------
    filename : str
        Path to the conditioning data file
        
    Returns
    -------
    points : dict
        Dictionary with keys:
        - 'x', 'y', 'z': numpy arrays of coordinates
        - 'value': numpy array of values
        - 'n_points': number of data points
        
    Examples
    --------
    >>> points = read_conditioning_data('conditioning_data.eas')
    >>> print(f"Number of points: {points['n_points']}")
    >>> print(f"X coordinates: {points['x']}")
    >>> print(f"Values: {points['value']}")
    """
    data_dict = read_eas(filename)
    data = data_dict['data']
    
    if data.shape[1] < 4:
        raise ValueError(f"Expected at least 4 columns (x,y,z,value), got {data.shape[1]}")
    
    return {
        'x': data[:, 0],
        'y': data[:, 1],
        'z': data[:, 2],
        'value': data[:, 3],
        'n_points': len(data)
    }
