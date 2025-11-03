"""
Job Worker for ProbModelSEED

Replaces RunProbModelSEEDJob.pl
Executes individual jobs and reports results to MongoDB
"""

import os
import sys
import json
import traceback
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional
from pymongo import MongoClient

from .config import conf, setconf, config_hash
from .workspace_client import WorkspaceClient


class JobWorker:
    """Worker that executes a single ProbModelSEED job"""

    def __init__(self, job_id: int, config_dict: Optional[Dict] = None):
        """
        Initialize job worker

        Args:
            job_id: Numeric job ID
            config_dict: Configuration dictionary. If None, uses global config.
        """
        self.job_id = job_id
        self.config = config_dict

        # Set job ID in config for downstream use
        setconf("Scheduler", "jobid", str(job_id))

        # Setup paths
        job_dir_base = conf("Scheduler", "jobdirectory")
        self.job_dir = Path(job_dir_base) / "jobs" / str(job_id)
        self.job_dir.mkdir(parents=True, exist_ok=True)

        # Setup MongoDB connection
        mongo_host = conf("ProbModelSEED", "mongodb-host", "localhost")
        mongo_user = conf("ProbModelSEED", "mongodb-user")
        mongo_pwd = conf("ProbModelSEED", "mongodb-pwd")

        if mongo_user and mongo_user not in ('null', 'none', ''):
            connection_string = f"mongodb://{mongo_user}:{mongo_pwd}@{mongo_host}/"
        else:
            connection_string = f"mongodb://{mongo_host}/"

        self.mongo_client = MongoClient(connection_string)
        self.db = self.mongo_client.modelseed
        self.jobs_collection = self.db.jobs

        # Write PID file for scheduler monitoring
        pid_file = self.job_dir / "pid"
        pid_file.write_text(str(os.getpid()))

        # Initialize workspace client
        self.workspace = None
        self.job = None

    def execute(self):
        """
        Main execution entry point

        Loads job, executes it, and reports results
        """
        try:
            # Load job definition
            self.job = self.load_job()

            # Initialize workspace client with job token
            self.workspace = WorkspaceClient(token=self.job.get('token'))

            # Route to appropriate app handler
            app_name = self.job['app']
            print(f"Executing job {self.job_id}: {app_name}")

            if app_name == 'ModelReconstruction':
                self.run_model_reconstruction()
            elif app_name == 'GapfillModel':
                self.run_gapfill_model()
            elif app_name == 'FluxBalanceAnalysis':
                self.run_fba()
            elif app_name == 'ComputeReactionProbabilities':
                self.run_compute_rxn_probs()
            else:
                raise ValueError(f"Unknown app: {app_name}")

            # Mark success
            self.finish(success=True)
            print(f"Job {self.job_id} completed successfully")

        except Exception as e:
            error_msg = f"{str(e)}\n{traceback.format_exc()}"
            print(f"Job {self.job_id} failed:", file=sys.stderr)
            print(error_msg, file=sys.stderr)
            self.finish(success=False, error=error_msg)
            sys.exit(1)

    def load_job(self) -> Dict[str, Any]:
        """
        Load job definition from file or MongoDB

        Returns:
            Job dictionary
        """
        job_file = self.job_dir / "jobfile.json"

        if not job_file.exists():
            # Fetch from MongoDB (like RunProbModelSEEDJob.pl does)
            print(f"Fetching job {self.job_id} from MongoDB")
            job = self.jobs_collection.find_one({'id': self.job_id})
            if not job:
                raise ValueError(f"Job {self.job_id} not found in database")

            # Remove MongoDB _id field for JSON serialization
            if '_id' in job:
                del job['_id']

            # Write to file for debugging
            with open(job_file, 'w') as f:
                json.dump(job, f, indent=2)
        else:
            # Load from file
            with open(job_file, 'r') as f:
                job = json.load(f)

        return job

    def run_model_reconstruction(self):
        """Execute ModelReconstruction app"""
        from .model_reconstruction import run_model_reconstruction

        params = self.job['parameters']

        # Prepare input data
        input_data = {
            'config': self.config or config_hash(),
            'parameters': params,
            'job_id': self.job_id,
            'workspace': self.workspace
        }

        # Write input for debugging
        input_file = self.job_dir / 'input.json'
        with open(input_file, 'w') as f:
            # Create serializable version
            debug_input = {
                'config': input_data['config'],
                'parameters': params,
                'job_id': self.job_id
            }
            json.dump(debug_input, f, indent=2)

        print(f"Running model reconstruction with parameters: {params}")

        # Execute reconstruction
        output = run_model_reconstruction(input_data)

        # Write output
        output_file = self.job_dir / 'output.json'
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)

        print(f"Model reconstruction complete. Output written to {output_file}")

    def run_gapfill_model(self):
        """Execute GapfillModel app"""
        from .model_reconstruction import run_gapfill_model

        params = self.job['parameters']

        # Prepare input data
        input_data = {
            'config': self.config or config_hash(),
            'parameters': params,
            'job_id': self.job_id,
            'workspace': self.workspace
        }

        print(f"Running gapfill with parameters: {params}")

        # Execute gapfilling
        output = run_gapfill_model(input_data)

        # Write output
        output_file = self.job_dir / 'output.json'
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)

        print(f"Gapfilling complete. Output written to {output_file}")

    def run_fba(self):
        """Execute FluxBalanceAnalysis app"""
        from .model_reconstruction import run_fba

        params = self.job['parameters']

        # Prepare input data
        input_data = {
            'config': self.config or config_hash(),
            'parameters': params,
            'job_id': self.job_id,
            'workspace': self.workspace
        }

        print(f"Running FBA with parameters: {params}")

        # Execute FBA
        output = run_fba(input_data)

        # Write output
        output_file = self.job_dir / 'output.json'
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)

        print(f"FBA complete. Output written to {output_file}")

    def run_compute_rxn_probs(self):
        """Execute ComputeReactionProbabilities app"""
        from .model_reconstruction import run_compute_reaction_probabilities

        params = self.job['parameters']

        input_data = {
            'config': self.config or config_hash(),
            'parameters': params,
            'job_id': self.job_id,
            'workspace': self.workspace
        }

        print(f"Computing reaction probabilities with parameters: {params}")

        output = run_compute_reaction_probabilities(input_data)

        output_file = self.job_dir / 'output.json'
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)

        print(f"Reaction probabilities computed. Output written to {output_file}")

    def finish(self, success: bool, error: Optional[str] = None):
        """
        Report job completion to MongoDB

        Args:
            success: True if job succeeded, False if failed
            error: Error message if job failed
        """
        status = 'completed' if success else 'failed'
        update = {
            'status': status,
            'completed_time': datetime.utcnow().isoformat() + '+0000'
        }

        if error:
            update['error'] = error

        print(f"Updating job {self.job_id} status to {status}")

        self.jobs_collection.update_one(
            {'id': self.job_id},
            {'$set': update}
        )

        # Also handle workspace metadata update on failure (like RunProbModelSEEDJob.pl does)
        if not success and self.job and self.job['app'] == 'ModelReconstruction':
            try:
                params = self.job['parameters']
                output_path = params.get('output_path', '')
                output_file = params.get('output_file', '')

                if output_path and output_file:
                    folder = output_path.rstrip('/') + '/' + output_file
                    self.workspace.set_metadata(folder, {
                        'status_error': error,
                        'status': 'failed',
                        'status_timestamp': datetime.utcnow().isoformat() + '+0000'
                    })
                    print(f"Updated workspace metadata for {folder}")
            except Exception as e:
                print(f"Warning: Could not update workspace metadata: {e}", file=sys.stderr)


def main():
    """Main entry point for job worker script"""
    if len(sys.argv) < 2:
        print("Usage: python -m biop3.ProbModelSEED.job_worker <job_id>", file=sys.stderr)
        sys.exit(1)

    job_id = int(sys.argv[1])

    # Load configuration
    from .config import config_hash

    config = config_hash()

    # Execute job
    worker = JobWorker(job_id, config)
    worker.execute()


if __name__ == '__main__':
    main()
