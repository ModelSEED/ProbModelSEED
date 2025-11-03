"""
PATRIC Workspace API Client

Lightweight Python wrapper for PATRIC Workspace operations
Replaces Bio::ModelSEED::patricenv::call_ws() Perl calls
"""

import os
import json
import requests
from typing import Optional, Dict, List, Any, Tuple
from pathlib import Path

from .config import conf


class WorkspaceClient:
    """Client for PATRIC Workspace API"""

    def __init__(self, url: Optional[str] = None, token: Optional[str] = None):
        """
        Initialize workspace client

        Args:
            url: Workspace service URL. If None, reads from config.
            token: Authentication token. If None, reads from environment.
        """
        self.url = url or conf("ProbModelSEED", "workspace-url")
        if not self.url:
            raise ValueError("Workspace URL not configured")

        self.token = token or self._get_token()
        if not self.token:
            raise ValueError("Authentication token not found")

        self.headers = {
            'Authorization': self.token,
            'Content-Type': 'application/json'
        }

    def _get_token(self) -> Optional[str]:
        """Get authentication token from environment or file"""
        # Check environment variable
        if 'KB_AUTH_TOKEN' in os.environ:
            return os.environ['KB_AUTH_TOKEN']
        if 'P3_AUTH_TOKEN' in os.environ:
            return os.environ['P3_AUTH_TOKEN']

        # Check token file
        token_file = Path.home() / '.patric_token'
        if token_file.exists():
            return token_file.read_text().strip()

        return None

    def _call(self, method: str, params: Dict[str, Any]) -> Any:
        """
        Make RPC call to workspace service

        Args:
            method: Workspace method name
            params: Method parameters

        Returns:
            Response data

        Raises:
            requests.HTTPError: On HTTP errors
            ValueError: On API errors
        """
        response = requests.post(
            self.url,
            headers=self.headers,
            json=params,
            timeout=300
        )

        if response.status_code != 200:
            raise requests.HTTPError(
                f"Workspace call failed ({response.status_code}): {response.text}"
            )

        # Some workspace methods return direct JSON, not JSON-RPC
        try:
            data = response.json()
            if isinstance(data, dict) and 'error' in data:
                raise ValueError(f"Workspace error: {data['error']}")
            return data
        except json.JSONDecodeError:
            return response.text

    def get(
        self,
        objects: List[str],
        metadata_only: bool = False,
        adminmode: Optional[bool] = None
    ) -> List[List[Any]]:
        """
        Get objects from workspace

        Args:
            objects: List of object paths
            metadata_only: If True, only return metadata
            adminmode: If True, use admin mode

        Returns:
            List of [metadata, data] pairs

        Example:
            >>> client.get(['/user/models/model1'])
            [[[meta...], {data...}]]
        """
        params = {
            'objects': objects,
            'metadata_only': 1 if metadata_only else 0
        }
        if adminmode is not None:
            params['adminmode'] = 1 if adminmode else 0

        return self._call('get', params)

    def get_object(self, path: str, metadata_only: bool = False) -> Tuple[List, Any]:
        """
        Get a single object from workspace

        Args:
            path: Object path
            metadata_only: If True, only return metadata

        Returns:
            Tuple of (metadata, data)

        Example:
            >>> meta, data = client.get_object('/user/models/model1')
        """
        result = self.get([path], metadata_only=metadata_only)
        if not result or not result[0]:
            raise ValueError(f"Object not found: {path}")
        return result[0][0]  # Returns [metadata, data] pair

    def get_object_data(self, path: str) -> Any:
        """
        Get object data only (no metadata)

        Args:
            path: Object path

        Returns:
            Object data

        Example:
            >>> genome = client.get_object_data('/user/genomes/genome1')
        """
        meta, data = self.get_object(path, metadata_only=False)
        return data

    def get_object_meta(self, path: str) -> List:
        """
        Get object metadata only

        Args:
            path: Object path

        Returns:
            Object metadata

        Example:
            >>> meta = client.get_object_meta('/user/genomes/genome1')
        """
        result = self.get([path], metadata_only=True)
        if not result or not result[0]:
            raise ValueError(f"Object not found: {path}")
        return result[0][0][7]  # Metadata is at index 7

    def create(
        self,
        objects: List[List],
        overwrite: bool = False,
        createUploadNodes: bool = False
    ) -> Any:
        """
        Create/save objects in workspace

        Args:
            objects: List of [path, type, metadata, data] tuples
            overwrite: If True, overwrite existing objects
            createUploadNodes: If True, create upload nodes

        Returns:
            Response data

        Example:
            >>> client.create([['/user/models/model1', 'FBAModel', {}, model_data]])
        """
        params = {
            'objects': objects,
            'overwrite': 1 if overwrite else 0
        }
        if createUploadNodes:
            params['createUploadNodes'] = 1

        return self._call('create', params)

    def save_object(
        self,
        path: str,
        object_type: str,
        data: Any,
        metadata: Optional[Dict] = None,
        overwrite: bool = True
    ) -> Any:
        """
        Save a single object to workspace

        Args:
            path: Object path
            object_type: Object type (e.g., 'FBAModel', 'genome')
            data: Object data
            metadata: Object metadata
            overwrite: If True, overwrite existing object

        Returns:
            Response data

        Example:
            >>> client.save_object(
            ...     '/user/models/model1',
            ...     'FBAModel',
            ...     model_data,
            ...     {'status': 'complete'}
            ... )
        """
        objects = [[path, object_type, metadata or {}, data]]
        return self.create(objects, overwrite=overwrite)

    def update_metadata(self, objects: List[List]) -> Any:
        """
        Update metadata for objects

        Args:
            objects: List of [path, metadata] pairs

        Returns:
            Response data

        Example:
            >>> client.update_metadata([
            ...     ['/user/models/model1', {'status': 'complete'}]
            ... ])
        """
        params = {'objects': objects}
        return self._call('update_metadata', params)

    def set_metadata(self, path: str, metadata: Dict) -> Any:
        """
        Set metadata for a single object

        Args:
            path: Object path
            metadata: Metadata dictionary

        Returns:
            Response data
        """
        return self.update_metadata([[path, metadata]])

    def ls(
        self,
        paths: List[str],
        excludeDirectories: bool = False,
        excludeObjects: bool = False,
        recursive: bool = False,
        query: Optional[Dict] = None
    ) -> Any:
        """
        List workspace contents

        Args:
            paths: List of paths to list
            excludeDirectories: If True, exclude directories
            excludeObjects: If True, exclude objects
            recursive: If True, list recursively
            query: Query filter

        Returns:
            Directory listings

        Example:
            >>> client.ls(['/user/models/'])
        """
        params = {
            'paths': paths,
            'excludeDirectories': 1 if excludeDirectories else 0,
            'excludeObjects': 1 if excludeObjects else 0,
            'recursive': 1 if recursive else 0
        }
        if query:
            params['query'] = query

        return self._call('ls', params)

    def delete(self, objects: List[str], force: bool = False, deleteDirectories: bool = False) -> Any:
        """
        Delete objects from workspace

        Args:
            objects: List of object paths
            force: If True, force deletion
            deleteDirectories: If True, delete directories

        Returns:
            Response data

        Example:
            >>> client.delete(['/user/models/model1'])
        """
        params = {
            'objects': objects,
            'force': 1 if force else 0,
            'deleteDirectories': 1 if deleteDirectories else 0
        }
        return self._call('delete', params)

    def copy(self, objects: List[List], overwrite: bool = False) -> Any:
        """
        Copy objects in workspace

        Args:
            objects: List of [source, destination] pairs
            overwrite: If True, overwrite existing objects

        Returns:
            Response data

        Example:
            >>> client.copy([['/user/models/model1', '/user/models/model2']])
        """
        params = {
            'objects': objects,
            'overwrite': 1 if overwrite else 0
        }
        return self._call('copy', params)

    def get_download_url(self, objects: List[str]) -> Dict[str, str]:
        """
        Get download URLs for objects

        Args:
            objects: List of object paths

        Returns:
            Dictionary mapping paths to download URLs

        Example:
            >>> urls = client.get_download_url(['/user/models/model1'])
        """
        params = {'objects': objects}
        return self._call('get_download_url', params)

    @classmethod
    def from_config(cls, config_dict: Optional[Dict] = None):
        """
        Create client from configuration

        Args:
            config_dict: Configuration dictionary. If None, uses global config.

        Returns:
            WorkspaceClient instance

        Example:
            >>> from .config import get_config
            >>> client = WorkspaceClient.from_config(get_config().to_dict())
        """
        if config_dict is None:
            url = conf("ProbModelSEED", "workspace-url")
        else:
            url = config_dict.get('ProbModelSEED', {}).get('workspace-url')

        return cls(url=url)


# Global workspace client instance
_global_client: Optional[WorkspaceClient] = None


def get_workspace_client() -> WorkspaceClient:
    """
    Get global workspace client instance

    Returns:
        Global WorkspaceClient instance
    """
    global _global_client
    if _global_client is None:
        _global_client = WorkspaceClient.from_config()
    return _global_client


def set_workspace_client(client: WorkspaceClient):
    """
    Set global workspace client instance

    Args:
        client: WorkspaceClient instance to use globally
    """
    global _global_client
    _global_client = client


def call_ws(method: str, params: Dict[str, Any]) -> Any:
    """
    Call workspace method - drop-in replacement for Bio::ModelSEED::patricenv::call_ws()

    Args:
        method: Method name (e.g., 'get', 'create', 'update_metadata')
        params: Method parameters

    Returns:
        Response data

    Example:
        >>> call_ws('get', {'objects': ['/user/models/model1']})
    """
    client = get_workspace_client()
    return client._call(method, params)
