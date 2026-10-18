# Underwater Multi-View Photogrammetry & 3DGS Scene Change Detection (UMP)

[![QUT Engineering Thesis](https://img.shields.io/badge/QUT-Engineering_Thesis-003366.svg)](https://www.qut.edu.au/)
[![Ubuntu 22.04 LTS](https://img.shields.io/badge/Ubuntu-22.04_LTS-E95420.svg?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![CUDA 11.8 / 12.4](https://img.shields.io/badge/CUDA-11.8%20%2F%2012.4-76B900.svg?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)
[![3D Gaussian Splatting](https://img.shields.io/badge/3DGS-Primitive--Space-brightgreen.svg)](https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/)
[![Status: 15/15 Succeeded](https://img.shields.io/badge/Benchmark_Status-15%2F15_Succeeded_(100%25)-success.svg)](./agentdocs/attempt_10_verification.md)

This repository contains the software suite, evaluation workspace, and experimental benchmarks for the QUT Engineering Research Thesis: **"Investigation of Primitive-Space Scene Change Detection in Underwater 3D Gaussian Splatting Models"**.

It provides a production-grade, one-shot automation platform for training, regularising, extracting per-model 3D surface meshes (`.obj`), and evaluating **8 state-of-the-art 3D Gaussian Splatting (3DGS) and Online Scene Change Detection (OSCD) architectures** on both high-performance computing (QUT Aqua HPC cluster) and local desktop workstations.

---

## Table of Contents
1. [Core Research Objective & Key Contributions](#1-core-research-objective--key-contributions)
2. [Supported Model Architectures](#2-supported-model-architectures)
3. [The End-to-End User Journey & `Model_Outputs` Workspace](#3-the-end-to-end-user-journey--model_outputs-workspace)
   - [Workspace Directory Structure (`Model_Outputs/`)](#workspace-directory-structure-model_outputs)
   - [Recommended Desktop Viewing Tools (Ubuntu & Blender)](#recommended-desktop-viewing-tools-ubuntu--blender)
   - [Phase 1: Setup (Environment & GPU Verification)](#phase-1-setup-environment--gpu-verification)
   - [Phase 2: Run (Master Pipeline Orchestration)](#phase-2-run-master-pipeline-orchestration)
   - [Phase 3: Extract (Transfer from HPC to Local Desktop)](#phase-3-extract-transfer-from-hpc-to-local-desktop)
   - [Phase 4: Organise (`organize_outputs.py`)](#phase-4-organise-organize_outputspy)
   - [Phase 5: Review, Evaluate & Heatmaps (`collect_metrics.py`, `view_outputs.py`, `generate_change_heatmaps.py`)](#phase-5-review-evaluate--heatmaps)
4. [Dataset Ingestion Guide](#4-dataset-ingestion-guide)
   - [A. Pre-Configured Datasets (Submerged3D & Phone-Captured OSCD)](#a-pre-configured-datasets)
   - [B. Bringing Any Custom Underwater Dataset](#b-bringing-any-custom-underwater-dataset)
   - [C. Bringing Any Custom Dual-Photo Change Detection Dataset](#c-bringing-any-custom-dual-photo-change-detection-dataset)
5. [Future Research Direction: Temporal Underwater OSCD for Coral Reef Monitoring](#5-future-research-direction-temporal-underwater-oscd-for-coral-reef-monitoring)
6. [Master Quantitative Benchmark Portfolio (15 / 15 Succeeded)](#6-master-quantitative-benchmark-portfolio-15--15-succeeded)
7. [Repository Structure & Living Brain Documentation](#7-repository-structure--living-brain-documentation)

---

## 1. Core Research Objective & Key Contributions

Traditional optical photogrammetry and NeRF models struggle in marine environments due to wavelength-dependent light absorption (loss of red spectra), backscatter, and particulate floating matter ("marine snow"). Furthermore, detecting physical scene modifications across time typically requires volumetric voxelization or dense mesh subtraction, which is computationally prohibitive and susceptible to water-column noise.

This project addresses these fundamental bottlenecks by:
1. **Primary Goal — Primitive-Space Scene Change Detection on 3D Gaussian Splats (`O-SCD`):** Detecting, segmenting, and updating scene modifications directly on the **3D Gaussian splat primitives** themselves (`GS-DIFF` / `O-SCD`)—and exporting 3D thermal change heatmaps (`.ply`) and post-change representations—without retraining the entire scene from scratch.
2. **Evaluating Underwater 3DGS Formulations:** Benchmarking physical optical restoration (`SeaSplat`, `3D-UIR`), image-enhancement prior splatting (`Gaussian Splashing`, `WaterSplatting`), supplementary depth-guided splatting (`RUSplatting`, `UW-GS`), and baseline 3DGS across realistic underwater marine scenes (`Kwaj` and `Tokai`).
3. **Per-Model 3D Surface Geometry Extraction & Comparison (`SuGaR` — Supporting Output & Bonus Feature):**
   - **Literature Motivation:** The primitive-space 3DGS change detection paper (`GS-DIFF` / `O-SCD`, Galappaththige et al., 2026) explicitly recommended at the conclusion of their paper integrating the **SuGaR** surface regularization method to bind 3D Gaussians to true physical surfaces and mitigate unconstrained Gaussian drift—which directly motivated integrating SuGaR into this pipeline.
   - **Why We Produce & Review 3D `.obj` Models for Every Method Right Now ($\text{mm} \to \text{cm}$ Coral Change Detection):** While identifying change directly on the 3D Gaussian splats is the primary objective, we also extract and review **distinct, model-specific 3D `.obj` surface meshes with `.mtl`/`.png` UV textures** (`--output_dir_tag <model>/<scene>`) for every underwater 3DGS method right now as a supporting output and bonus capability. In ecological coral reef monitoring (AIMS EcoRRAP), we often need to identify fine-scale **millimeter-to-centimeter ($\text{mm} \to \text{cm}$) changes in coral** (e.g., skeletal branching tip extension, plating accretion, bioerosion, or partial colony breakage). Comparing the 3D `.obj` models generated across different underwater 3DGS methods reveals which optical restoration approach produces cleaner, more accurate 3D surface reconstructions (free of water-column "floaters"), showing how pairing a higher-fidelity 3D reconstruction model with SuGaR can improve $\text{mm} \to \text{cm}$ coral change detection now and as a key future direction.

---

## 2. Supported Model Architectures

The suite manages 11 isolated Conda environments, automating all 6 stages (COLMAP, Depth Anything V2, Model Training, Per-Model SuGaR Mesh Extraction, and Benchmarking) across 8 leading architectures:

| Category | Model | Key Mechanism / Contribution | Outputs Evaluated |
|---|---|---|---|
| **Physics-Based 3DGS** | **SeaSplat** | Incorporates the Akkaynak-Treibitz physical oceanographic optical model directly into differentiable rendering. | `.ply` Splat + SuGaR `.obj` Mesh + NVS Metrics |
| **Physics-Based 3DGS** | **3D-UIR** | Homodirectional gradient regulation preventing floaters in backscatter-heavy marine water columns. | `.ply` Splat + SuGaR `.obj` Mesh + NVS Metrics |
| **Image Restoration 3DGS** | **Gaussian Splashing** | Coupled physical underwater degradation inversion with depth-guided Gaussian regularization. | `.ply` Splat + SuGaR `.obj` Mesh + NVS Metrics |
| **Image Restoration 3DGS** | **WaterSplatting** | Nerfstudio-native depth-guided medium compensation with separate scattering volumes. | `.ply` Splat + SuGaR `.obj` Mesh + NVS Metrics |
| **Supplementary 3DGS** | **RUSplatting** | Robust underwater Gaussian splatting with adaptive opacity pruning and RIFE frame synthesis. | `.ply` Splat + SuGaR `.obj` Mesh + NVS Metrics |
| **Supplementary 3DGS** | **UW-GS** | Density-guided underwater splatting with Background Medium Model (BMM) and depth prior alignment. | `.ply` Splat + SuGaR `.obj` Mesh + NVS Metrics |
| **Surface Geometry** | **SuGaR** | Surface-aligned 3D Gaussian Splatting (`dn_consistency`) for polygonal surface mesh extraction (`.obj`). | Standalone & Per-Model Coarse/Refined `.obj` Meshes |
| **Scene Change Detection**| **O-SCD** | Online Scene Change Detection in primitive space using MobileSAM and keypoint feature matching. | Updated `.ply`, 3D Heatmap `.ply`, `.obj` Mesh, Masks |

---

## 3. The End-to-End User Journey & `Model_Outputs` Workspace

The complete operational lifecycle is organized into 5 intuitive phases:

```
┌──────────────┐     ┌──────────────┐     ┌───────────────┐     ┌────────────────┐     ┌───────────────┐
│   1. SETUP   │ ──> │    2. RUN    │ ──> │  3. EXTRACT   │ ──> │  4. ORGANISE   │ ──> │   5. REVIEW   │
│ Provision    │     │ Orchestrate  │     │ Bundle & Sync │     │ Standardize    │     │ Visualize     │
│ 11 Envs & GPU│     │ 6-Stage Pipe │     │ from Cluster  │     │ for Supervisor │     │ Splats/Meshes │
└──────────────┘     └──────────────┘     └───────────────┘     └────────────────┘     └───────────────┘
```

### Workspace Directory Structure (`Model_Outputs/`)

The `Model_Outputs/` directory is the local evaluation, organization, and presentation workspace for all 15 model executions (including per-model `.ply` splats and `.obj` textured surface meshes).

> [!IMPORTANT]
> **Git Tracking Exclusion:** All large data files, point clouds (`.ply`), textured meshes (`.obj`, `.mtl`), UV textures (`.png`), renders, and unzipped output directories (`Model_Outputs/raw/`, `Model_Outputs/organized/`) are **strictly excluded from the Git repository** in `.gitignore`. Only the Python automation scripts and documentation are tracked.

```text
Model_Outputs/
├── organize_outputs.py          # Script 1: Reorganizes raw outputs into a clean supervisor hierarchy
├── collect_metrics.py           # Script 2: Aggregates quantitative metrics into LaTeX, Markdown & CSV
├── view_outputs.py              # Script 3: Interactive viewer for 3D Gaussians, SuGaR meshes & OSCD masks
├── generate_change_heatmaps.py  # Script 4: Synthesizes 3D thermal change heatmaps (.ply) & comparison videos (.mp4)
├── raw/                         # [GITIGNORED] Extracted raw archive from HPC (ump_15_outputs.tar.gz)
└── organized/                   # [GITIGNORED] Clean, presentation-grade directory for supervisors
    ├── 01_Physics_Based_3DGS/
    │   ├── SeaSplat/            (Kwaj & Tokai: distinct .ply splat, SuGaR .obj/.mtl/.png mesh, results.json)
    │   └── 3D-UIR/              (Kwaj & Tokai: distinct .ply splat, SuGaR .obj/.mtl/.png mesh, results.json)
    ├── 02_Image_Restoration_3DGS/
    │   ├── Gaussian_Splashing/  (Kwaj & Tokai: distinct .ply splat, SuGaR .obj/.mtl/.png mesh, results.json)
    │   └── WaterSplatting/      (Kwaj & Tokai: distinct .ply splat, SuGaR .obj/.mtl/.png mesh, results.json)
    ├── 03_Supplementary_3DGS/
    │   ├── RUSplatting/         (Kwaj & Tokai: distinct .ply splat, SuGaR .obj/.mtl/.png mesh, results.json)
    │   └── UW-GS/               (Kwaj & Tokai: distinct .ply splat, SuGaR .obj/.mtl/.png mesh, results.json)
    ├── 04_Surface_Geometry_Mesh/
    │   └── SuGaR/               (Kwaj & Tokai: standalone baseline coarse & refined .obj/.mtl/.png meshes)
    ├── 05_Scene_Change_Detection/
    │   └── O-SCD/               (updated_scene.ply, 3D change heatmaps .ply, oscd.obj, change_masks/, videos)
    ├── master_benchmark_table.md   # Markdown summary table
    ├── master_benchmark_table.tex  # Academic LaTeX table for thesis/paper
    ├── master_benchmark_table.csv  # Spreadsheet export
    └── PORTFOLIO_INDEX.md          # Clickable supervisor navigation guide
```

### Recommended Desktop Viewing Tools (Ubuntu & Blender)

Before reviewing outputs locally, install the recommended visualization tools:

```bash
# 1. 3D Textured Surface Mesh Viewer (MeshLab)
sudo apt update && sudo apt install -y meshlab

# 2. Raw Geometry & Point Cloud Inspector (CloudCompare)
# Note: CloudCompare inspects raw (x,y,z) coordinate points and scalar distributions.
# To render the true continuous volumetric Gaussian Splat, use SuperSplat WebGL in your browser.
sudo snap install cloudcompare

# 3. Blender (For inspecting & rendering per-model .obj + .mtl + .png textured meshes)
sudo snap install blender --classic

# 4. Python visualization packages (for built-in Open3D, Matplotlib, and heatmap generation)
pip install matplotlib open3d opencv-python plyfile scipy
```

> [!TIP]
> **Viewing & Saving `.obj` + `.mtl` Textured Meshes in Blender:**
> 1. Ensure the `.obj`, `.mtl`, and `.png` files for a model reside in the same folder (automatically handled by `organize_outputs.py`).
> 2. Open Blender $\to$ **File $\to$ Import $\to$ Wavefront (.obj)** and select `<Model>_<Scene>_refined_mesh.obj`.
> 3. Press **`Z`** in the 3D Viewport and select **Material Preview** (or click the **Viewport Shading: Material Preview** globe icon in the top-right corner) to display the UV-baked `.png` textures immediately.
> 4. In the Shader Editor, set **Roughness = `1.0`** and **Specular = `0.0`** on the `Principled BSDF` node to inspect raw photogrammetric surface colors without artificial gloss.
> 5. To save a clean, high-resolution screenshot without UI clutter: toggle **Show Overlays** off (top-right overlapping circles icon), set `Output Properties` resolution (e.g., `3840 x 2160`), and select **View $\to$ Viewport Render Image** (then **Image $\to$ Save As**).

---

### Phase 1: Setup (Environment & GPU Verification)
Execute the automated provisioning script to install system tools, set up CUDA, clone rasterizer submodules, and build isolated Conda environments:

```bash
# Provision everything automatically (or target specific components)
bash Codebase/scripts/setup_env.sh --all

# Pre-flight diagnostic check (verifies GPU compute, Conda environments, and dataset integrity)
bash Codebase/scripts/verify_env.sh --all-envs
```

---

### Phase 2: Run (Master Pipeline Orchestration)
Run the turnkey automation pipeline (`Codebase/scripts/run_pipeline.sh`) on either your local workstation or the QUT Aqua HPC cluster:

```bash
# A. Dry-run to inspect the execution graph without modifying files
bash Codebase/scripts/run_pipeline.sh --model seasplat --scene Kwaj --dry-run

# B. Execute a single underwater model end-to-end (Stages 1 to 6, including per-model SuGaR .obj mesh)
bash Codebase/scripts/run_pipeline.sh --model seasplat --scene Kwaj

# C. Re-run ONLY Stage 5 (SuGaR 3D surface mesh extraction) for each underwater model using existing .ply priors
for model in seasplat 3d-uir gaussiansplashing watersplatting rusplatting uw-gs sugar; do
    for scene in Kwaj Tokai; do
        bash Codebase/scripts/run_pipeline.sh --model "${model}" --scene "${scene}" --stage mesh
    done
done

# D. Execute scene change detection on a dual-photo dataset
bash Codebase/scripts/run_pipeline.sh --model oscd --dataset Dataset/Custom_OSCD_Dataset

# E. Submit as a high-performance batch job on QUT Aqua HPC (NVIDIA H100/A100)
qsub HPC/scripts/run_pipeline.pbs
```

---

### Phase 3: Extract (Transfer from HPC to Local Desktop)
When running on the HPC cluster, bundle all 15 models' evaluation artifacts (including per-model `.obj`/`.mtl`/`.png` meshes) using the manifest-based packager:

1. **On the HPC Cluster (`aqua`):**
   ```bash
   cd ~/EUAPGM7346/UMP
   bash HPC/scripts/package_outputs.sh
   ```
   *(This builds `ump_15_outputs.tar.gz` containing all final `.ply` splats, per-model `.obj`/`.mtl`/`.png` meshes, `.png` change masks, and `results.json` metrics).*

2. **On Your Local Desktop (Connected to QUT VPN):**
   ```bash
   # Download at maximum speed via QUT's dedicated Data Transfer Node (eresdtn01):
   rsync -avzP n11585382@eresdtn01.qut.edu.au:~/EUAPGM7346/UMP/ump_15_outputs.tar.gz ~/Downloads/

   # Unpack into Model_Outputs/raw (or ~/UMP_15_outputs):
   mkdir -p Model_Outputs/raw
   tar -xzvf ~/Downloads/ump_15_outputs.tar.gz -C Model_Outputs/raw/
   ```

---

### Phase 4: Organise (`organize_outputs.py`)
Transform the raw directory crawl into a standardized academic portfolio:

```bash
# Uses fast symbolic links by default (instantaneous, consumes 0 extra disk space):
python Model_Outputs/organize_outputs.py --input Model_Outputs/raw --output Model_Outputs/organized

# Or create standalone physical file copies (recommended when copying across drives/OS):
python Model_Outputs/organize_outputs.py --input Model_Outputs/raw --output Model_Outputs/organized --mode copy
```

This creates `Model_Outputs/organized/` grouped by research domain (`01_Physics_Based_3DGS`, `02_Image_Restoration_3DGS`, `03_Supplementary_3DGS`, `04_Surface_Geometry_Mesh`, `05_Scene_Change_Detection`), automatically matching each model's own namespaced SuGaR mesh (`<Model>_<Scene>_refined_mesh.obj`), rewriting internal `.mtl` texture references so textures load out-of-the-box in Blender/MeshLab, and building `PORTFOLIO_INDEX.md`.

---

### Phase 5: Review, Evaluate & Heatmaps

1. **Compile Quantitative Comparison Tables (`collect_metrics.py`):**
   ```bash
   python Model_Outputs/collect_metrics.py
   ```
   Generates:
   - **`master_benchmark_table.tex`**: Complete LaTeX table using `booktabs` formatted for your thesis or paper.
   - **`master_benchmark_table.md`**: Markdown table viewable directly in GitHub / VS Code.
   - **`master_benchmark_table.csv`**: CSV spreadsheet export.
   - **`master_benchmark_table.json`**: Structured JSON metrics data.

2. **Interactive 3D Visualizer Terminal (`view_outputs.py`):**
   ```bash
   python Model_Outputs/view_outputs.py
   ```
   Select any model by number from the terminal menu:
   - **3D Gaussian Splats (`.ply`):** Choose **[1]** to launch **[SuperSplat](https://playcanvas.com/supersplat/editor)** WebGL in your browser for photorealistic volumetric 3DGS rendering at 60 FPS, or **[2]** for raw coordinate inspection in CloudCompare.
   - **3D Change Heatmap Splats (`.ply`):** Press **[H]** or select O-SCD $\to$ **[h]** to view the scene where changed objects glow in bright 3D thermal flame red/yellow in SuperSplat.
   - **Reconstructed Video Heat Maps (`.mp4`):** Press **[V]** or select O-SCD $\to$ **[v]** to play the full-resolution camera sweep video with glowing thermal change overlays and 3-panel side-by-side comparison.
   - **Per-Model Textured Meshes (`.obj`):** Launches MeshLab or Blender with automatic `.mtl`/`.png` texture bindings so you can compare surface geometry quality across `SeaSplat`, `3D-UIR`, `Gaussian Splashing`, `WaterSplatting`, `RUSplatting`, `UW-GS`, and `SuGaR`.
   - **OSCD Change Maps (2D):** Type **`[M]`** to launch an interactive Matplotlib gallery displaying the rendered 2D change masks.
   - **Master Benchmark Table:** Type **`[T]`** to print the formatted comparative metrics in your terminal.

3. **Synthesize 3D & Video Change Heatmaps (`generate_change_heatmaps.py`):**
   ```bash
   python Model_Outputs/generate_change_heatmaps.py
   ```
   Automatically produces:
   1. `O-SCD_3D_Change_Heatmap_Hybrid.ply` (Photorealistic room context with glowing thermal flame red on changed objects).
   2. `O-SCD_3D_Change_Heatmap_Turbo.ply` (Full 3D scientific false-color thermal spectrum).
   3. `oscd_change_heatmap_overlay.mp4` (Full 1080p camera sweep video with thermal change overlays and glowing contours).
   4. `oscd_change_comparison_3panel.mp4` (Synchronized 3-panel comparison video: `[Inspection RGB] | [Thermal Heatmap Overlay] | [Binary Mask]`).
   5. `oscd_change_keyframe_strip.png` (High-resolution multi-view comparison figure ready for your thesis/paper).

---

## 4. Dataset Ingestion Guide

### A. Pre-Configured Datasets
The repository comes pre-configured with:
1. **Submerged3D (`Dataset/Submerged3D/`):** Contains challenging real-world underwater photogrammetric surveys across `Kwaj` (Kwajalein shipwreck) and `Tokai` (Tokai Maru shipwreck).
2. **Custom OSCD Dataset (`Dataset/Custom_OSCD_Dataset/`):** A dual-photo dataset captured with a smartphone camera depicting a table scene where objects were added and removed between passes (`reference_scene` vs `inference_scene`).

---

### B. Bringing Any Custom Underwater Dataset
To run the full 6-stage underwater pipeline on **your own underwater photos or video**:

1. **Directory Structure:**
   Organize your dataset under `Dataset/` or any local folder with an `input/` (or `images/`) directory:
   ```text
   Dataset/My_Underwater_Site/
   └── Reef_Zone_A/
       └── input/
           ├── frame_00001.jpg
           ├── frame_00002.jpg
           └── ... (50-200 overlapping images)
   ```

2. **Capture Guidelines for Underwater 3DGS:**
   - **Overlap:** Ensure $\ge 70\%$ forward overlap and $\ge 60\%$ side overlap between consecutive frames.
   - **Coverage:** Walk or swim in a smooth orbital or lawnmower pattern around the subject at constant depth/distance.
   - **Lighting:** Avoid turning video lights on/off during capture to maintain photogrammetric consistency.

3. **Running the Pipeline:**
   ```bash
   # Run SeaSplat on your custom scene:
   bash Codebase/scripts/run_pipeline.sh \
       --model seasplat \
       --dataset Dataset/My_Underwater_Site \
       --scene Reef_Zone_A

   # Or run all underwater models on your scene:
   bash Codebase/scripts/run_pipeline.sh \
       --all \
       --dataset Dataset/My_Underwater_Site \
       --scene Reef_Zone_A
   ```
   *The pipeline automatically performs COLMAP feature extraction, Depth-Anything-V2 depth estimation and optical inversion, neural Gaussian training, model-namespaced SuGaR textured mesh extraction, and novel view benchmarking.*

---

### C. Bringing Any Custom Dual-Photo Change Detection Dataset
To detect physical scene modifications between two states (e.g. baseline vs modified, object added/removed, structural damage, or coral growth/breakage):

1. **Option 1: Extract Directly from Smartphone Videos (`prepare_oscd_dataset.py`)**
   Record two short 20–40 second videos covering the same scene:
   - Video 1: Baseline state (`video_reference.mp4`)
   - Video 2: Modified state (`video_inference.mp4`)

   Run the automated dataset generator:
   ```bash
   python Codebase/scripts/prepare_oscd_dataset.py \
       --video-ref /path/to/video_reference.mp4 \
       --video-inf /path/to/video_inference.mp4 \
       --output-dir Dataset/My_Custom_Change_Scene \
       --fps 4.0 --select-sharpest
   ```
   *This automatically samples frames, eliminates motion blur using Laplacian variance, and formats the output into `reference_scene/input/` and `inference_scene/input/`.*

2. **Option 2: Using Photo Sets (DSLR / Action Camera / Phone Photos)**
   Structure your images as follows:
   ```text
   Dataset/My_Custom_Change_Scene/
   ├── reference_scene/
   │   └── input/
   │       ├── 001.jpg
   │       └── ... (baseline images)
   └── inference_scene/
       └── input/
           ├── 001.jpg
           └── ... (modified inspection images)
   ```

3. **Running the Change Detection Pipeline:**
   ```bash
   bash Codebase/scripts/run_pipeline.sh \
       --model oscd \
       --dataset Dataset/My_Custom_Change_Scene
   ```
   *The pipeline trains the reference 3DGS model, triangulates spatial correspondences, segments changed regions using MobileSAM, prunes and inserts 3D Gaussians (`updated_scene.ply`), exports a differential SuGaR mesh (`.obj`), and writes quantitative change metrics.*

---

## 5. Future Research Direction: Temporal Underwater OSCD for Coral Reef Monitoring

```
========================================================================================
                      FUTURE WORK ARCHITECTURAL PARADIGM:
              TEMPORAL UNDERWATER PRIMITIVE-SPACE CHANGE DETECTION
========================================================================================

 [Temporal Capture T0: Baseline Site]             [Temporal Capture T1: Inspection Site]
  - Raw images with turbidity & haze               - Raw images with different turbidity
                │                                                    │
                ▼                                                    ▼
  ┌───────────────────────────────┐                                  │
  │   Underwater-Optimised 3DGS   │                                  │
  │ (SeaSplat / 3D-UIR / Splashing)│                                 │
  └───────────────┬───────────────┘                                  │
                  ▼                                                  │
  ┌───────────────────────────────┐                                  │
  │    SuGaR Surface Extraction   │                                  │
  │  - Enforce SDF / Normal Prior │                                  │
  │  - Prune Turbidity Floaters   │                                  │
  │  - Export Per-Model .obj Mesh │                                  │
  └───────────────┬───────────────┘                                  │
                  ▼                                                  │
       Clean Geometry-Anchored                                       │
        Turbidity-Free 3DGS Prior                                    │
                  │                                                  │
                  └───────────────────────┬──────────────────────────┘
                                          ▼
                         ┌─────────────────────────────────┐
                         │   Primitive-Space OSCD Engine   │
                         │  - Track T1 against T0 prior    │
                         │  - Invariant to water haze      │
                         │  - Detect genuine physical shift│
                         └────────────────┬────────────────┘
                                          ▼
                      ┌───────────────────────────────────────┐
                      │    Differential 3D Analysis & Mesh    │
                      │  - Millimeter-to-Centimeter (mm -> cm)│
                      │    Coral Growth / Erosion Metrology   │
                      │  - Structural Defect Detection        │
                      └───────────────────────────────────────┘
========================================================================================
```

### The Concept & Why Per-Model 3D Surface Meshes Are Essential
Currently, change detection (`O-SCD`) and underwater 3DGS operate as modular stages. The capstone Phase 3 integration unites them into an end-to-end framework tailored for fine-scale ecological reef monitoring (AIMS EcoRRAP):

1. **The Motivation ($\text{mm} \to \text{cm}$ Coral Metrology):** Standard change detection algorithms fail when applied to underwater photo sets taken months apart because differing water turbidity, sunlight caustics, and suspended marine snow trigger false change detections. Furthermore, coral colonies grow or erode at fine spatial scales—often **millimeters to centimeters ($\text{mm} \to \text{cm}$)** per monitoring interval (e.g., *Acropora* branch tip extension, partial colony mortality, or skeletal erosion). Detecting $\text{mm} \to \text{cm}$ geometric shifts requires a sharp, geometrically accurate 3D surface boundary rather than a fuzzy cloud of semi-transparent ellipsoids.
2. **Why We Generate and Review 3D `.obj` Meshes Across All Underwater Models:** Different underwater 3DGS approaches handle backscatter and depth regularization differently—some optimize novel-view PSNR by placing semi-transparent "floater" Gaussians in front of the camera, which corrupts downstream Poisson/SDF surface reconstruction. By generating a distinct SuGaR `.obj` mesh for every candidate underwater 3DGS model (`SeaSplat`, `3D-UIR`, `Gaussian Splashing`, `WaterSplatting`, `RUSplatting`, `UW-GS`), we directly evaluate which method produces the cleanest, highest-fidelity 3D surface geometry capable of supporting $\text{mm} \to \text{cm}$ coral change detection.
3. **The Unified Mechanism:**
   - **Step 1 ($T_0$ Baseline):** Capture multi-view images of a coral reef colony. Run through the top-performing **underwater-optimised 3DGS model** (`3D-UIR` / `Gaussian Splashing` / `WaterSplatting`) to remove water-column attenuation and backscatter. Then run **SuGaR** to anchor Gaussian primitives onto the true coral skeleton surface, pruning water-column floaters and exporting a baseline `.obj` mesh.
   - **Step 2 ($T_1$ Inspection):** Capture the reef site at a future time. Feed the $T_0$ restored, surface-aligned 3DGS model as the reference geometry prior into **O-SCD**.
   - **Step 3 (Primitive-Space Delta):** Because the $T_0$ model is physically restored and surface-bounded, O-SCD detects **genuine physical changes** ($\text{mm} \to \text{cm}$ coral growth, branching breakage, or bleaching) in primitive space, immune to temporal variations in water turbidity.
   - **Step 4 (Volumetric & Surface Quantitation):** Run SuGaR on the updated Gaussian delta to compute exact physical volume ($\text{cm}^3$) and surface displacement ($\text{mm} \to \text{cm}$) metrics.

---

## 6. Master Quantitative Benchmark Portfolio (15 / 15 Succeeded)

All 15 target model pipelines have achieved **100% full-lifecycle completion** across all 6 stages on the QUT Aqua HPC cluster:

| # | Research Domain | Architecture | Scene | Status | Duration | PSNR (dB) $\uparrow$ | SSIM $\uparrow$ | LPIPS $\downarrow$ | 3D Artifacts Exported |
|---|---|---|---|---|:---:|:---:|:---:|:---:|:---|
| **1** | Physics-Based 3DGS | `3D-UIR` | `Kwaj` | **SUCCESS** | 1h 11m 20s | **27.00** | **0.8739** | 0.1812 | `.ply` Splat + `.obj` Mesh |
| **2** | Physics-Based 3DGS | `3D-UIR` | `Tokai` | **SUCCESS** | 1h 18m 29s | **23.78** | **0.7085** | 0.3311 | `.ply` Splat + `.obj` Mesh |
| **3** | Physics-Based 3DGS | `SeaSplat` | `Kwaj` | **SUCCESS** | 1h 02m 11s | **24.60** | **0.8341** | 0.2296 | `.ply` Splat + `.obj` Mesh |
| **4** | Physics-Based 3DGS | `SeaSplat` | `Tokai` | **SUCCESS** | 59m 03s | **21.93** | **0.6737** | 0.3926 | `.ply` Splat + `.obj` Mesh |
| **5** | Restoration 3DGS | `Gaussian Splashing` | `Kwaj` | **SUCCESS** | 2h 32m 37s | **27.93** | **0.8394** | 0.2081 | `.ply` Splat + `.obj` Mesh |
| **6** | Restoration 3DGS | `Gaussian Splashing` | `Tokai` | **SUCCESS** | 4h 57m 07s | **24.32** | **0.6142** | 0.3766 | `.ply` Splat + `.obj` Mesh |
| **7** | Restoration 3DGS | `WaterSplatting` | `Kwaj` | **SUCCESS** | 38m 42s | **27.12** | **0.8635** | **0.1714** | `.ply` Splat + `.obj` Mesh |
| **8** | Restoration 3DGS | `WaterSplatting` | `Tokai` | **SUCCESS** | 48m 15s | **23.52** | **0.6588** | **0.3048** | `.ply` Splat + `.obj` Mesh |
| **9** | Supplementary 3DGS | `RUSplatting` | `Kwaj` | **SUCCESS** | 50m 16s | **26.56** | **0.8620** | 0.2045 | `.ply` Splat + `.obj` Mesh |
| **10**| Supplementary 3DGS | `RUSplatting` | `Tokai` | **SUCCESS** | 53m 24s | **21.41** | **0.6490** | 0.4229 | `.ply` Splat + `.obj` Mesh |
| **11**| Supplementary 3DGS | `UW-GS` | `Kwaj` | **SUCCESS** | 51m 15s | **24.64** | **0.8432** | 0.2286 | `.ply` Splat + `.obj` Mesh |
| **12**| Supplementary 3DGS | `UW-GS` | `Tokai` | **SUCCESS** | 1h 03m 29s | **21.43** | **0.6387** | 0.4364 | `.ply` Splat + `.obj` Mesh |
| **13**| Surface Geometry | `SuGaR` (Standalone) | `Kwaj` | **SUCCESS** | 38m 41s | -- | -- | -- | Coarse & Refined `Kwaj.obj` |
| **14**| Surface Geometry | `SuGaR` (Standalone) | `Tokai` | **SUCCESS** | 32m 11s | -- | -- | -- | Coarse & Refined `Tokai.obj` |
| **15**| Scene Change Det. | **`O-SCD`** | `Custom_OSCD` | **SUCCESS** | 1h 04m 06s | **27.08** | **0.8315** | 0.3440 | Updated `.ply`, Heatmap `.ply`, `oscd.obj` |

*All quantitative data can be regenerated locally using `python Model_Outputs/collect_metrics.py`.*

---

## 7. Repository Structure & Living Brain Documentation

```text
UMP/
├── README.md                      # Master user, research & Model_Outputs evaluation documentation
├── 1A/                            # Assessment 1A: Literature Review submission
├── 1B/                            # Assessment 1B: Project Proposal submission
├── 2B/                            # Assessment 2B: Progress Report LaTeX source & compiled PDF
├── agentdocs/                     # Living brain documentation system
│   ├── README.md                  # Index & AI agent directives
│   ├── overview.md                # High-level architecture & project goals
│   ├── pipeline_and_scripts.md    # Technical bash & Conda environment manual
│   ├── HPC_Guide.md               # QUT Aqua cluster reference & PBS job guides
│   ├── attempt_10_verification.md # Final milestone report (15/15 Succeeded)
│   └── change_log.md              # Detailed chronological audit trail
├── Codebase/
│   ├── 3DGS-Change-Detection/     # O-SCD algorithm & keypoint tracking
│   ├── 3DGS-Water-Approaches/     # Underwater 3DGS models (Physics, Image, SuGaR)
│   ├── scripts/                   # run_pipeline.sh, setup_env.sh, verify_env.sh
│   └── Tools/                     # COLMAP conversion & photogrammetry utilities
├── Dataset/                       # Storage for Submerged3D & Custom_OSCD_Dataset
├── HPC/                           # PBS job scripts (run_pipeline.pbs, package_outputs.sh) & Guides
├── Model_Outputs/                 # Local evaluation, reordering, heatmap & viewer toolchain
│   ├── organize_outputs.py        # Output reordering, per-model mesh matching & .mtl fixing tool
│   ├── collect_metrics.py         # LaTeX / Markdown / CSV table generator
│   ├── view_outputs.py            # Interactive 3D splat, mesh & mask visualizer
│   └── generate_change_heatmaps.py# 3D thermal change splat (.ply) & video (.mp4) synthesizer
└── Literature/                    # Master bibliography (references.bib) & papers
```

For in-depth forensic analysis and execution logs from earlier iterations, refer to:
- [Attempt 6 Failure Analysis](./agentdocs/attempt_6_failure_analysis.md)
- [Attempt 7 Failure Analysis](./agentdocs/attempt_7_failure_analysis.md)
- [Attempt 8 Failure Analysis](./agentdocs/attempt_8_failure_analysis.md)
- [Attempt 9 Failure Analysis](./agentdocs/attempt_9_failure_analysis.md)
- [Attempt 10 Verification Report](./agentdocs/attempt_10_verification.md)
