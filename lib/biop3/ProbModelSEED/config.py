"""
Configuration management for ProbModelSEED

Replaces Perl Bio::KBase::utilities::conf() with Python implementation
Reads deploy.cfg and provides typed access to configuration values
"""

import os
import configparser
from pathlib import Path
from typing import Optional, Dict, Any


class ProbModelSEEDConfig:
    """Configuration manager for ProbModelSEED"""

    def __init__(self, config_file: Optional[str] = None):
        """
        Initialize configuration from file

        Args:
            config_file: Path to configuration file. If None, searches standard locations.
        """
        self.parser = configparser.ConfigParser()
        self._config_dict = None

        if config_file is None:
            config_file = self._find_config_file()

        self.config_file = Path(config_file)
        if not self.config_file.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_file}")

        self.parser.read(self.config_file)

    def _find_config_file(self) -> str:
        """Find configuration file in standard locations"""
        # Check environment variable first
        if 'PROBMODELSEED_CONFIG' in os.environ:
            return os.environ['PROBMODELSEED_CONFIG']

        # Check standard deployment location
        deployment_paths = [
            '/disks/p3dev2/deployment/deployment.cfg',
            '/disks/p3dev2/deployment/deploy.cfg',
            'deploy.cfg',
            '../deploy.cfg',
        ]

        for path in deployment_paths:
            if Path(path).exists():
                return path

        raise FileNotFoundError(
            "Could not find deploy.cfg. Set PROBMODELSEED_CONFIG environment variable."
        )

    def get(self, section: str, key: str, default: Any = None) -> Any:
        """
        Get configuration value

        Args:
            section: Configuration section (e.g., 'ProbModelSEED', 'Scheduler')
            key: Configuration key
            default: Default value if not found

        Returns:
            Configuration value as string, or default if not found
        """
        try:
            value = self.parser.get(section, key)
            # Handle special values
            if value.lower() in ('null', 'none', ''):
                return default
            return value
        except (configparser.NoSectionError, configparser.NoOptionError):
            return default

    def get_int(self, section: str, key: str, default: int = 0) -> int:
        """Get configuration value as integer"""
        value = self.get(section, key, default)
        if value is None:
            return default
        try:
            return int(value)
        except (ValueError, TypeError):
            return default

    def get_bool(self, section: str, key: str, default: bool = False) -> bool:
        """Get configuration value as boolean"""
        value = self.get(section, key, default)
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            return value.lower() in ('1', 'true', 'yes', 'on')
        return bool(value)

    def get_float(self, section: str, key: str, default: float = 0.0) -> float:
        """Get configuration value as float"""
        value = self.get(section, key, default)
        if value is None:
            return default
        try:
            return float(value)
        except (ValueError, TypeError):
            return default

    def set(self, section: str, key: str, value: Any):
        """
        Set configuration value (runtime only, not persisted)

        Args:
            section: Configuration section
            key: Configuration key
            value: Value to set
        """
        if not self.parser.has_section(section):
            self.parser.add_section(section)
        self.parser.set(section, key, str(value))
        # Invalidate cached dict
        self._config_dict = None

    def to_dict(self) -> Dict[str, Dict[str, str]]:
        """
        Convert configuration to nested dictionary

        Returns:
            Dictionary with structure {section: {key: value}}
        """
        if self._config_dict is None:
            self._config_dict = {
                section: dict(self.parser.items(section))
                for section in self.parser.sections()
            }
        return self._config_dict

    def sections(self):
        """Get list of configuration sections"""
        return self.parser.sections()

    def items(self, section: str):
        """Get all items in a section"""
        try:
            return dict(self.parser.items(section))
        except configparser.NoSectionError:
            return {}

    def has_section(self, section: str) -> bool:
        """Check if section exists"""
        return self.parser.has_section(section)

    def has_option(self, section: str, key: str) -> bool:
        """Check if option exists in section"""
        return self.parser.has_option(section, key)

    @classmethod
    def from_env(cls):
        """Create configuration from environment-specified file"""
        return cls()


# Global configuration instance
_global_config: Optional[ProbModelSEEDConfig] = None


def get_config() -> ProbModelSEEDConfig:
    """
    Get global configuration instance

    Returns:
        Global ProbModelSEEDConfig instance
    """
    global _global_config
    if _global_config is None:
        _global_config = ProbModelSEEDConfig.from_env()
    return _global_config


def set_config(config: ProbModelSEEDConfig):
    """
    Set global configuration instance

    Args:
        config: Configuration instance to use globally
    """
    global _global_config
    _global_config = config


def conf(section: str, key: str, default: Any = None) -> Any:
    """
    Get configuration value - drop-in replacement for Bio::KBase::utilities::conf()

    Args:
        section: Configuration section
        key: Configuration key
        default: Default value if not found

    Returns:
        Configuration value

    Example:
        >>> conf("Scheduler", "jobdirectory")
        '/disks/p3dev2/fba/'
    """
    return get_config().get(section, key, default)


def conf_int(section: str, key: str, default: int = 0) -> int:
    """Get configuration value as integer"""
    return get_config().get_int(section, key, default)


def conf_bool(section: str, key: str, default: bool = False) -> bool:
    """Get configuration value as boolean"""
    return get_config().get_bool(section, key, default)


def conf_float(section: str, key: str, default: float = 0.0) -> float:
    """Get configuration value as float"""
    return get_config().get_float(section, key, default)


def setconf(section: str, key: str, value: Any):
    """
    Set configuration value - drop-in replacement for Bio::KBase::utilities::setconf()

    Args:
        section: Configuration section
        key: Configuration key
        value: Value to set

    Example:
        >>> setconf("Scheduler", "jobid", 12345)
    """
    get_config().set(section, key, value)


def config_hash() -> Dict[str, Dict[str, str]]:
    """
    Get full configuration as dictionary

    Returns:
        Nested dictionary of all configuration values
    """
    return get_config().to_dict()
