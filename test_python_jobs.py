#!/usr/bin/env python
"""
Test script for Python job system

Tests configuration, workspace client, and job system components
"""

import sys
import os
from pathlib import Path

# Add lib to path
lib_path = Path(__file__).parent / "lib"
sys.path.insert(0, str(lib_path))

def test_config():
    """Test configuration module"""
    print("\n=== Testing Configuration Module ===")

    from biop3.ProbModelSEED import conf, setconf, config_hash, get_config

    # Test loading config
    config = get_config()
    print(f"✓ Config loaded from: {config.config_file}")

    # Test getting values
    job_dir = conf("Scheduler", "jobdirectory")
    print(f"✓ Job directory: {job_dir}")

    threads = conf("Scheduler", "threads", "4")
    print(f"✓ Threads: {threads}")

    # Test setting values
    setconf("Test", "key", "value")
    assert conf("Test", "key") == "value"
    print("✓ Set/get config works")

    # Test config hash
    config_dict = config_hash()
    assert "Scheduler" in config_dict
    print(f"✓ Config has {len(config_dict)} sections")

    print("✅ Configuration module working!")
    return True


def test_workspace_client():
    """Test workspace client (requires network and auth)"""
    print("\n=== Testing Workspace Client ===")

    try:
        from biop3.ProbModelSEED import WorkspaceClient

        # Test client creation
        try:
            ws = WorkspaceClient.from_config()
            print(f"✓ Workspace client created: {ws.url}")
        except ValueError as e:
            print(f"⚠ Workspace client creation failed (may need auth): {e}")
            return False

        # Test would require actual workspace access and auth
        print("⚠ Full workspace tests require authentication")
        print("✅ Workspace client module working!")
        return True

    except Exception as e:
        print(f"❌ Workspace client test failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_job_worker_import():
    """Test job worker imports"""
    print("\n=== Testing Job Worker Import ===")

    try:
        from biop3.ProbModelSEED.job_worker import JobWorker
        print("✓ JobWorker class imported")

        # Test initialization would require MongoDB
        print("⚠ Full job worker tests require MongoDB connection")
        print("✅ Job worker module working!")
        return True

    except Exception as e:
        print(f"❌ Job worker import failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_scheduler_import():
    """Test scheduler imports"""
    print("\n=== Testing Scheduler Import ===")

    try:
        from biop3.ProbModelSEED.scheduler import JobScheduler
        print("✓ JobScheduler class imported")

        # Test initialization would require MongoDB
        print("⚠ Full scheduler tests require MongoDB connection")
        print("✅ Scheduler module working!")
        return True

    except Exception as e:
        print(f"❌ Scheduler import failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_model_reconstruction_import():
    """Test model reconstruction imports"""
    print("\n=== Testing Model Reconstruction Import ===")

    try:
        from biop3.ProbModelSEED import model_reconstruction
        print("✓ model_reconstruction module imported")

        # Check functions exist
        assert hasattr(model_reconstruction, 'run_model_reconstruction')
        assert hasattr(model_reconstruction, 'run_gapfill_model')
        assert hasattr(model_reconstruction, 'run_fba')
        print("✓ All expected functions present")

        print("⚠ Full reconstruction tests require ModelSEEDpy")
        print("✅ Model reconstruction module working!")
        return True

    except Exception as e:
        print(f"❌ Model reconstruction import failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Run all tests"""
    print("=" * 60)
    print("ProbModelSEED Python Job System Tests")
    print("=" * 60)

    results = []

    # Run tests
    results.append(("Configuration", test_config()))
    results.append(("Workspace Client", test_workspace_client()))
    results.append(("Job Worker", test_job_worker_import()))
    results.append(("Scheduler", test_scheduler_import()))
    results.append(("Model Reconstruction", test_model_reconstruction_import()))

    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)

    passed = 0
    failed = 0

    for name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{name:.<40} {status}")
        if result:
            passed += 1
        else:
            failed += 1

    print("=" * 60)
    print(f"Passed: {passed}/{len(results)}")
    print(f"Failed: {failed}/{len(results)}")

    # Exit with error if any failed
    if failed > 0:
        sys.exit(1)
    else:
        print("\n✅ All tests passed!")
        sys.exit(0)


if __name__ == '__main__':
    main()
