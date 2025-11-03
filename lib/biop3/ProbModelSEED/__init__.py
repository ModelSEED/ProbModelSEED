"""
ProbModelSEED Python Package

Provides Python-based job system for metabolic model reconstruction
"""

__version__ = "1.0.0"

# Export main components for easy import
from .config import (
    get_config,
    set_config,
    conf,
    conf_int,
    conf_bool,
    conf_float,
    setconf,
    config_hash,
    ProbModelSEEDConfig
)

from .workspace_client import (
    WorkspaceClient,
    get_workspace_client,
    set_workspace_client,
    call_ws
)

__all__ = [
    # Config
    'get_config',
    'set_config',
    'conf',
    'conf_int',
    'conf_bool',
    'conf_float',
    'setconf',
    'config_hash',
    'ProbModelSEEDConfig',
    # Workspace
    'WorkspaceClient',
    'get_workspace_client',
    'set_workspace_client',
    'call_ws',
]
