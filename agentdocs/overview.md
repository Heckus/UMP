# Project Overview

This repository is the central workspace for a QUT (Queensland University of Technology) Engineering project/thesis, focusing on the **"Investigation of Primitive-Space Scene Change Detection in Under-water 3D Gaussian Splatting Models"**.

## **[KEY-CONCEPT]** Core Objective

The primary objective of this project is to investigate and develop methods for detecting scene changes directly within the primitive space (the Gaussians themselves) of 3D Gaussian Splatting (3DGS) models, with a specific focus on challenging underwater environments. This involves analyzing existing 3DGS architectures, adapting them for underwater optical properties, and implementing robust change detection algorithms.

## Repository Structure

The repository is organized into distinct sections to support both the academic and software development components of the thesis:

- **`1A/` & `1B/`**: Contain academic submissions. `1A` houses the Literature Review (Assessment 1A), and `1B` contains the Project Proposal. Both include LaTeX source files and the resulting compiled PDFs.
- **`Codebase/`**: The main directory for software development, experiments, and data management. It includes:
  - `3DGS-Change-Detection/`: Source code and experiments specifically for scene change detection in 3DGS.
  - `3DGS-Water-Approaches/`: Code adapting 3DGS for underwater environments (addressing turbidity, lighting, etc.).
  - `Dataset/`: Storage for datasets used in training and evaluation.
  - `scripts/`: Production-grade bash automation suite for environment provisioning, multi-model training pipelines, and pre-flight validation (`setup_env.sh`, `run_pipeline.sh`, `verify_env.sh`). Detailed documentation is available in [`pipeline_and_scripts.md`](./pipeline_and_scripts.md).
  - `Tools/` & `src/`: Utility scripts and core source code.
  - `open_source_models.md`: A curated reference list of relevant open-source 3DGS models and repositories.
- **`Literature/`**: A comprehensive collection of research papers (PDFs) and the master bibliography (`references.bib`) covering 3DGS, underwater imaging, and change detection.
- **`QUT_Thesis_Template_DO_NOT_TOUCH/`**: The official LaTeX template for the final QUT thesis document.
- **`agentdocs/`**: The living documentation system maintained by AI agents to preserve project context and provide instructions for future development sessions.

## **[KEY-CONCEPT]** Automation Scripts Suite (`Codebase/scripts/`)

To support reproducible training, data preparation, and evaluation across diverse 3DGS and OSCD architectures, a production-grade one-shot bash scripting suite is maintained in `Codebase/scripts/`:

- **`setup_env.sh` (Automated Environment Setup)**:
  Provisions Ubuntu system dependencies (`apt-get`), NVIDIA proprietary drivers (`ubuntu-drivers autoinstall`), Miniconda3 bootstrap, Git submodule repair (cloning missing rasterizers and CUDA kernels), and automated creation of 11 isolated Conda environments with sanitized Linux recipes. Supports `--all`, `--system-deps`, `--drivers`, `--conda`, `--env <name>`, `--dry-run`, and `-y`.
- **`run_pipeline.sh` (Master Orchestration Pipeline)**:
  Orchestrates the complete 6-stage end-to-end execution workflow: (1) Data Preparation & Download, (2) COLMAP Sparse Reconstruction, (3) Depth Map Estimation & Inversion (Depth-Anything-V2 / RIFE), (4) Model Training (supporting 8 models: SeaSplat, 3D-UIR, Gaussian Splashing, WaterSplatting, RUSplatting, UW-GS, SuGaR, OSCD), (5) Surface Mesh Extraction (SuGaR), and (6) Benchmarking & Metrics Evaluation (`results.json`). Supports `--model <name>`, `--all`, `--dataset <path>`, `--scene <name>`, `--stage <stage>`, `--dry-run`, `--skip-verify`, and `--skip-gpu`.
- **`verify_env.sh` (Pre-execution Test Suite & Flight Diagnostics)**:
  Performs pre-flight diagnostic validation across GPU compute capabilities, NVIDIA driver health, Conda environment integrity (single or all 11 environments), dataset hierarchy structures (Submerged3D and OSCD dual-scene formats), and essential system binaries. Employs standardized exit codes (`0`: Success, `1`: GPU failure, `2`: Conda failure, `3`: Dataset failure, `4`: System tool missing) and integrates automatically with `run_pipeline.sh`.

For in-depth technical details, configuration parameters, Conda environment recipes, and usage workflows, refer to [Pipeline and Automation Scripts](pipeline_and_scripts.md).

## **[CRITICAL]** Project Context

This is an active academic research repository. AI agents assisting in this project should be prepared to handle both rigorous academic writing tasks (LaTeX formatting, citations) and complex computer vision/graphics programming (typically Python and CUDA for 3DGS) within the codebase.
