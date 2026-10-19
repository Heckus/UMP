# Panning & Orbiting 3DGS / SuGaR GIF Naming Instructions

Save your panning/orbiting screen-recorded GIFs inside [`2A/gifs/`](file:///home/hecke/0Github/UMP/2A/gifs).  
The interactive slide deck ([`2A/ENN595_2A_Presentation_Slides.html`](file:///home/hecke/0Github/UMP/2A/ENN595_2A_Presentation_Slides.html)) is pre-wired with **automatic hot-swap detection** and **interactive model switcher tabs**:
- As soon as you place any file from the table below into `2A/gifs/`, the slide deck automatically detects it and replaces the static/composite fallback with your live orbiting GIF.
- If a file has not been recorded yet, the slide seamlessly displays the pre-generated fallback GIF/render with zero broken image icons.

---

## 1. Exact Target Filenames & Source `.ply` / `.obj` Paths

### A. Priority 1 — Essential Orbiting GIFs (High Impact for 8-Minute Talk)
If you only want to record the **6 most impactful orbiting GIFs**, record these first:

| Target GIF Filename in `2A/gifs/` | Slide # | Source Artifact in `Model_Outputs/organized/` | Recommended Viewer & Camera Motion |
| :--- | :---: | :--- | :--- |
| **`orbit_3d_uir_kwaj.gif`** | Slide 11 | `01_Physics_Based_3DGS/3D-UIR/Kwaj/3D-UIR_Kwaj_point_cloud.ply` | **SuperSplat WebGL:** Slow 360° or 90° arc orbit around Kwajalein superstructure & handrails (`SSIM 0.8739`). |
| **`orbit_seasplat_kwaj.gif`** | Slide 5 & 11 | `01_Physics_Based_3DGS/SeaSplat/Kwaj/SeaSplat_Kwaj_point_cloud.ply` | **SuperSplat WebGL:** Smooth pan across hull showing restored benthic colour & removed green-blue backscatter. |
| **`orbit_3d_uir_tokai.gif`** | Slide 11 & 12 | `01_Physics_Based_3DGS/3D-UIR/Tokai/3D-UIR_Tokai_point_cloud.ply` | **SuperSplat WebGL:** Orbit over the deep turbid Tokai Maru deck (`SSIM 0.7085`). |
| **`orbit_sugar_mesh_kwaj.gif`** | Slide 6 & 12 | `04_Surface_Geometry_Mesh/SuGaR/Kwaj/SuGaR_Kwaj_refined_mesh.obj` | **Blender / MeshLab:** Orbit showing solid 1.0M-face watertight Poisson surface + wireframe toggle (85–92% floaters pruned). |
| **`orbit_oscd_heatmap_all_changes.gif`** | Slide 7 & 13 | `05_Scene_Change_Detection/O-SCD/Custom_OSCD_Dataset/O-SCD_3D_Change_Heatmap_Turbo_All_Changes.ply` | **SuperSplat WebGL:** Elevated 35° orbit around the table highlighting moved objects + the **volumetric thermal ghost of the removed red soda can**. |
| **`orbit_oscd_updated_scene.gif`** | Slide 13 | `05_Scene_Change_Detection/O-SCD/Custom_OSCD_Dataset/O-SCD_Custom_OSCD_Dataset_point_cloud.ply` | **SuperSplat WebGL:** Same 35° orbit showing the clean post-change $T_1$ 3DGS reconstruction (`PSNR 27.08 dB`). |

---

### B. Priority 2 — Optional Additional Model Tabs (Interactive Switcher on Slides 11, 12, 13)
The interactive switcher tabs on Slides 11, 12, and 13 also automatically load any of the following files if present in `2A/gifs/`:

| Target GIF Filename in `2A/gifs/` | Slide # | Source Artifact in `Model_Outputs/organized/` | Description |
| :--- | :---: | :--- | :--- |
| **`orbit_watersplatting_kwaj.gif`** | Slide 11 (Tab) | `02_Image_Restoration_3DGS/WaterSplatting/Kwaj/WaterSplatting_Kwaj_point_cloud.ply` | Fastest training model (`38m`, best perceptual `LPIPS 0.1714`). |
| **`orbit_gaussiansplashing_kwaj.gif`** | Slide 11 (Tab) | `02_Image_Restoration_3DGS/Gaussian_Splashing/Kwaj/Gaussian_Splashing_Kwaj_point_cloud.ply` | Highest raw PSNR (`27.93 dB`) volumetric medium rendering. |
| **`orbit_rusplatting_kwaj.gif`** | Slide 11 (Tab) | `03_Supplementary_3DGS/RUSplatting/Kwaj/RUSplatting_Kwaj_point_cloud.ply` | Inverted-depth + RIFE sparse-view reconstruction (`PSNR 26.56 dB`). |
| **`orbit_uw_gs_kwaj.gif`** | Slide 11 (Tab) | `03_Supplementary_3DGS/UW-GS/Kwaj/UW-GS_Kwaj_point_cloud.ply` | Distractor-filtered background medium model (`PSNR 24.64 dB`). |
| **`orbit_seasplat_tokai.gif`** | Slide 12 (Tab) | `01_Physics_Based_3DGS/SeaSplat/Tokai/SeaSplat_Tokai_point_cloud.ply` | Deep blue attenuation recovery on Tokai Maru. |
| **`orbit_sugar_mesh_tokai.gif`** | Slide 12 (Tab) | `04_Surface_Geometry_Mesh/SuGaR/Tokai/SuGaR_Tokai_refined_mesh.obj` | Watertight Poisson mesh on Tokai Maru (`1.0M` faces). |
| **`orbit_oscd_heatmap_turbo.gif`** | Slide 13 (Tab) | `05_Scene_Change_Detection/O-SCD/Custom_OSCD_Dataset/O-SCD_3D_Change_Heatmap_Turbo.ply` | 3D Turbo thermal change heatmap ($T_1$ moved/added objects). |
| **`orbit_oscd_sugar_mesh.gif`** | Slide 13 (Tab) | `05_Scene_Change_Detection/O-SCD/Custom_OSCD_Dataset/O-SCD_Custom_OSCD_Dataset_refined_mesh.obj` | Textured SuGaR mesh (`oscd.obj`) of the updated scene. |

---

## 2. Quick Workflow: Launching the Viewer & Converting `.mp4`/`.mkv` Recordings to `.gif`

1. **Launch Interactive Viewer:**
   ```bash
   python3 Model_Outputs/view_outputs.py
   ```
   Or drag-and-drop any `.ply` directly into [SuperSplat WebGL (`https://playcanvas.com/supersplat/editor`)](https://playcanvas.com/supersplat/editor) and `.obj` into Blender or [3DViewer.net (`https://3dviewer.net/`)](https://3dviewer.net/).

2. **Convert Any Screen Recording (`.mp4` / `.mkv` / `.webm`) to a Crisp 16:9 Presentation `.gif`:**
   ```bash
   ffmpeg -y -i raw_recording.mp4 \
     -vf "fps=15,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
     2A/gifs/orbit_3d_uir_kwaj.gif
   ```
