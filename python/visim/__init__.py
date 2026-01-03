"""
VISIM - Volume Integration Sequential Simulation Python Interface

This module provides tools for working with VISIM parameter files,
data files, and simulation/estimation output.
"""

__version__ = "2.0.0"

from .parameters import VisimParams
from .data import read_eas, write_eas
from .output import read_visim_output, read_estimation_output
from .runner import run_visim, run_visim_batch, find_visim_executable

__all__ = [
    'VisimParams',
    'read_eas',
    'write_eas',
    'read_visim_output',
    'read_estimation_output',
    'run_visim',
    'run_visim_batch',
    'find_visim_executable',
]
