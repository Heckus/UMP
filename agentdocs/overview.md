# Project Overview

This repository is the central workspace for a QUT (Queensland University of Technology) Engineering project/thesis, focusing on the **"Investigation of Primitive-Space Scene Change Detection in Under-water 3D Gaussian Splatting Models"**.

---

## 1. **[KEY-CONCEPT]** Core Research Objective

The primary objective of this project is to investigate and develop methods for detecting scene changes directly within the **primitive space** (the 3D Gaussians themselves) of 3D Gaussian Splatting (3DGS) models, with a specific focus on challenging underwater environments. This involves:
1. **Primary Goal — Primitive-Space Scene Change Detection (`O-SCD`):** Implementing primitive-space Online Scene Change Detection (`GS-DIFF` / `O-SCD`) to track, segment, and update 3D Gaussians across temporal states without retraining the entire representation from scratch.
2. **Evaluating Underwater 3DGS Formulations:** Analyzing existing 3DGS architectures (`SeaSplat`, `3D-UIR`, `Gaussian Splashing`, `WaterSplatting`, `RUSplatting`, `UW-GS`) and adapting them for underwater optical degradation (wavelength-dependent absorption, backscatter, haze).
3. **Per-Model 3D Surface Geometry Extraction & Review (`SuGaR` — Supporting Output & Bonus Feature):**
   - **Literature Motivation:** The foundational 3D change detection paper (`GS-DIFF` / `O-SCD`, Galappaththige et al., 2026) explicitly recommended at the conclusion of their paper integrating the **SuGaR** surface regularization method to bind 3D Gaussians to physical surfaces and mitigate Gaussian drift—which directly motivated integrating SuGaR here.
   - **Why Per-Model 3D `.obj` Meshes Are Generated & Reviewed Right Now ($\text{mm} \to \text{cm}$ Coral Change):** While identifying change using the 3D Gaussian splats is the main goal, we also produce and review **distinct 3D surface models (`.obj` + `.mtl` + `.png`) for each underwater 3DGS method** (`--output_dir_tag <model>/<scene>`) right now as a supporting output and bonus capability. Because ecological coral monitoring (AIMS EcoRRAP) frequently requires identifying fine-scale **millimetre-to-centimetre ($\text{mm} \to \text{cm}$) changes in coral**, reviewing the 3D `.obj` reconstructions across methods reveals whether different underwater 3DGS models yield cleaner, more accurate 3D geometry that can support $\text{mm} \to \text{cm}$ change detection now or as a future direction.

---

## 2. **[KEY-CONCEPT]** The 5-Phase Operational Lifecycle

The entire pipeline is structured into a reproducible 5-phase lifecycle:

```
┌──────────────┐     ┌──────────────┐     ┌───────────────┐     ┌────────────────┐     ┌───────────────┐
│   1. SETUP   │ ──> │    2. RUN    │ ──> │  3. EXTRACT   │ ──> │  4. ORGANISE   │ ──> │   5. REVIEW   │
│ Provision    │     │ Orchestrate  │     │ Bundle & Sync │     │ Standardize    │     │ Visualize     │
│ 11 Envs & GPU│     │ 6-Stage Pipe │     │ from Cluster  │     │ for Supervisor │     │ Splats/Meshes │
└──────────────┘     └──────────────┘     └───────────────┘     └────────────────┘     └───────────────┘
```

1. **Setup (`setup_env.sh` & `verify_env.sh`):** Installs system dependencies, provisions CUDA/rasterizer submodules, creates 11 isolated Conda environments, and performs pre-flight GPU/dataset sanity checks.
2. **Run (`run_pipeline.sh` / `run_pipeline.pbs`):** Executes the 6-stage pipeline (Data Preparation, COLMAP, Depth Estimation/Inversion, Model Training, Per-Model SuGaR Mesh Extraction via `--output_dir_tag <model>/<scene>`, Benchmarking).
3. **Extract (`package_outputs.sh` & `rsync`):** Packages verified evaluation artifacts (including per-model `.ply` splats and `.obj`/`.mtl`/`.png` 3D meshes) on the HPC cluster using dynamic manifests and transfers them to the local Ubuntu desktop via the dedicated Data Transfer Node (`eresdtn01.qut.edu.au`).
4. **Organise (`Model_Outputs/organize_outputs.py`):** Reorders raw outputs into a 5-domain academic hierarchy (`01_Physics_Based_3DGS`, `02_Image_Restoration_3DGS`, etc.) with strict per-model mesh matching (`<Model>_<Scene>_refined_mesh.obj`), automatic `.mtl` texture fixing, and a clickable `PORTFOLIO_INDEX.md`.
5. **Review & Evaluate (`Model_Outputs/collect_metrics.py` & `view_outputs.py`):**
   - Compiles master benchmark tables in LaTeX (`master_benchmark_table.tex`), Markdown, CSV, and JSON.
   - Interactively visualizes 3D splats (CloudCompare / SuperSplat WebGL), per-model 3D surface meshes (MeshLab / Blender), and 2D change masks.

---

## 3. **[KEY-CONCEPT]** Dataset Ingestion: Supported & Custom Workflows

The repository supports both built-in benchmarks and arbitrary user-provided datasets:

### A. Pre-Configured Benchmark Datasets
- **Submerged3D (`Dataset/Submerged3D/`):** Real-world underwater shipwreck photogrammetry across two primary scenes: `Kwaj` (Kwajalein Prince Eugen shipwreck) and `Tokai` (Tokai Maru shipwreck).
- **Custom OSCD Dataset (`Dataset/Custom_OSCD_Dataset/`):** A dual-scene change detection dataset captured with a smartphone camera depicting a table scene where objects were added and removed between passes (`reference_scene` vs `inference_scene`).

### B. Ingesting ANY Custom Underwater Dataset
New users can ingest arbitrary underwater video or multi-view photo sets by structuring images as:
```text
Dataset/<Custom_Underwater_Dataset>/
└── <Scene_Name>/
    └── input/
        ├── frame_00001.jpg
        └── ... (overlapping underwater images)
```
Run the master pipeline:
```bash
bash Codebase/scripts/run_pipeline.sh --model seasplat --dataset Dataset/<Custom_Underwater_Dataset> --scene <Scene_Name>
```

### C. Ingesting ANY Custom Dual-Photo Change Detection Dataset
New users can detect physical scene changes between any two states (baseline vs modified):
1. **From Video (`prepare_oscd_dataset.py`):** Record two videos (`video_ref.mp4` and `video_inf.mp4`) and run:
   ```bash
   python Codebase/scripts/prepare_oscd_dataset.py --video-ref ref.mp4 --video-inf inf.mp4 --output-dir Dataset/<Custom_OSCD> --fps 4.0 --select-sharpest
   ```
2. **From Photo Sets:** Place images into `reference_scene/input/` and `inference_scene/input/`.
3. **Run Pipeline:**
   ```bash
   bash Codebase/scripts/run_pipeline.sh --model oscd --dataset Dataset/<Custom_OSCD>
   ```

---

## 4. **[CRITICAL]** Future Work Architecture: Temporal Underwater OSCD

The ultimate research vision for this repository is uniting underwater optical compensation with primitive-space change detection for **temporal underwater monitoring**:

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
                      │  - Quantitative Volumetric Change     │
                      │  - Marine Biofouling / Coral Growth   │
                      │  - Structural Defect Detection        │
                      └───────────────────────────────────────┘
========================================================================================
```

### Theoretical Mechanism:
1. **The Marine Problem:** In multi-temporal underwater monitoring (coral reef growth/bleaching, marine pipeline erosion, subsea infrastructure damage), surveys at timestamp $T_0$ (baseline) and $T_1$ (inspection) suffer from different water turbidity, floating marine snow, and seasonal ambient light. Standard change detection models falsely register these water column variations as structural changes.
2. **The Integrated Solution:**
   - **Step 1 ($T_0$ Baseline):** Run the $T_0$ underwater image set through an **underwater-optimised 3DGS model** (SeaSplat, 3D-UIR, or WaterSplatting) to invert optical attenuation. Then run **SuGaR** to regularize Gaussians onto true physical surfaces, stripping away all floating water-column primitives.
   - **Step 2 ($T_1$ Inspection):** Ingest the $T_1$ images into **OSCD**, using the restored $T_0$ Gaussian model as the reference geometry prior.
   - **Step 3 (Primitive Delta):** Because the $T_0$ prior is optically clean and surface-bounded, OSCD detects **genuine physical modifications** directly in primitive space without false positives caused by water haze.
   - **Step 4 (Volumetric Quantitation):** Run SuGaR on the updated scene delta to extract exact volumetric and surface-area change measurements ($cm^3$ or $m^2$).

---

## 5. **[KEY-CONCEPT]** Master 15 / 15 Benchmark Milestone

As of Attempt 10 (October 13, 2026), all 15 benchmark targets across 8 models and 3 datasets have achieved **100% full-lifecycle execution** across all 6 stages. Full details are documented in [`attempt_10_verification.md`](./attempt_10_verification.md) and [`HPC_Guide.md`](./HPC_Guide.md).

---

## 6. Repository Structure

- **`1A/` & `1B/`**: Academic submissions (Literature Review Assessment 1A, Project Proposal 1B).
- **`Codebase/`**: Core implementations:
  - `3DGS-Change-Detection/`: Source code and experiments for scene change detection (O-SCD).
  - `3DGS-Water-Approaches/`: Underwater 3DGS models (Physics, Image Restoration, SuGaR).
  - `scripts/`: Production-grade bash automation suite (`run_pipeline.sh`, `setup_env.sh`, `verify_env.sh`, `prepare_oscd_dataset.py`).
  - `Tools/`: Utility scripts and COLMAP photogrammetry converters.
- **`Dataset/`**: Storage for `Submerged3D` and `Custom_OSCD_Dataset`.
- **`HPC/`**: High-Performance Computing scripts (`run_pipeline.pbs`, `package_outputs.sh`) and Aqua cluster documentation (`HPC/Guides/`).
- **`Model_Outputs/`**: Local evaluation, reordering, and visualization toolchain (`organize_outputs.py`, `collect_metrics.py`, `view_outputs.py`).
- **`Literature/`**: Research papers and master bibliography (`references.bib`).
- **`agentdocs/`**: Living documentation brain maintained by AI agents to preserve project context.
