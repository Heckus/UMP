# 3DGS & OSCD Automation Pipeline & Scripting Suite

This document provides complete technical specifications, architectural details, operational workflows, and CLI references for the production-grade automation scripts suite located in `Codebase/scripts/`.

---

## 1. **[KEY-CONCEPT]** Architecture & System Overview

The automation suite provides a one-shot, turnkey execution platform for 3D Gaussian Splatting (3DGS) and Online Scene Change Detection (OSCD) models on Ubuntu Linux. It coordinates dependency provisioning, environment isolation, dataset normalization, sparse photogrammetric reconstruction, depth estimation, multi-model neural rendering, surface mesh extraction, and quantitative benchmarking.

```
Codebase/scripts/
├── verify_env.sh      # Pre-execution test suite & flight diagnostics (Exit codes 0-4)
├── setup_env.sh       # Automated provisioning (APT, Drivers, Miniconda, 11 Conda envs, Submodules)
└── run_pipeline.sh    # Master orchestration pipeline (6 stages, 8 models, dry-run mode)
```

### System Architecture Topology

```
+-----------------------------------------------------------------------------------+
|                              Host Operating System                                |
| Ubuntu Linux x86_64 | Proprietary NVIDIA Drivers | CUDA 11.8 - 12.8 | Miniconda3   |
+-----------------------------------------------------------------------------------+
                                         │
                   ┌─────────────────────┴─────────────────────┐
                   ▼                                           ▼
+------------------------------------+   +------------------------------------------+
|       verify_env.sh                |   |              setup_env.sh                |
|  - Pre-flight diagnostic engine    |   |  - System packages (apt-get)             |
|  - GPU/CUDA/VRAM validation        |   |  - NVIDIA driver autoinstall             |
|  - Conda env presence checks       |   |  - Miniconda silent bootstrap            |
|  - Dataset structure linting       |   |  - Git submodule auto-cloning & repair   |
|  - System tool dependency check    |   |  - 11 Isolated Conda environments        |
+------------------------------------+   +------------------------------------------+
                   │                                           │
                   └─────────────────────┬─────────────────────┘
                                         ▼
+-----------------------------------------------------------------------------------+
|                               run_pipeline.sh                                     |
|  Stage 1: Data Preparation & Download (Submerged3D / Custom_OSCD_Dataset)         |
|  Stage 2: COLMAP Sparse Reconstruction (colmap_runner -> convert.py)              |
|  Stage 3: Depth Estimation & Inversion (Depth-Anything-V2 ViT-L / RIFE)           |
|  Stage 4: Multi-Model Training (8 models across dedicated environments)           |
|  Stage 5: Surface Mesh Extraction (SuGaR -> train_full_pipeline.py -> .obj)       |
|  Stage 6: Held-out Evaluation & Benchmarking (render.py + metrics.py -> results)  |
+-----------------------------------------------------------------------------------+
```

### **[CRITICAL]** Isolation Design Principles

1. **Strict Environment Segregation**: The repository contains codebases with mutually incompatible Python and CUDA runtimes (from legacy Python 3.7 / PyTorch 1.12.1 up to Python 3.12 / PyTorch 2.5.1). To prevent dependency conflicts and CUDA driver mismatches, each model and tool executes inside an isolated Conda environment.
2. **Defensive Shell Conventions**: All scripts strictly adhere to `set -euo pipefail`. Because Conda's internal shell hook can trigger unbound variable warnings when inspecting unset environment variables, Conda activations explicitly wrap activations with temporary `set +u` guards.
3. **ShellCheck Compliance**: All automation scripts and test harnesses are verified against ShellCheck 0.11.0 standards with 0 errors and 0 warnings.
4. **Non-Destructive Dry-Run Guarantee**: All scripts provide `--dry-run` modes that display the exact execution graph, environment activations, directories, and CLI invocations without altering the host state.

---

## 2. Pre-Execution Test Suite: `verify_env.sh`

`verify_env.sh` acts as a pre-flight system diagnostic before initiating training or data processing pipelines. It validates that the host has necessary compute, runtime, dataset, and system dependencies available.

### CLI Syntax & Flags

```bash
verify_env.sh [OPTIONS]
```

| Option | Argument | Description |
| :--- | :--- | :--- |
| `-h`, `--help` | None | Prints complete usage documentation and exits with status `0`. |
| `-q`, `--quiet` | None | Suppresses informational output; outputs only warnings and errors. |
| `--skip-gpu` | None | Bypasses NVIDIA GPU and driver verification (for CI or headless hosts). |
| `--check-gpu` | None | Enforces NVIDIA GPU and driver verification (default behaviour). |
| `--env` | `<name>` | Validates presence of a specific Conda environment (e.g. `seasplat_py310`). |
| `--all-envs` | None | Validates presence of all 11 required isolated Conda environments. |
| `--dataset` | `<path>` | Validates dataset hierarchy and ensures image files are present. |

### Exit Codes

`verify_env.sh` uses standardized exit codes to communicate validation outcomes:

| Exit Code | Classification | Cause & Action Required |
| :---: | :--- | :--- |
| **`0`** | **Success** | All requested checks passed successfully. |
| **`1`** | **GPU Failure** | `nvidia-smi` missing, driver down, or kernel communication failure. Action: Run `setup_env.sh --drivers` or use `--skip-gpu` in headless/CI environments. |
| **`2`** | **Conda Failure** | Conda binary not found or requested Conda environment missing. Action: Run `setup_env.sh --conda` or `setup_env.sh --env <name>`. |
| **`3`** | **Dataset Failure** | Dataset directory missing, non-directory path, or scene `input/`/`images/` directory missing or empty. Action: Check dataset path or run Stage 1 data preparation. |
| **`4`** | **Dependency Failure** | Required system tool (`colmap`, `ffmpeg`, `git`, `python3`) missing from PATH. Action: Run `setup_env.sh --system-deps`. |

### Diagnostic Capabilities

- **GPU & CUDA Check**: Inspects `nvidia-smi -L` and queries GPU model, driver version, and CUDA version via `nvidia-smi --query-gpu=gpu_name,driver_version`.
- **Conda Environment Resolution**: Dynamically resolves the active Conda binary (`$CONDA_EXE`, `conda` in PATH, `~/miniconda3/bin/conda`, `/opt/conda/bin/conda`), queries `conda env list`, and checks physical environment paths.
- **Dataset Structure Linting**:
  - **Submerged3D Format**: Validates scene directories (e.g. `Cormoran`, `Isro`, `Kwaj`, `Tokai`), checking for populated `input/` or `images/` folders with image files (`.jpg`, `.jpeg`, `.png`).
  - **OSCD Format**: Automatically detects change detection layout and validates both `reference_scene/` and `inference_scene/` subdirectories.

---

## 3. Automated Environment Setup: `setup_env.sh`

`setup_env.sh` provides automated provisioning of system packages, GPU drivers, Miniconda, Git submodules, and isolated Conda environments.

### CLI Syntax & Flags

```bash
setup_env.sh [OPTIONS]
```

| Option | Argument | Description |
| :--- | :--- | :--- |
| `-h`, `--help` | None | Displays help message and exits with status `0`. |
| `--all` | None | Runs end-to-end setup (system packages, drivers, Miniconda, submodules, all 11 environments). |
| `--system-deps` | None | Installs Ubuntu `apt-get` packages only. |
| `--drivers` | None | Installs recommended proprietary NVIDIA drivers via `ubuntu-drivers autoinstall`. |
| `--conda` | None | Downloads, installs, and bootstraps Miniconda3 silently to `~/miniconda3`. |
| `--env` | `<name>` | Provisions a single specified Conda environment (normalizes case and aliases). |
| `--dry-run` | None | Prints planned installation commands without executing changes. |
| `-y`, `--yes` | None | Non-interactive mode (auto-accepts confirmation prompts). |

### System Packages Installed (`--system-deps`)

The script updates `apt-get` and installs essential compilation and multimedia packages:
- `build-essential`, `cmake`, `ninja-build`: Compilation tools for CUDA extension compilation.
- `colmap`: Structure-from-Motion (SfM) photogrammetry pipeline.
- `ffmpeg`: Video processing and frame extraction.
- `git`, `wget`, `curl`: Version control and asset downloads.
- `libgl1-mesa-glx`, `libglib2.0-0`: OpenGL and desktop GUI library dependencies for OpenCV and Vispy.

### The 11 Isolated Conda Environments

The table below summarizes all 11 isolated Conda environments provisioned by `setup_env.sh`:

| Environment | Python | CUDA / PyTorch | Key Packages & Repositories | Target Role |
| :--- | :---: | :---: | :--- | :--- |
| **`colmap_runner`** | 3.9 | System COLMAP | `tqdm` | Runs `convert.py` sparse reconstruction. |
| **`depth_anything`**| 3.10 | PyTorch cu121 | `torchvision`, `gradio`, `matplotlib`, `opencv-python` | Generates dense depth maps via Depth-Anything-V2 ViT-L. |
| **`seasplat_py310`**| 3.10 | PyTorch cu121 | `diff-gaussian-rasterization`, `simple-knn`, `plyfile` | SeaSplat underwater optical model training. |
| **`3d-uir`** | 3.10 | PyTorch 2.1.0 (cu118) | `cudatoolkit-dev=11.8`, `tiny-cuda-nn`, `fused-ssim` | 3D-UIR image restoration with depth scaling priors. |
| **`gaussianSplashing_env`** | 3.10 | PyTorch cu121 | `diff-gaussian-rasterization_UW`, `simple-knn`, `wandb`, `timm` | Gaussian Splashing direct volumetric rendering (HYB). |
| **`water_splatting`** | 3.8 | PyTorch 2.1.2 (cu118) | `cuda-toolkit=11.8`, `nerfstudio==1.1.4`, `tiny-cuda-nn` | WaterSplatting Nerfstudio-based volume rendering. |
| **`rusplatting`** | 3.12 | PyTorch 2.5.1 (cu124) | `diff-gaussian-rasterization`, `simple-knn`, `dearpygui`, `lpips` | RUSplatting sparse-view 3DGS with inverted depth. |
| **`UW-GS`** | 3.7 | PyTorch 1.12.1 (cu116) | `diff-gaussian-rasterization`, `simple-knn`, `imageio` | UW-GS with Background Medium Model (Linux recipe). |
| **`sugar`** | 3.9 | PyTorch 2.0.1 (cu118) | `pytorch3d==0.7.4`, `fvcore`, `iopath`, `open3d`, `PyMCubes` | SuGaR surface mesh extraction (.obj / .mtl). |
| **`oscd`** | 3.12 | PyTorch cu121 | `cupy-cuda12x`, `xformers`, `diff-fastgs`, `viser`, `transformers` | Online Scene Change Detection & model updating. |
| **`3dgs`** | 3.10 | PyTorch cu121 | `diff-gaussian-rasterization`, `simple-knn`, `fused-ssim` | Reference 3DGS baseline reconstruction (Kerbl et al.). |

### **[KEY-CONCEPT]** Submodule Auto-Repair Mechanism

Many open-source 3DGS repositories distribute submodules (`diff-gaussian-rasterization`, `simple-knn`, `fused-ssim`) as empty directory stubs or links to internal GitLab instances. `setup_env.sh` automatically checks every submodule across the entire repository. If a submodule is empty or corrupted, it clones the correct repository with dual-source fallback (e.g. Inria GitLab -> GitHub mirror for `simple-knn`).

Specific custom rasterizers are provisioned:
- `diff-gaussian-rasterization_UW`: Cloned from `BGU-CS-VIL/diff-gaussian-rasterization_UW.git` for Gaussian Splashing.
- `diff-gaussian-rasterization_fastgs`: Cloned from `Chumsy0725/diff-gaussian-rasterization_fastgs.git` for OSCD.

### **[KEY-CONCEPT]** Linux-Sanitized UW-GS Recipe

The upstream `UW-GS` repository includes Windows-specific environment packages (`win64_mkl`, `vc14_runtime`) that fail when resolved on Linux. `setup_env.sh` implements a sanitized Linux recipe that creates a Python 3.7 environment with PyTorch 1.12.1 + CUDA 11.6 wheels, strips Windows dependencies, and compiles the rasterizer submodules directly on Ubuntu.

---

## 4. Master Orchestration Pipeline: `run_pipeline.sh`

`run_pipeline.sh` is the master execution CLI that coordinates data preparation, COLMAP reconstruction, depth estimation, model training, mesh extraction, and quantitative benchmarking.

### CLI Syntax & Flags

```bash
run_pipeline.sh [OPTIONS]
```

| Option | Argument | Description |
| :--- | :--- | :--- |
| `-h`, `--help` | None | Displays help message and exits with status `0`. |
| `--model` | `<name>` | Selects model: `seasplat`, `3d-uir`, `gaussiansplashing`, `watersplatting`, `rusplatting`, `uw-gs`, `oscd`, `sugar`. |
| `--all` | None | Executes all 8 models sequentially. |
| `--dataset` | `<path>` | Custom dataset root or scene path. Default: `Codebase/Dataset/Submerged3D` (or `Custom_OSCD_Dataset` for OSCD). |
| `--scene` | `<name>` | Specific scene name (e.g. `Cormoran`, `Isro`, `Kwaj`, `Tokai`; default: `Cormoran`). |
| `--stage` | `<stage>` | Execution stage filter: `colmap`, `depth`, `train`, `mesh`, `eval`, `all` (default: `all`). |
| `--dry-run` | None | Prints expected execution commands and environments without running. |
| `--skip-verify` | None | Skips invoking `verify_env.sh` prior to pipeline launch. |
| `--skip-gpu` | None | Passes `--skip-gpu` to `verify_env.sh` (for headless/testing hosts). |
| `--gs-output-dir`| `<dir>` | Specifies checkpoint directory for SuGaR mesh prior (defaults to best 3DGS output). |

### The 6 Execution Stages

```
[Stage 1: Prep]  -->  [Stage 2: COLMAP]  -->  [Stage 3: Depth]  -->  [Stage 4: Train]  -->  [Stage 5: Mesh]  -->  [Stage 6: Eval]
 Submerged3D/OSCD        convert.py             Depth-Anything-V2        Model Dispatch        SuGaR Pipeline        render.py + metrics
  Normalization          colmap_runner             RIFE / Inversion       8 Environments        .obj / .mtl export      results.json
```

#### Stage 1: Data Preparation & Download (`prep`)
- **Submerged3D Dataset**: If the dataset directory is absent, automatically downloads the benchmark via `huggingface-cli download theflash987/Submerged3D --repo-type dataset --local-dir <path>`.
- **Folder Normalization**: Automatically detects `images/` directory and normalizes to `input/` as required by COLMAP and 3DGS conventions.
- **OSCD Dataset**: Verifies presence of `reference_scene/` and `inference_scene/` structures.

#### Stage 2: COLMAP Sparse Reconstruction (`colmap`)
- Activates `colmap_runner` environment.
- Executes `python convert.py -s <scene_path>` from `Codebase/Tools/gaussian-splatting-main/`.
- For OSCD, performs dual-scene sparse reconstruction across both `reference_scene/` and `inference_scene/`.

#### Stage 3: Depth Map Generation & Inversion (`depth`)
- Activates `depth_anything` environment.
- Invokes `Depth-Anything-V2-main/run.py` using the ViT-L checkpoint (`--encoder vitl --pred-only --grayscale`).
- **Model-Specific Adaptations**:
  - **RUSplatting**: Inverts depth maps (`depthmap_inverted/`) and establishes symlinks; invokes RIFE intermediate frame generation (`_to_` pattern).
  - **3D-UIR**: Generates standard depth maps, creates `depths/` symlink, and computes scene depth scaling factors via `python utils/make_depth_scale.py --base_dir <scene> --depths_dir <scene>/depths`.
  - **Other 3DGS models**: Generates standard dense depth maps into `<scene>/depthmap/`.

#### Stage 4: Model Training (`train`)
Executes model-specific training in its respective isolated Conda environment:

1. **SeaSplat** (`seasplat_py310`):
   ```bash
   python train.py -s <scene_path> --exp seasplat_exp --do_seathru --seathru_from_iter 10000 --eval
   ```
2. **3D-UIR** (`3d-uir`):
   ```bash
   python train.py -s <scene_path> -d <scene_path>/depths --eval
   ```
3. **Gaussian Splashing** (`gaussianSplashing_env`):
   ```bash
   python train.py -s <scene_path> --underwater_processing HYB --eval
   ```
4. **WaterSplatting** (`water_splatting`):
   ```bash
   ns-train water-splatting --vis viewer+wandb colmap --downscale-factor 1 --colmap-path sparse/0 --data <scene_path> --images-path images
   ```
5. **RUSplatting** (`rusplatting`):
   ```bash
   python train.py -s <scene_path> --adaptive --eval
   ```
6. **UW-GS** (`UW-GS`):
   ```bash
   python train.py -s <scene_path> -m "output/<scene_name>" --BMM_Flag --eval
   ```
7. **OSCD** (`oscd` + `3dgs`):
   - Step 4a: Baseline 3DGS reference reconstruction (`3dgs` env, 30,000 iterations).
   - Step 4b: Online change detection (`oscd` env):
     ```bash
     python oscd.py -s <dataset_path> -m <dataset_path>/output --resolution 1 --test_hold 5 --refine
     ```
   - Step 4c: 3D scene representation update (`oscd` env):
     ```bash
     python update.py -s <dataset_path> -m <dataset_path>/output --resolution 1 --test_hold 5
     ```
8. **SuGaR** (`sugar`): Directly invokes surface mesh extraction (see Stage 5).

#### Stage 5: Surface Mesh Extraction (`mesh`)
- Activates `sugar` environment.
- Ingests best 3DGS point cloud prior (defaulting to SeaSplat checkpoint or custom path via `--gs-output-dir`).
- Runs SuGaR joint density and mesh extraction pipeline:
  ```bash
  python train_full_pipeline.py -s <scene_path> -r "dn_consistency" --high_poly True --export_obj True --gs_output_dir <checkpoint_dir>
  ```
- Produces refined, textured 3D mesh files (`.obj`, `.mtl`).

#### Stage 6: Benchmarking & Metrics Evaluation (`eval`)
- **Novel View Synthesis**: Renders held-out test views via `python render.py -m <output_path> --skip_train`.
- **Quantitative Metrics**: Computes PSNR, SSIM, and LPIPS via `python metrics.py -m <output_path>`, writing summary statistics to `<output_path>/results.json`.
- **WaterSplatting**: Evaluates checkpoints via Nerfstudio CLI (`ns-eval --load-config <config.yml>`).
- **OSCD Change Detection**: Evaluates novel view metrics (`utils/metrics.py`) and segmentation masks (`utils/evaluate.py --gt <gt_mask> --pred_binary <renders>/change_mask`).

---

## 5. Practical Workflows & Usage Guide

### Initial Machine Setup (Workstation Dual-Boot)

To configure a clean Ubuntu system with all drivers, runtimes, and models:

```bash
# 1. Preview planned actions
./Codebase/scripts/setup_env.sh --all --dry-run

# 2. Run system dependency installation (requires sudo)
./Codebase/scripts/setup_env.sh --system-deps -y

# 3. Install NVIDIA drivers (requires reboot if new driver installed)
./Codebase/scripts/setup_env.sh --drivers -y

# 4. Bootstrap Miniconda and provision all 11 isolated environments
./Codebase/scripts/setup_env.sh --all -y
```

### Pre-Flight Diagnostic Checks

```bash
# Check all components (GPU, all Conda envs, tools)
./Codebase/scripts/verify_env.sh --all-envs

# Check host without physical GPU (e.g. CI or non-NVIDIA machine)
./Codebase/scripts/verify_env.sh --skip-gpu

# Check single environment and dataset
./Codebase/scripts/verify_env.sh --env seasplat_py310 --dataset Codebase/Dataset/Submerged3D/Cormoran
```

### Running Model Training Pipelines

```bash
# SeaSplat dry-run inspection
./Codebase/scripts/run_pipeline.sh --model seasplat --dry-run

# SeaSplat live execution on Cormoran scene
./Codebase/scripts/run_pipeline.sh --model seasplat --scene Cormoran

# Run only training stage for 3D-UIR
./Codebase/scripts/run_pipeline.sh --model 3d-uir --stage train

# Run SuGaR mesh extraction using pre-trained SeaSplat prior
./Codebase/scripts/run_pipeline.sh --model sugar --gs-output-dir Codebase/3DGS-Water-Approaches/Physics/seasplat-master/output/seasplat_exp/Cormoran

# Run OSCD change detection pipeline
./Codebase/scripts/run_pipeline.sh --model oscd --dataset Codebase/Dataset/Custom_OSCD_Dataset

# Sequential execution across all 8 models
./Codebase/scripts/run_pipeline.sh --all
```

---

## 6. Testing & Quality Assurance

The scripting suite includes an end-to-end hermetic test harness in `tests/e2e/`:

```bash
# Execute entire E2E test suite (ShellCheck, Tier 1-4)
bash tests/e2e/test_runner.sh

# Execute specific test tiers
bash tests/e2e/test_runner.sh --tier shellcheck   # Static code analysis
bash tests/e2e/test_runner.sh --tier 1            # Single-flag feature coverage
bash tests/e2e/test_runner.sh --tier 2            # Boundary conditions & exit codes
bash tests/e2e/test_runner.sh --tier 3            # Flag combinations
bash tests/e2e/test_runner.sh --tier 4            # Real-world multi-stage scenarios
```

For detailed test harness architecture and mock sandboxing details, refer to `TEST_INFRA.md` and `TEST_READY.md`.
