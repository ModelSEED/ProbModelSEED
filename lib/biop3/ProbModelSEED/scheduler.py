"""
Job Scheduler for ProbModelSEED

Replaces scheduler.pl with Python implementation
Monitors and dispatches jobs from MongoDB queue
"""

import os
import sys
import time
import signal
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from pymongo import MongoClient
import psutil

from .config import conf, get_config


class JobScheduler:
    """Main job scheduler daemon"""

    def __init__(self, config_dict: Optional[Dict] = None):
        """
        Initialize job scheduler

        Args:
            config_dict: Configuration dictionary. If None, uses global config.
        """
        if config_dict is None:
            config_dict = get_config().to_dict()

        self.config = config_dict

        # Get configuration
        self.job_dir_base = Path(conf("Scheduler", "jobdirectory", "/tmp/fba"))
        self.max_threads = int(conf("Scheduler", "threads", "4"))
        self.msurl = conf("Scheduler", "msurl")
        self.worker_executable = conf("Scheduler", "python_worker",
                                      "python -m biop3.ProbModelSEED.job_worker")

        # Setup directories
        self.job_dir = self.job_dir_base / "jobs"
        self.error_dir = self.job_dir_base / "errors"
        self.output_dir = self.job_dir_base / "output"

        for directory in [self.job_dir, self.error_dir, self.output_dir]:
            directory.mkdir(parents=True, exist_ok=True)

        # Setup MongoDB connection
        mongo_host = conf("ProbModelSEED", "mongodb-host", "localhost")
        mongo_user = conf("ProbModelSEED", "mongodb-user")
        mongo_pwd = conf("ProbModelSEED", "mongodb-pwd")

        if mongo_user and mongo_user not in ('null', 'none', ''):
            connection_string = f"mongodb://{mongo_user}:{mongo_pwd}@{mongo_host}/"
        else:
            connection_string = f"mongodb://{mongo_host}/"

        print(f"Connecting to MongoDB at {mongo_host}")
        self.mongo_client = MongoClient(connection_string)
        self.db = self.mongo_client.modelseed
        self.jobs_collection = self.db.jobs
        self.events_collection = self.db.events

        # Write scheduler PID
        self.pid_file = self.job_dir_base / "schedulerPID"
        self.pid_file.write_text(str(os.getpid()))

        # Track running state
        self.running = True

        # Setup signal handlers
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)

        print(f"Scheduler initialized:")
        print(f"  Job directory: {self.job_dir}")
        print(f"  Max threads: {self.max_threads}")
        print(f"  Worker: {self.worker_executable}")

    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        print(f"\nReceived signal {signum}, shutting down gracefully...")
        self.running = False

    def monitor_loop(self):
        """Main scheduler monitoring loop"""
        print("Starting scheduler monitoring loop")
        iteration = 0

        while self.running:
            iteration += 1
            print(f"\n--- Scheduler iteration {iteration} at {datetime.now()} ---")

            try:
                # 1. Check running jobs and clean up dead ones
                running_jobs = self.check_running_jobs()
                print(f"  Currently running: {len(running_jobs)} jobs")

                # 2. Queue new jobs if slots available
                open_slots = self.max_threads - len(running_jobs)
                if open_slots > 0:
                    queued = self.queue_new_jobs(open_slots)
                    print(f"  Queued {queued} new jobs (had {open_slots} open slots)")
                else:
                    print(f"  No open slots (max={self.max_threads})")

                # 3. Cleanup old files
                if iteration % 10 == 0:  # Every 10 iterations
                    print("  Cleaning up old files...")
                    self.cleanup_old_files()

            except Exception as e:
                print(f"Error in scheduler iteration: {e}")
                import traceback
                traceback.print_exc()

            # Sleep before next iteration
            if self.running:
                print(f"  Sleeping for 60 seconds...")
                time.sleep(60)

        print("Scheduler stopped")

    def check_running_jobs(self) -> List[Dict]:
        """
        Check running jobs and mark dead ones as failed

        Returns:
            List of still-running jobs
        """
        # Find jobs marked as running in database
        jobs = list(self.jobs_collection.find({'status': 'running'}))
        active_jobs = []

        for job in jobs:
            job_id = job['id']
            pid = job.get('pid')

            if not pid:
                # No PID recorded, mark as failed
                self._fail_job(job_id, "No PID recorded for running job")
                continue

            # Check if process is still alive using psutil
            if not psutil.pid_exists(pid):
                # Process died - collect error log and mark as failed
                error_log = self.job_dir / str(job_id) / "stderr.log"

                if error_log.exists():
                    try:
                        error = error_log.read_text()
                    except Exception as e:
                        error = f"Could not read error log: {e}"
                else:
                    error = "Job process no longer running for unknown reason"

                print(f"  Job {job_id} (PID {pid}) is dead - marking as failed")
                self._fail_job(job_id, error)
            else:
                # Still running
                active_jobs.append(job)

        # Record check event in database
        self.events_collection.update_one(
            {'id': 'scheduler_checks_job'},
            {'$set': {'time': datetime.utcnow()}},
            upsert=True
        )

        return active_jobs

    def queue_new_jobs(self, max_count: int) -> int:
        """
        Start new jobs from queue

        Args:
            max_count: Maximum number of jobs to start

        Returns:
            Number of jobs started
        """
        # Find queued jobs
        queued_jobs = list(
            self.jobs_collection.find({'status': 'queued'})
            .sort('submit_time', 1)  # Oldest first
            .limit(max_count)
        )

        count = 0
        for job in queued_jobs:
            try:
                self.start_job(job)
                count += 1
            except Exception as e:
                print(f"  Failed to start job {job['id']}: {e}")
                self._fail_job(job['id'], str(e))

        return count

    def start_job(self, job: Dict):
        """
        Start a single job

        Args:
            job: Job dictionary from MongoDB
        """
        job_id = job['id']
        print(f"  Starting job {job_id}: {job.get('app', 'unknown')}")

        # Create job directory
        job_path = self.job_dir / str(job_id)
        job_path.mkdir(parents=True, exist_ok=True)

        # Write job file
        job_file = job_path / "jobfile.json"

        # Remove MongoDB _id for JSON serialization
        job_data = dict(job)
        if '_id' in job_data:
            del job_data['_id']

        import json
        with open(job_file, 'w') as f:
            json.dump(job_data, f, indent=2)

        # Prepare command
        # Worker executable can be like "python -m biop3.ProbModelSEED.job_worker"
        cmd_parts = self.worker_executable.split()
        cmd_parts.append(str(job_id))

        # Launch worker process
        stdout_log = job_path / "stdout.log"
        stderr_log = job_path / "stderr.log"

        process = subprocess.Popen(
            cmd_parts,
            stdout=open(stdout_log, 'w'),
            stderr=open(stderr_log, 'w'),
            cwd=str(job_path)
        )

        # Wait briefly for PID file to be created
        pid_file = job_path / "pid"
        max_wait = 30  # 30 seconds
        waited = 0

        while not pid_file.exists() and waited < max_wait:
            time.sleep(0.5)
            waited += 0.5

        if pid_file.exists():
            # Read PID from file (worker writes its own PID)
            try:
                pid = int(pid_file.read_text().strip())
            except Exception:
                pid = process.pid  # Fallback to subprocess PID

            # Update job status to running
            self.jobs_collection.update_one(
                {'id': job_id},
                {
                    '$set': {
                        'status': 'running',
                        'pid': pid,
                        'start_time': datetime.utcnow().isoformat() + '+0000'
                    }
                }
            )

            # Record start event
            self.events_collection.update_one(
                {'id': 'scheduler_runs_job'},
                {'$set': {'time': datetime.utcnow()}},
                upsert=True
            )

            print(f"    Job {job_id} started with PID {pid}")
        else:
            # Failed to start
            print(f"    Job {job_id} failed to create PID file")
            self._fail_job(job_id, "Could not assign PID to job - worker failed to start")

    def _fail_job(self, job_id: int, error: str):
        """
        Mark a job as failed

        Args:
            job_id: Job ID
            error: Error message
        """
        self.jobs_collection.update_one(
            {'id': job_id},
            {
                '$set': {
                    'status': 'failed',
                    'error': error,
                    'completed_time': datetime.utcnow().isoformat() + '+0000'
                }
            }
        )

    def cleanup_old_files(self):
        """Delete files older than 7 days"""
        now = datetime.now()
        max_age = timedelta(days=7)

        for directory in [self.job_dir, self.error_dir, self.output_dir]:
            if not directory.exists():
                continue

            for item in directory.iterdir():
                try:
                    # Get modification time
                    mtime = datetime.fromtimestamp(item.stat().st_mtime)

                    if now - mtime > max_age:
                        if item.is_file():
                            item.unlink()
                        elif item.is_dir():
                            # Remove directory and contents
                            import shutil
                            shutil.rmtree(item)
                except Exception as e:
                    print(f"  Warning: Could not clean up {item}: {e}")

    def shutdown(self):
        """Shutdown scheduler gracefully"""
        print("Shutting down scheduler...")

        # Remove PID file
        if self.pid_file.exists():
            self.pid_file.unlink()

        # Close MongoDB connection
        self.mongo_client.close()

        print("Scheduler shutdown complete")


def main():
    """Main entry point for scheduler script"""
    from .config import get_config

    print("ProbModelSEED Job Scheduler")
    print("=" * 50)

    # Load configuration
    try:
        config = get_config()
        config_dict = config.to_dict()
    except Exception as e:
        print(f"Error loading configuration: {e}")
        sys.exit(1)

    # Create and run scheduler
    scheduler = JobScheduler(config_dict)

    try:
        scheduler.monitor_loop()
    except KeyboardInterrupt:
        print("\nReceived keyboard interrupt")
    finally:
        scheduler.shutdown()


if __name__ == '__main__':
    main()
