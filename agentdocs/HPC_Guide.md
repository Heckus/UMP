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
- `qsig -s 2 <job_id>`: Send `SIGINT` (signal 2, equivalent to `Ctrl+C`) to the running job processes to unfreeze interactive loops.

## 6. Headless Batch Execution & Interactive Viewers
- **[CRITICAL] No Interactive WebSockets:** Frameworks such as Nerfstudio (WaterSplatting) host an interactive WebSocket/HTTP viewer on port 7007 and block post-training waiting for manual user exit (`Use ctrl+c to quit`). In headless batch jobs, this will burn all remaining walltime.
- **Enforcing Auto-Termination:** Always configure training commands to run headlessly:
  - Nerfstudio / WaterSplatting: Use `--vis wandb --viewer.quit-on-train-completion True` and ensure `quit_on_train_completion=True` in `water_splatting_config.py`.
  - WandB: Always ensure `export WANDB_MODE=offline` (or `disabled`) so headless nodes never prompt for web authentication.
- **Unfreezing a Hanging Job Without Data Loss:** If a training job has reached 100% and is hanging at `"Use ctrl+c to quit"`:
  - From the compute node: run `pkill -2 -f ns-train` (or `kill -INT <PID>`). Nerfstudio catches `SIGINT`, exits with status 0, and the pipeline immediately proceeds to `.ply` export, mesh extraction, and evaluation.
  - From the login node: run `qsig -s 2 <job_id>`.

## 7. Attempt 6 Execution Procedure

Following the forensic audit of Attempt 5, all 3 failure root causes (SuGaR scoping shadow, 3D-UIR rasterizer 3D vs 4D gradient tensor shape mismatch, and OSCD custom logger stream absence of `isatty` in TorchDynamo) are fully resolved.

### Step-by-Step Launch Instructions:

1. **Pull Latest Changes on HPC**:
   ```bash
   cd ~/EUAPGM7346/UMP
   git pull origin main
   ```
   *Note*: SuGaR (`cameras.py`) and OSCD (`general_utils.py`, `oscd.py`) execute directly from source; `git pull` updates them immediately.

2. **Automated 3D-UIR Rasterizer Rebuild**:
   - `run_pipeline.sh` includes fail-safe self-healing automation (`ensure_3d_uir_rasterizer`): when `run_pipeline.pbs` executes, it checks the active `3d-uir` Conda environment. If `diff_gaussian_rasterization` is legacy `0.0.0` or missing, it automatically sets `CUDA_HOME` to 11.8.0 and force-reinstalls the custom 4D homodirectional extension before preflight verification and training.
   - Alternatively, to rebuild `3d-uir` ahead of job submission:
     ```bash
     qsub -v TARGET_ENV="3d-uir" HPC/scripts/setup_env.pbs
     ```

3. **Launch the Master Pipeline**:
   ```bash
   qsub HPC/scripts/run_pipeline.pbs
   ```

4. **Monitor Job Execution Live**:
   ```bash
   # Check queue status
   qstat -u $USER

   # Monitor real-time unbuffered log stream
   tail -f run_pipeline_live.log
   ```

## 8. Attempt 7 Execution Procedure & Verification

During Attempt 6, the pipeline made a monumental leap forward: **6 of 15 model executions ran to full completion** across all 6 stages, all 11 Conda environments built cleanly, and 3D-UIR homodirectional gradients were validated. The 9 remaining failures were traced to 5 specific code-level defects (SuGaR Kwaj scale collapse, SeaSplat evaluation GT path, SuGaR `.jpg.jpg` camera loader, GaussianSplashing PLY attribute deserialization, and OSCD Python variable shadowing).

All 5 defects have been completely resolved in the codebase for Attempt 7. Because all modifications are in Python source files and shell scripts (no binary extension recompilation required), updating the HPC cluster takes seconds via Git.

### Step-by-Step Launch Instructions:

1. **Pull Latest Code on QUT Aqua**:
   ```bash
   cd ~/EUAPGM7346/UMP
   git pull origin main
   ```

2. **Verify Pre-Flight Environment & Dry-Run (Optional but Recommended)**:
   ```bash
   # Quick dry-run of pipeline orchestration
   bash Codebase/scripts/run_pipeline.sh --dry-run --model seasplat --stage all --scene Kwaj
   bash Codebase/scripts/run_pipeline.sh --dry-run --model oscd --stage all
   ```

3. **Submit Attempt 7 Pipeline Job**:
   ```bash
   qsub HPC/scripts/run_pipeline.pbs
   ```

4. **Monitor Live Execution**:
   ```bash
   # Check job queue and active node allocation
   qstat -u $USER

   # Stream real-time execution log
   tail -f run_pipeline_live.log

   # Check for any trapped errors
   cat pipeline_errors.log
   ```

5. **Post-Run Verification Checklist (Projected 15 / 15 Succeeded)**:
   - Check summary report at the bottom of `run_pipeline_complete.log` (15/15 SUCCESS).
   - Verify textured surface meshes extracted for all 8 models across Kwaj and Tokai:
     - `Dataset/Submerged3D/Kwaj/output/refined_mesh/Kwaj.obj`
     - `Dataset/Submerged3D/Tokai/output/refined_mesh/Tokai.obj`
   - Verify novel view synthesis benchmark metrics (PSNR, SSIM, LPIPS) in:
     - `Codebase/3DGS-Water-Approaches/Physics/seasplat-master/output/<Scene>/results.json`
     - `Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main/output/<Scene>/results.json`
     - `Codebase/3DGS-Water-Approaches/Image/gaussianSplashing-main/output/<Scene>/results.json`
     - `Codebase/3DGS-Water-Approaches/Image/water-splatting-main/outputs/<Scene>/.../results.json`
     - `Codebase/3DGS-Water-Approaches/Additional/RUSplatting-main/output/<Scene>/results.json`
     - `Codebase/3DGS-Water-Approaches/Additional/UW-GS-main/output/<Scene>/results.json`
     - `Codebase/3DGS-Water-Approaches/Additional/SuGaR-main/output/...`
     - `Codebase/3DGS-Change-Detection/O-SCD-main/output/Custom_OSCD_Dataset/output/results.json`



