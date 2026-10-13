# Model Outputs Evaluation & Presentation Workspace

This workspace is designed for evaluating, organizing, and visualizing the complete portfolio of all **15 model executions** from the QUT Engineering research thesis: **"Investigation of Primitive-Space Scene Change Detection in Underwater 3D Gaussian Splatting Models"**.

> [!IMPORTANT]
> **Git Tracking Exclusion:** All large data files, point clouds (`.ply`), textured meshes (`.obj`), textures, renders, and unzipped output directories (`raw/`, `organized/`) within this workspace are **strictly excluded from the Git repository** in `.gitignore`. Only the Python automation scripts and documentation are tracked.

---

## Workspace Directory Structure

```
Model_Outputs/
├── README.md               # This evaluation guide
├── organize_outputs.py     # Script 1: Reorganizes raw outputs into a clean supervisor hierarchy
├── collect_metrics.py      # Script 2: Aggregates quantitative metrics into LaTeX, Markdown & CSV
├── view_outputs.py         # Script 3: Interactive viewer for 3D Gaussians, SuGaR meshes & OSCD masks
├── raw/                    # [GITIGNORED] Extracted raw archive from HPC (ump_15_outputs.tar.gz)
└── organized/              # [GITIGNORED] Clean, presentation-grade directory for supervisors
    ├── 01_Physics_Based_3DGS/
    │   ├── SeaSplat/       (Kwaj & Tokai: .ply, .obj, results.json)
    │   └── 3D-UIR/         (Kwaj & Tokai: .ply, .obj, results.json)
    ├── 02_Image_Restoration_3DGS/
    │   ├── Gaussian_Splashing/ (Kwaj & Tokai: .ply, .obj, results.json)
    │   └── WaterSplatting/     (Kwaj & Tokai: .ply, .obj, results.json)
    ├── 03_Supplementary_3DGS/
    │   ├── RUSplatting/    (Kwaj & Tokai: .ply, .obj, results.json)
    │   └── UW-GS/          (Kwaj & Tokai: .ply, .obj, results.json)
    ├── 04_Surface_Geometry_Mesh/
    │   └── SuGaR/          (Kwaj & Tokai: coarse & refined .obj meshes)
    ├── 05_Scene_Change_Detection/
    │   └── O-SCD/          (updated_scene.ply, oscd.obj, change_masks/, results.json)
    ├── master_benchmark_table.md   # Markdown summary table
    ├── master_benchmark_table.tex  # Academic LaTeX table for thesis/paper
    ├── master_benchmark_table.csv  # Spreadsheet export
    └── PORTFOLIO_INDEX.md          # Clickable supervisor navigation guide
```

---

## Recommended Ubuntu Desktop Viewing Tools

Before viewing, ensure the following native Linux visualization tools are installed:

```bash
# 1. 3D Textured Surface Mesh Viewer (MeshLab)
sudo apt update && sudo apt install -y meshlab

# 2. Raw Geometry & Point Cloud Inspector (CloudCompare)
# Note: CloudCompare inspects raw (x,y,z) coordinate points and scalar distributions.
# To render the true continuous volumetric Gaussian Splat, use SuperSplat WebGL in your browser.
sudo snap install cloudcompare

# 3. Optional: Blender (Advanced rendering and inspection)
sudo snap install blender --classic

# 4. Optional: Python visualization packages (for built-in Open3D and Matplotlib viewers)
pip install matplotlib open3d
```

---

## Step-by-Step Workflow

### Step 1: Extract Outputs
Once you have downloaded `ump_15_outputs.tar.gz` from the HPC Data Transfer Node (`eresdtn01.qut.edu.au`), extract it into `~/UMP_15_outputs` or `Model_Outputs/raw`:

```bash
# Option A: Extract directly into ~/UMP_15_outputs
mkdir -p ~/UMP_15_outputs
tar -xzvf ~/Downloads/ump_15_outputs.tar.gz -C ~/UMP_15_outputs/

# Option B: Extract inside Model_Outputs/raw
mkdir -p Model_Outputs/raw
tar -xzvf ~/Downloads/ump_15_outputs.tar.gz -C Model_Outputs/raw/
```

---

### Step 2: Reorganize into Supervisor Hierarchy (`organize_outputs.py`)
Run the organizer to automatically find, standardize, and rename the 15 models' outputs:

```bash
# Uses fast symbolic links by default (instantaneous, consumes 0 extra disk space):
python Model_Outputs/organize_outputs.py

# Or if you prefer physical file copies:
python Model_Outputs/organize_outputs.py --mode copy
```

This creates the clean `Model_Outputs/organized/` directory, renaming files with clear, professional labels (e.g., `SeaSplat_Kwaj_point_cloud.ply`, `OSCD_Updated_Point_Cloud.ply`, `OSCD_Textured_Mesh.obj`), and automatically builds `PORTFOLIO_INDEX.md`.

---

### Step 3: Compile Master Benchmark Tables (`collect_metrics.py`)
Extract all PSNR, SSIM, LPIPS, and change detection metrics from all 15 models into publication-ready formats:

```bash
python Model_Outputs/collect_metrics.py
```

This generates:
- **`master_benchmark_table.tex`**: Complete LaTeX table using `booktabs` formatted for your thesis or paper.
- **`master_benchmark_table.md`**: Markdown table viewable directly in GitHub / VS Code.
- **`master_benchmark_table.csv`**: CSV table for LibreOffice Calc or Excel.
- **`master_benchmark_table.json`**: Structured JSON data.

---

### Step 4: Interactively View Splats, Meshes & Change Maps (`view_outputs.py`)

Launch the interactive viewer:
```bash
python Model_Outputs/view_outputs.py
```

You can select any model by number from the terminal menu:
- **3D Gaussian Splats (`.ply`):** Choose **[1]** to launch [SuperSplat](https://playcanvas.com/supersplat/editor) in your browser for photorealistic volumetric 3DGS rendering at 60 FPS, or **[2]** for raw coordinate inspection in CloudCompare.
- **3D Change Heatmap Splats (`.ply`):** Press **[H]** or select O-SCD -> **[h]** to view the scene where changed objects glow in bright 3D thermal flame red/yellow in SuperSplat!
- **Reconstructed Video Heat Maps (`.mp4`):** Press **[V]** or select O-SCD -> **[v]** to play the full-resolution camera sweep video with glowing thermal change overlays and 3-panel side-by-side comparison.
- **Textured Meshes (`.obj`):** Launches MeshLab or Blender.
- **OSCD Change Maps (2D):** Type `[M]` to launch an interactive Matplotlib gallery displaying the rendered 2D change masks.
- **Master Benchmark Table:** Type `[T]` to print the formatted comparative metrics in your terminal.

---

### Step 5: Synthesize 3D & Video Change Heatmaps (`generate_change_heatmaps.py`)

If you want to recompute or regenerate the 3D and video heatmaps:
```bash
python Model_Outputs/generate_change_heatmaps.py
```
This automatically produces:
1. `O-SCD_3D_Change_Heatmap_Hybrid.ply` (Photorealistic room context with glowing thermal flame red on changed objects).
2. `O-SCD_3D_Change_Heatmap_Turbo.ply` (Full 3D scientific false-color thermal spectrum).
3. `oscd_change_heatmap_overlay.mp4` (Full 1080p camera sweep video with thermal change overlays and glowing contours).
4. `oscd_change_comparison_3panel.mp4` (Synchronized 3-panel comparison video: [Inspection RGB] | [Thermal Heatmap Overlay] | [Binary Mask]).
5. `oscd_change_keyframe_strip.png` (High-resolution multi-view comparison figure ready for your thesis/paper).

