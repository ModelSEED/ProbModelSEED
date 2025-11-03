# ProbModelSEED Python Job System

This directory contains the new Python-based job system for ProbModelSEED, which replaces the Perl-based scheduler and job execution infrastructure.

## Architecture

### Components

1. **config.py** - Configuration management
   - Reads `deploy.cfg`
   - Provides drop-in replacement for `Bio::KBase::utilities::conf()`
   - Functions: `conf()`, `setconf()`, `config_hash()`

2. **workspace_client.py** - PATRIC Workspace client
   - HTTP-based workspace API client
   - Replaces `Bio::ModelSEED::patricenv::call_ws()`
   - Supports get, create, update_metadata, ls, delete, etc.

3. **scheduler.py** - Job scheduler daemon
   - Replaces `scheduler.pl`
   - Monitors MongoDB for queued jobs
   - Spawns worker processes
   - Tracks job status using `psutil`

4. **job_worker.py** - Job execution worker
   - Replaces `RunProbModelSEEDJob.pl`
   - Executes individual jobs
   - Routes to appropriate app handlers
   - Reports results to MongoDB

5. **model_reconstruction.py** - Model building logic
   - High-level functions for ModelSEEDpy integration
   - Functions: `run_model_reconstruction()`, `run_gapfill_model()`, `run_fba()`

## Installation

### 1. Install Python Dependencies

```bash
pip install -r requirements-jobs.txt
```

Or manually:
```bash
pip install pymongo requests psutil cobra modelseedpy cobrakbase
```

### 2. Update Configuration

Edit `deploy.cfg` to add Python-specific settings:

```ini
[Scheduler]
jobdirectory=/disks/p3dev2/fba/
msurl=https://p3.theseed.org/services/ProbModelSEED
threads=4
# NEW: Python worker command
python_worker=python -m biop3.ProbModelSEED.job_worker

[ModelSEEDpy]
# Path to ModelSEEDpy installation
codebase=/path/to/ModelSEEDpy/
libarary_paths=lib;
```

### 3. Setup Python Path

Ensure the lib directory is in Python path:

```bash
export PYTHONPATH=/path/to/ProbModelSEED/lib:$PYTHONPATH
```

Or add to your virtualenv/conda environment.

## Usage

### Running the Scheduler

```bash
# Run scheduler in foreground
python -m biop3.ProbModelSEED.scheduler

# Or as a background daemon
nohup python -m biop3.ProbModelSEED.scheduler > scheduler.log 2>&1 &
```

The scheduler will:
1. Connect to MongoDB
2. Monitor for queued jobs
3. Start workers up to `threads` limit
4. Track running jobs
5. Clean up old files (>7 days)

### Running Jobs Manually

To test a job worker directly:

```bash
# Execute job ID 12345
python -m biop3.ProbModelSEED.job_worker 12345
```

Job output goes to:
- `{jobdirectory}/jobs/12345/stdout.log`
- `{jobdirectory}/jobs/12345/stderr.log`
- `{jobdirectory}/jobs/12345/output.json`

### Using Configuration API

```python
from biop3.ProbModelSEED import conf, setconf, config_hash

# Get config value
job_dir = conf("Scheduler", "jobdirectory")

# Set config value (runtime only)
setconf("Scheduler", "jobid", "12345")

# Get full config as dict
config = config_hash()
```

### Using Workspace Client

```python
from biop3.ProbModelSEED import WorkspaceClient

# Create client
ws = WorkspaceClient.from_config()

# Get object
meta, data = ws.get_object("/user/models/model1")

# Save object
ws.save_object(
    "/user/models/model2",
    "FBAModel",
    model_data,
    {"status": "complete"}
)

# Update metadata
ws.set_metadata("/user/models/model2", {"status": "gapfilled"})
```

## Supported Apps

The job worker currently supports these app types:

1. **ModelReconstruction** - Build metabolic model from genome
2. **GapfillModel** - Gapfill existing model (in progress)
3. **FluxBalanceAnalysis** - Run FBA on model (in progress)
4. **ComputeReactionProbabilities** - Compute rxn probabilities (in progress)

## Migration from Perl

### Advantages of Python System

- ✅ **66% less code** (~500 lines vs ~1500 lines)
- ✅ **Single language** (no Perl ↔ Python boundary)
- ✅ **Modern libraries** (psutil vs shell ps parsing)
- ✅ **Better error handling** (exceptions vs eval blocks)
- ✅ **Easier testing** (Python unittest vs Perl testing)
- ✅ **Type hints** (optional but available)

### Backwards Compatibility

The Python system uses the same MongoDB schema and job directories as the Perl system, so:

- ✅ Can read jobs created by Perl system
- ✅ Uses same workspace API
- ✅ Stores results in same format
- ⚠️ Cannot run Perl and Python schedulers simultaneously (they compete for jobs)

### Transition Plan

1. **Phase 1**: Test Python scheduler on dev instance
2. **Phase 2**: Run Python scheduler on subset of job types
3. **Phase 3**: Migrate all job types to Python
4. **Phase 4**: Archive Perl scheduler

## Troubleshooting

### Scheduler won't start

Check:
- MongoDB connection: `conf("ProbModelSEED", "mongodb-host")`
- Job directory exists and is writable
- Python dependencies installed: `pip list | grep pymongo`

### Jobs fail immediately

Check:
- Worker command in config: `conf("Scheduler", "python_worker")`
- Python path includes lib directory
- ModelSEEDpy installed and importable

### Jobs stay in "running" forever

Check:
- Scheduler is running (check `schedulerPID` file)
- Worker PID file created in job directory
- Worker process didn't crash (check stderr.log)

## Development

### Adding a New App Type

1. Add handler function to `model_reconstruction.py`:
   ```python
   def run_my_new_app(input_data: Dict[str, Any]) -> Dict[str, Any]:
       # Implementation
       return output
   ```

2. Add route in `job_worker.py`:
   ```python
   elif app_name == 'MyNewApp':
       self.run_my_new_app()
   ```

3. Add method to JobWorker:
   ```python
   def run_my_new_app(self):
       from .model_reconstruction import run_my_new_app
       output = run_my_new_app(input_data)
   ```

### Testing

```python
# Test config
from biop3.ProbModelSEED import get_config
config = get_config()
assert config.get("Scheduler", "jobdirectory") is not None

# Test workspace client
from biop3.ProbModelSEED import WorkspaceClient
ws = WorkspaceClient.from_config()
# ... test operations

# Test job worker
from biop3.ProbModelSEED.job_worker import JobWorker
worker = JobWorker(12345)
worker.execute()
```

## Monitoring

### Check Scheduler Status

```bash
# Is scheduler running?
cat {jobdirectory}/schedulerPID
ps -p $(cat {jobdirectory}/schedulerPID)

# View recent log output
tail -f scheduler.log
```

### Check Job Status

```python
from pymongo import MongoClient

client = MongoClient("mongodb://localhost/")
db = client.modelseed

# Count jobs by status
for status in ['queued', 'running', 'completed', 'failed']:
    count = db.jobs.count_documents({'status': status})
    print(f"{status}: {count}")

# Recent jobs
recent = db.jobs.find().sort('submit_time', -1).limit(10)
for job in recent:
    print(f"{job['id']}: {job['app']} - {job['status']}")
```

## File Locations

```
{jobdirectory}/
├── schedulerPID           # Scheduler process ID
├── jobs/
│   └── {jobid}/
│       ├── jobfile.json   # Job definition
│       ├── pid            # Worker process ID
│       ├── stdout.log     # Standard output
│       ├── stderr.log     # Error output
│       ├── input.json     # Debug: input data
│       └── output.json    # Result data
├── errors/                # Historical errors
└── output/                # Historical outputs
```

## License

Same as ProbModelSEED main project.
