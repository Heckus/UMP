# HPC Guide: QUT Aqua Cluster

This document serves as the master reference for AI agents and developers interacting with the QUT High-Performance Computing (HPC) cluster (Aqua). It summarizes the core rules, job submission procedures, and environment constraints based on the `HPC/Guides` documentation.

## 1. System Constraints & Rules
- **No `sudo` Access:** You cannot install system packages (`apt-get`) or NVIDIA drivers. All dependencies must be loaded via HPC modules or installed locally via Conda.
- **Maximum Walltime:** All jobs have a strict maximum walltime limit of **48 hours**. Jobs requesting more will sit in the queue indefinitely.
- **Research Project ID (RPID):** All PBS scripts **must** include an RPID (e.g., `#PBS -P ABCDEF1234`). Jobs without an RPID will be rejected.

## 2. Software Modules & Conda
The HPC uses a module system to manage software. Before running Python or Conda commands, you must load the appropriate module.

### Managing Modules
- `module spider <name>`: Search for available software.
- `module load <name>`: Load a software module (e.g., `module load Anaconda3/2024.02-1`).
- `module purge`: Unload all currently loaded modules to avoid conflicts.

### Conda Initialization
To use Conda on the HPC, load the Anaconda module and initialize it (only needed once, but safe to include in scripts):
```bash
module load Anaconda3/2024.02-1
conda init
```

## 3. PBS Job Submission
Jobs are submitted to the queue using PBS scripts (typically `.pbs` extension) and the `qsub` command.

### Key PBS Directives
Include these at the top of your bash scripts:
```bash
#!/bin/bash -l
#PBS -N job_name                   # Name of the job
#PBS -l select=1:ncpus=4:mem=16gb  # Resource request (Nodes : CPUs : Memory)
#PBS -l walltime=04:00:00          # Walltime (HH:MM:SS) - MAX 48:00:00
#PBS -P YOUR_RPID_HERE             # Mandatory Research Project ID
#PBS -j oe                         # Merge standard output and error into one file
```

### Navigating to the Work Directory
PBS jobs start in your home directory by default. Always include this line to switch to the directory from which the job was submitted:
```bash
cd $PBS_O_WORKDIR
```

## 4. Requesting GPUs
To request GPU resources, add the `ngpus` flag to your `select` directive. Because GPUs are highly contended, only request them for jobs that actively utilize CUDA.

```bash
# Example: 1 Node, 42 CPUs, 1 GPU, 243GB RAM, specifically targeting an H100 node.
# Note: Always request the proportional share of CPU/Memory for your GPU to prevent hardware waste, 
# as CPU-only jobs cannot run on GPU nodes. (H100 node: 168 CPUs / 4 GPUs = 42 CPUs per GPU)
#PBS -l select=1:ncpus=42:ngpus=1:mem=243gb:gpu_id=H100
```

## 5. Helpful Commands
- `qsub script.pbs`: Submit a job to the queue.
- `qsub -I -l select=...`: Start an interactive job (terminal session on a compute node).
- `qstat -u $USER`: View the status of your queued and running jobs.
- `qdel <job_id>`: Delete/cancel a submitted job.
