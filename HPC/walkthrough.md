# HPC Execution Walkthrough

This guide provides step-by-step instructions on how to execute the Underwater Gaussian Splatting pipeline on the QUT Aqua HPC cluster using the PBS job submission system.

## 1. Prerequisites

Before submitting any jobs, you must ensure that your Research Project ID (RPID) is correctly configured in the PBS scripts.

1. Open the three PBS scripts located in `HPC/scripts/`:
   - `setup_env.pbs`
   - `verify_env.pbs`
   - `run_pipeline.pbs`
2. Locate the line `#PBS -P EUAPGM7346` at the top of each script.
3. Ensure `EUAPGM7346` is the RPID.

## 2. Step 1: Provisioning the Conda Environments

Because the cluster nodes do not have internet access or `sudo` privileges configured the same way as a local desktop, you must build your environments using a compute node that exactly matches the architecture you will run on (in our case, the `H100` GPU).

To build all 11 Conda environments:
```bash
qsub HPC/scripts/setup_env.pbs
```

You can monitor the status of your job using:
```bash
qstat -u <your_username>
```
Wait for this job to complete before moving on. You can check the output log (`ump_setup_env.o*`) in your current directory to verify that all environments were built successfully.

## 3. Step 2: Pre-Flight Verification

Before launching a massive 48-hour training pipeline, run a quick diagnostic job to ensure that the H100 GPU is accessible and that all Conda environments were provisioned perfectly.

Submit the verification job:
```bash
qsub HPC/scripts/verify_env.pbs
```

Check the `ump_verify_env.o*` log file once it finishes. If it passes without any exit code failures, your environments are pristine and ready for heavy lifting.

## 4. Step 3: Running the Pipeline

The master orchestration script automatically processes the Submerged3D dataset. By default, submitting the pipeline script will execute all 8 models sequentially on the `Kwaj` and `Tokai` scenes.

To run the default pipeline:
```bash
qsub HPC/scripts/run_pipeline.pbs
```

### Passing Custom Arguments
If you only want to run a specific model or a different scene, you can pass arguments to the PBS script using the `-v` (variable) flag.

Example: Run only the `seasplat` model on the `Tokai` scene:
```bash
qsub -v ARGS="--model seasplat --scene Tokai" HPC/scripts/run_pipeline.pbs
```

Example: Run the `oscd` model:
```bash
qsub -v ARGS="--model oscd" HPC/scripts/run_pipeline.pbs
```

## 5. Monitoring and Outputs

- **Job Status:** Use `qstat -u <username>` to check if your job is queued (`Q`) or running (`R`).
- **Logs:** PBS automatically generates a combined output and error log in the directory where you ran `qsub`. Look for files named `ump_run_pipeline.o[JOB_ID]`. You can `tail -f` this file to watch the pipeline execute in real-time.
- **Results:** The viewable `.ply` splat files and quantitative `results.json` files will be saved cleanly inside the `Codebase/3DGS-Water-Approaches` (or respective model) output directories, safely bypassing any read-only constraints on the shared `Dataset/` directory.
