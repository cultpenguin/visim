"""
Module for reading and writing VISIM parameter files.
"""

import os


class VisimParams:
    """
    Class for reading, modifying, and writing VISIM parameter files.
    
    Attributes
    ----------
    All VISIM parameters are stored as attributes, including:
    - icond : int, conditioning type
    - datafl : str, conditioning data file
    - nsim : int, number of realizations
    - nx, ny, nz : int, grid dimensions
    - xmn, ymn, zmn : float, grid origin
    - xsiz, ysiz, zsiz : float, cell size
    - And many more...
    
    Examples
    --------
    >>> # Read a parameter file
    >>> params = VisimParams('conditional_estimation.par')
    >>> print(f"Grid: {params.nx} x {params.ny} x {params.nz}")
    >>> print(f"Number of realizations: {params.nsim}")
    
    >>> # Modify parameters
    >>> params.nsim = 100
    >>> params.outfl = 'new_output.out'
    
    >>> # Write to new file
    >>> params.write('new_params.par')
    """
    
    def __init__(self, filename=None):
        """
        Initialize VisimParams.
        
        Parameters
        ----------
        filename : str, optional
            Path to parameter file to read
        """
        # Set default values
        self._set_defaults()
        
        # Store the parameter lines for writing
        self._lines = []
        
        if filename is not None:
            self.read(filename)
    
    def _set_defaults(self):
        """Set default parameter values."""
        # Basic parameters
        self.icond = 0
        self.datafl = 'data.eas'
        self.icolx = 1
        self.icoly = 2
        self.icolz = 3
        self.icolvr = 4
        self.volgeomfl = 'dummy_volgeom.eas'
        self.volsumfl = 'dummy_volsum.eas'
        self.tmin = -1.0e21
        self.tmax = 1.0e21
        self.idbg = [0, -1, -1, -1, -1, 0, 0]
        self.outfl = 'visim.out'
        self.nsim = 1
        self.idrawopt = 0
        self.refhist_file = 'reference.eas'
        self.ibt = 1
        self.ibtw = 0
        
        # Grid
        self.nx = 50
        self.xmn = 0.0
        self.xsiz = 1.0
        self.ny = 50
        self.ymn = 0.0
        self.ysiz = 1.0
        self.nz = 1
        self.zmn = 0.0
        self.zsiz = 1.0
        
        # Random seed
        self.ixv = 69069
        
        # Search
        self.ndmin = 0
        self.ndmax = 12
        self.nodmax = 12
        
        # Kriging
        self.radius = 10.0
        self.radius1 = 10.0
        self.radius2 = 10.0
        self.sang1 = 0.0
        self.sang2 = 0.0
        self.sang3 = 0.0
        
        # Global statistics
        self.gmean = 0.0
        self.gvar = 1.0
        
        # Variogram
        self.nst = 1
        self.c0 = 0.0
        self.it = [1]
        self.cc = [1.0]
        self.ang1 = [0.0]
        self.ang2 = [0.0]
        self.ang3 = [0.0]
        self.aa = [10.0]
        self.aa1 = [10.0]
        self.aa2 = [10.0]
        
        # Tail extrapolation
        self.zmin = -10.0
        self.zmax = 10.0
        self.ltail = 1
        self.ltpar = 1.0
        self.utail = 1
        self.utpar = 1.0
    
    def read(self, filename):
        """
        Read parameters from a VISIM parameter file.
        
        Parameters
        ----------
        filename : str
            Path to parameter file
        """
        with open(filename, 'r') as f:
            lines = f.readlines()
        
        self._lines = lines
        idx = 0
        
        # Skip header lines until "START OF PARAMETERS:"
        while idx < len(lines):
            if 'START OF PARAMETERS' in lines[idx]:
                idx += 1
                break
            idx += 1
        
        # Line 1: conditioning type
        self.icond = int(lines[idx].split()[0])
        idx += 1
        
        # Line 2: data file
        self.datafl = lines[idx].split()[0]
        idx += 1
        
        # Line 3: columns
        parts = lines[idx].split()
        self.icolx = int(parts[0])
        self.icoly = int(parts[1])
        self.icolz = int(parts[2])
        self.icolvr = int(parts[3])
        idx += 1
        
        # Line 4: volume geometry file
        self.volgeomfl = lines[idx].split()[0]
        idx += 1
        
        # Line 5: volume summary file
        self.volsumfl = lines[idx].split()[0]
        idx += 1
        
        # Line 6: trimming limits
        parts = lines[idx].split()
        self.tmin = float(parts[0])
        self.tmax = float(parts[1])
        idx += 1
        
        # Line 7: debugging levels
        parts = lines[idx].split()
        self.idbg = [int(x) for x in parts[:7]]
        idx += 1
        
        # Line 8: output file
        self.outfl = lines[idx].split()[0]
        idx += 1
        
        # Line 9: number of realizations
        self.nsim = int(lines[idx].split()[0])
        idx += 1
        
        # Line 10: ccdf type
        self.idrawopt = int(lines[idx].split()[0])
        idx += 1
        
        # Line 11: reference histogram file
        self.refhist_file = lines[idx].split()[0]
        idx += 1
        
        # Line 12: histogram columns
        parts = lines[idx].split()
        self.ibt = int(parts[0])
        self.ibtw = int(parts[1])
        idx += 1
        
        # Lines 13-15: DSSIM parameters (skip for now)
        idx += 3
        
        # Line 16: grid nx
        parts = lines[idx].split()
        self.nx = int(parts[0])
        self.xmn = float(parts[1])
        self.xsiz = float(parts[2])
        idx += 1
        
        # Line 17: grid ny
        parts = lines[idx].split()
        self.ny = int(parts[0])
        self.ymn = float(parts[1])
        self.ysiz = float(parts[2])
        idx += 1
        
        # Line 18: grid nz
        parts = lines[idx].split()
        self.nz = int(parts[0])
        self.zmn = float(parts[1])
        self.zsiz = float(parts[2])
        idx += 1
        
        # Line 19: random seed
        self.ixv = int(lines[idx].split()[0])
        idx += 1
        
        # Line 20: min and max data
        parts = lines[idx].split()
        self.ndmin = int(parts[0])
        self.ndmax = int(parts[1])
        idx += 1
        
        # Line 21: max previously simulated nodes
        self.nodmax = int(lines[idx].split()[0])
        idx += 1
        
        # Line 22: volume neighborhood (skip)
        idx += 1
        
        # Line 23: random path
        idx += 1
        
        # Line 24: assign data to nodes
        idx += 1
        
        # Line 25: max data per octant
        idx += 1
        
        # Line 26: search radii
        parts = lines[idx].split()
        self.radius = float(parts[0])
        self.radius1 = float(parts[1])
        self.radius2 = float(parts[2])
        idx += 1
        
        # Line 27: search angles
        parts = lines[idx].split()
        self.sang1 = float(parts[0])
        self.sang2 = float(parts[1])
        self.sang3 = float(parts[2])
        idx += 1
        
        # Line 28: global mean and variance
        parts = lines[idx].split()
        self.gmean = float(parts[0])
        self.gvar = float(parts[1])
        idx += 1
        
        # Line 29: nst, nugget
        parts = lines[idx].split()
        self.nst = int(parts[0])
        self.c0 = float(parts[1])
        idx += 1
        
        # Variogram structures
        self.it = []
        self.cc = []
        self.ang1 = []
        self.ang2 = []
        self.ang3 = []
        self.aa = []
        self.aa1 = []
        self.aa2 = []
        
        for i in range(self.nst):
            # Structure parameters
            parts = lines[idx].split()
            self.it.append(int(parts[0]))
            self.cc.append(float(parts[1]))
            self.ang1.append(float(parts[2]))
            self.ang2.append(float(parts[3]))
            self.ang3.append(float(parts[4]))
            idx += 1
            
            # Ranges
            parts = lines[idx].split()
            self.aa.append(float(parts[0]))
            self.aa1.append(float(parts[1]))
            self.aa2.append(float(parts[2]))
            idx += 1
        
        # Tail extrapolation
        parts = lines[idx].split()
        self.zmin = float(parts[0])
        self.zmax = float(parts[1])
        idx += 1
        
        parts = lines[idx].split()
        self.ltail = int(parts[0])
        self.ltpar = float(parts[1])
        idx += 1
        
        parts = lines[idx].split()
        self.utail = int(parts[0])
        self.utpar = float(parts[1])
    
    def write(self, filename):
        """
        Write parameters to a VISIM parameter file.
        
        Parameters
        ----------
        filename : str
            Path to output parameter file
        """
        with open(filename, 'w') as f:
            f.write("                  Parameters for VISIM\n")
            f.write("                  ********************\n")
            f.write("\n")
            f.write("START OF PARAMETERS:\n")
            
            # Write all parameters
            f.write(f"{self.icond}                             - conditional simulation (0=no,1=p+v,2=p,3=v)\n")
            f.write(f"{self.datafl}                 - file with conditioning data\n")
            f.write(f"{self.icolx} {self.icoly} {self.icolz} {self.icolvr}                       - columns for X,Y,Z,val\n")
            f.write(f"{self.volgeomfl}            - Geometry of volume\n")
            f.write(f"{self.volsumfl}              - Summary of volgeom.eas\n")
            f.write(f"{self.tmin:.1e}   {self.tmax:.1e}              - trimming limits\n")
            f.write(f"{' '.join(map(str, self.idbg))}             - debugging level\n")
            f.write(f"{self.outfl}             - file for output\n")
            f.write(f"{self.nsim}                             - number of realizations\n")
            f.write(f"{self.idrawopt}                             - ccdf type: 0=Gaussian, 1=DSSIM\n")
            f.write(f"{self.refhist_file}                 - reference histogram\n")
            f.write(f"{self.ibt}    {self.ibtw}                        - columns for variable and weights\n")
            f.write(f"-3.5 3.5 100                  - min_Gmean,max_Gmean,n_Gmean\n")
            f.write(f"0 2 100                       - min_Gvar,max_Gvar,n_Gvar\n")
            f.write(f"170 0                         - nQ (number of quantiles)\n")
            f.write(f"{self.nx}   {self.xmn}   {self.xsiz}                - nx,xmn,xsiz\n")
            f.write(f"{self.ny}   {self.ymn}   {self.ysiz}                - ny,ymn,ysiz\n")
            f.write(f"{self.nz}    {self.zmn}   {self.zsiz}                - nz,zmn,zsiz\n")
            f.write(f"{self.ixv}                         - random number seed\n")
            f.write(f"{self.ndmin}    {self.ndmax}                       - min and max data for kriging\n")
            f.write(f"{self.nodmax}                            - max previously simulated nodes\n")
            f.write(f"0 8 0.001                     - Volume Neighborhood\n")
            f.write(f"1                             - Random Path (1=independent)\n")
            f.write(f"1                             - assign data to nodes (1=yes)\n")
            f.write(f"0                             - maximum data per octant\n")
            f.write(f"{self.radius}  {self.radius1}  {self.radius2}              - maximum search radii\n")
            f.write(f"{self.sang1}   {self.sang2}   {self.sang3}               - angles for search ellipsoid\n")
            f.write(f"{self.gmean}  {self.gvar}                     - global mean and variance\n")
            f.write(f"{self.nst}    {self.c0}                     - nst, nugget effect\n")
            
            for i in range(self.nst):
                f.write(f"{self.it[i]}    {self.cc[i]}  {self.ang1[i]}   {self.ang2[i]}   {self.ang3[i]}    - it,cc,ang1,ang2,ang3\n")
                f.write(f"         {self.aa[i]} {self.aa1[i]}  {self.aa2[i]}       - a_hmax, a_hmin, a_vert\n")
            
            f.write(f"{self.zmin}   {self.zmax}                  - zmin,zmax (tail)\n")
            f.write(f"{self.ltail}       {self.ltpar}                   - lower tail option, parameter\n")
            f.write(f"{self.utail}      {self.utpar}                   - upper tail option, parameter\n")
    
    def __repr__(self):
        """String representation."""
        return (f"VisimParams(grid={self.nx}x{self.ny}x{self.nz}, "
                f"nsim={self.nsim}, "
                f"mean={self.gmean}, var={self.gvar})")
