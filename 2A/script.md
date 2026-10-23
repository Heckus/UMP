# ENN595-1 Project Summary Oral Presentation: Master Script
**Project Title:** Investigation of Primitive-Space Scene Change Detection in Underwater 3D Gaussian Splatting Models  
**Presenter:** Joshua Hecke (n11585382)  
**School / Faculty:** School of Electrical Engineering & Robotics | QUT Centre for Robotics  
**Supervisor:** Prof. Niko Sünderhauf (Principal Supervisor, QUT Centre for Robotics)  
**Public Code Repository:** [https://github.com/Heckus/UMP](https://github.com/Heckus/UMP)  
**Strict Presentation Time Limit:** **8 Minutes Maximum** (Script timed to **7m 45s** with a 15-second safety buffer) + **2 Minutes Q&A**  
**Total Target Spoken Words:** **~1,030 words** (Delivered at a calm, authoritative **130–135 words per minute**)

<style>
@media print {
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; font-size: 11pt; color: #111; line-height: 1.45; }
  h1 { font-size: 18pt; margin-bottom: 4pt; }
  h2 { font-size: 14pt; border-bottom: 2px solid #0284c7; padding-bottom: 2pt; margin-top: 10pt; }
  h3 { font-size: 12pt; margin-top: 8pt; margin-bottom: 2pt; color: #0369a1; }
  .page-break { page-break-after: always; break-after: page; }
  .no-break { page-break-inside: avoid; break-inside: avoid; }
  .dashboard-table { font-size: 8.5pt; width: 100%; border-collapse: collapse; }
  .dashboard-table th, .dashboard-table td { border: 1px solid #cbd5e1; padding: 4pt 6pt; }
  .card { border: 1px solid #94a3b8; border-radius: 6pt; padding: 8pt 10pt; margin-bottom: 10pt; background: #fff; }
  .badge { font-weight: bold; padding: 1pt 4pt; border-radius: 3pt; font-size: 8.5pt; }
  .script-box { background: #f8fafc; border-left: 4px solid #0284c7; padding: 6pt 10pt; font-size: 10.5pt; font-style: normal; margin-top: 4pt; }
  .cue { color: #b45309; font-weight: bold; font-size: 9pt; }
  .action { color: #047857; font-weight: bold; font-size: 9pt; }
  .pronounce { color: #64748b; font-size: 8.5pt; font-style: italic; }
}
@media screen {
  body { max-width: 900px; margin: 0 auto; padding: 20px; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #1e293b; line-height: 1.5; }
  .page-break { border-bottom: 3px dashed #cbd5e1; margin: 30px 0; padding-bottom: 10px; }
  .card { border: 1px solid #cbd5e1; border-radius: 8px; padding: 14px 18px; margin-bottom: 16px; background: #ffffff; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
  .script-box { background: #f0f9ff; border-left: 4px solid #0284c7; padding: 12px 16px; border-radius: 0 6px 6px 0; font-size: 1.05rem; margin-top: 8px; }
  .cue { color: #b45309; font-weight: 700; font-size: 0.88rem; }
  .action { color: #047857; font-weight: 700; font-size: 0.88rem; }
  .pronounce { color: #64748b; font-size: 0.85rem; font-style: italic; }
}
</style>

---

## Quick Reference: Presenter's 8-Minute Pacing Dashboard

*Keep this summary table visible on your podium or folder for instant time checks during the talk.*

| Slide # | Slide Title | Visual Asset / Screen Action | Clock Time | Duration | Words | Pace Check |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: |
| **1** | Title & Core Research Question | Hexagon title frame & public repo badge | `0:00 – 0:30` | `30s` | `68` | Authoritative |
| **2** | Ecological Context & 2D Bottleneck | 3-column reef problem & 45% rugosity card | `0:30 – 1:05` | `35s` | `78` | Urgent / Clear |
| **3** | Concept: 3D Gaussian Splatting (2023) | Kerbl et al. paper & bicycle 3DGS loop | `1:05 – 1:35` | `30s` | `67` | Explanatory |
| **4** | Concept: Primitive-Space SCD (2026) | GS-Diff paper & Decoupled Kernels | `1:35 – 2:10` | `35s` | `78` | Methodical |
| **5** | Concept: Underwater Optical 3DGS (2025) | Jaffe-McGlamery equation & 6 models | `2:10 – 2:45` | `35s` | `78` | Technical |
| **6** | Concept: SuGaR Surface Regularization | Guédon paper & garden mesh GIF | `2:45 – 3:20` | `35s` | `79` | Problem-Solving |
| **7** | Proposed 6-Stage CONOPS Architecture | High-res CONOPS map + HPC stages | `3:20 – 4:00` | `40s` | `89` | **Midpoint (4:00)** |
| **8** | Strategy: Why Submerged3D (20 Img × 4 Sites) | 4-site grid GIF + Engineering buffer | `4:00 – 4:40` | `40s` | `88` | Justifying |
| **9** | Production Target: AIMS EcoRRAP (1.35 TB) | EcoRRAP coral transect matrix | `4:40 – 5:10` | `30s` | `68` | Visionary |
| **10** | Progress: Aqua HPC & 15/15 Milestone | 11 Conda envs & 15/15 success table | `5:10 – 5:45` | `35s` | `78` | Rigorous |
| **11** | Progress: Quantitative Benchmark Results | Kwaj & Tokai metrics table + Orbit GIFs | `5:45 – 6:30` | `45s` | `99` | Analytical |
| **12** | Progress: Per-Model SuGaR 3D Meshes | Static bright mesh renders (Kwaj & Tokai) | `6:30 – 7:00` | `30s` | `68` | Decisive |
| **13** | Progress: Primitive-Space O-SCD Results | 4-panel change mask + Orbiting ghost can | `7:00 – 7:35` | `35s` | `78` | Climax / Proof |
| **14** | Priorities for Next Steps & Roadmap | Phase 2–4 Gantt roadmap + Thank you | `7:35 – 8:00` | `25s` | `56` | Forward-Looking |
| **Q&A** | **Examiner Defense Session** | **Switch to slide 11, 10, or 13 as needed** | **8:00 – 10:00** | **2m 00s** | — | Calm & Precise |

<div class="page-break"></div>

---

# Printable Slide-by-Slide Script Cards

---

### Slide 1: Title Slide & Core Research Question
<div class="card no-break">

**Timing:** `0:00 – 0:30` (`30s`) | **Word Count:** 68 words | **Pacing:** Calm, confident, formal  
**Rubric Focus:** *Criterion 1 (Context & Well-Formulated Research Question)*  
**Visual On Screen:** Title slide with dark-navy theme, supervisor name, and public repository callout (`github.com/Heckus/UMP`).

**Stage Directions & Delivery:**
- <span class="action">[STAND TALL, EYE CONTACT ACROSS PANEL]</span>
- <span class="pronounce">[Pronounce: Hecke = HECK-ee | Sünderhauf = SOON-der-howf]</span>

<div class="script-box">

"Good morning everyone. My name is **Joshua Hecke**, and under the supervision of Professor Niko Sünderhauf at the QUT Centre for Robotics, my research investigates **Primitive-Space Scene Change Detection in Underwater 3D Gaussian Splatting Models**.

Our core research question asks: **How can we detect fine-scale structural growth, breakage, and bleaching directly inside 3D Gaussian primitive space, without being deceived by fluctuating underwater turbidity and backscatter?**"

</div>

**Transition to Slide 2:** <span class="cue">[ADVANCE SLIDE]</span> "To understand why this is such an urgent challenge, let us look at how coral reefs are monitored today."

</div>

---

### Slide 2: Project Context: Why 3D Underwater Change Detection?
<div class="card no-break">

**Timing:** `0:30 – 1:05` (`35s`) | **Word Count:** 78 words | **Pacing:** Engaging, problem-focused  
**Rubric Focus:** *Criterion 1 (Clear, Critical Analysis of Ecological Context & Limitations)*  
**Visual On Screen:** 3-column analysis: (1) Ecological Crisis, (2) 2D Diver Survey Limits, (3) Marine Photogrammetry Challenge.

**Stage Directions & Delivery:**
- <span class="action">[POINT TO: 45% Rugosity Stat in Column 2]</span>
- <span class="pronounce">[Pronounce: rugosity = roo-GOSS-ih-tee | photogrammetry = foe-toe-GRAM-eh-tree]</span>

<div class="script-box">

"Coral ecosystems like the Great Barrier Reef face unprecedented thermal bleaching and storm destruction. Ecological programs like AIMS EcoRRAP need to monitor **millimetre-to-centimetre changes** over time.

However, standard monitoring still relies on two-dimensional planar photo-transects. Recent studies show 2D surveys underestimate structural reef rugosity by **up to 45%**, completely missing complex vertical branching and under-canopy health.

Yet moving to 3D underwater vision is notoriously difficult: between survey passes, changing light, water haze, and floating particles corrupt standard image comparison."

</div>

**Transition to Slide 3:** <span class="cue">[ADVANCE SLIDE]</span> "To overcome this, our foundation builds upon 3D Gaussian Splatting."

</div>

<div class="page-break"></div>

---

### Slide 3: Understanding the Concept (2023): 3D Gaussian Splatting
<div class="card no-break">

**Timing:** `1:05 – 1:35` (`30s`) | **Word Count:** 67 words | **Pacing:** Clear, instructional, explanatory  
**Rubric Focus:** *Criterion 1 (Mastery of Foundational Technologies & Formulations)*  
**Visual On Screen:** Kerbl et al. (SIGGRAPH 2023) paper highlight and real-time bicycle scene rendering loop.

**Stage Directions & Delivery:**
- <span class="action">[GESTURE TO THE EXPLICIT PRIMITIVES CALLOUT]</span>
- <span class="pronounce">[Pronounce: anisotropic = an-eye-so-TROP-ik | covariance = co-VAIR-ee-ance]</span>

<div class="script-box">

"Introduced by Kerbl et al. in 2023, 3D Gaussian Splatting revolutionised computer vision.

Unlike Neural Radiance Fields—which bury scene geometry inside slow, black-box neural networks—3DGS represents the world **explicitly** as millions of 3D Gaussian ellipsoids. Each primitive carries an exact 3D position, anisotropic covariance shape, opacity, and spherical harmonic colour.

This delivers real-time rendering at over thirty frames per second, while giving us direct mathematical access to the physical primitives themselves."

</div>

**Transition to Slide 4:** <span class="cue">[ADVANCE SLIDE]</span> "In 2026, QUT researchers leveraged these explicit primitives to reinvent change detection."

</div>

---

### Slide 4: Understanding the Concept (2026): Primitive-Space Change Detection
<div class="card no-break">

**Timing:** `1:35 – 2:10` (`35s`) | **Word Count:** 78 words | **Pacing:** Technical, authoritative  
**Rubric Focus:** *Criterion 1 & 2 (Cutting-Edge Concept & Decoupled Change Formulations)*  
**Visual On Screen:** Galappaththige et al. (QUT 2026) paper banner, Decoupled Kernel cards, and `concept_oscd_paper.gif`.

**Stage Directions & Delivery:**
- <span class="action">[POINT TO: Green Geometric Kernel, then Orange Appearance Kernel]</span>
- <span class="pronounce">[Pronounce: Galappaththige = gah-lahp-PAHTH-tih-gay | SuGaR = SHOO-gahr]</span>

<div class="script-box">

"Galappaththige et al. introduced **GS-Diff** and **O-SCD**, operating directly on 3D primitives rather than comparing rendered 2D images.

Crucially, this architecture decouples change into two independent mathematical kernels:
- A **Geometric Kernel**, which detects true physical additions or structural breakage;
- And an **Appearance Kernel**, which isolates surface colour shifts like thermal coral bleaching.

Importantly, the authors concluded that unconstrained Gaussians can drift over time, explicitly recommending surface regularization like SuGaR to anchor geometry."

</div>

**Transition to Slide 5:** <span class="cue">[ADVANCE SLIDE]</span> "However, neither 3DGS nor O-SCD were designed to function through water."

</div>

<div class="page-break"></div>

---

### Slide 5: Extending the Concept (2025): Optical Water Restoration
<div class="card no-break">

**Timing:** `2:10 – 2:45` (`35s`) | **Word Count:** 78 words | **Pacing:** Confident, scientific  
**Rubric Focus:** *Criterion 1 & 2 (Physics-Grounded Marine Domain Adaptation)*  
**Visual On Screen:** Jaffe-McGlamery optical formation equation and animated comparisons (`orbit_3d_uir_kwaj.gif`, `orbit_seasplat_kwaj.gif`).

**Stage Directions & Delivery:**
- <span class="action">[POINT TO: Equation Box — Backscatter vs. Direct Transmission]</span>
- <span class="pronounce">[Pronounce: Jaffe-McGlamery = JAFF-ee mc-GLAM-er-ee | albedo = al-BEE-doh]</span>

<div class="script-box">

"Standard 3DGS treats water haze as physical geometry, creating dense swarms of floating ghost splats.

Recent underwater architectures embed the **Jaffe-McGlamery optical formation model** directly into the differentiable rasterizer. This explicitly decouples the medium's wavelength-dependent attenuation and backscatter from true benthic scene radiance.

Across our benchmark, we evaluated six distinct architectures across physics-based methods like **SeaSplat** and **3D-UIR**, alongside restoration models like **Gaussian Splashing** and **WaterSplatting**, isolating true underwater colour and crisp geometry."

</div>

**Transition to Slide 6:** <span class="cue">[ADVANCE SLIDE]</span> "To clean up the remaining water-column noise, we introduce surface regularization."

</div>

---

### Slide 6: Extending the Concept (2024): SuGaR Surface Regularization
<div class="card no-break">

**Timing:** `2:45 – 3:20` (`35s`) | **Word Count:** 79 words | **Pacing:** Problem-solving, precise  
**Rubric Focus:** *Criterion 2 (Creative Solution to Water Floaters & Surface Alignment)*  
**Visual On Screen:** Guédon & Lepetit (CVPR 2024) paper, SDF density formula, and garden mesh GIF.

**Stage Directions & Delivery:**
- <span class="action">[EMPHASIZE: 85–92% Floater Removal]</span>
- <span class="pronounce">[Pronounce: Guédon = geh-DOHN | Poisson = PWAH-sohn]</span>

<div class="script-box">

"Following the recommendation from the O-SCD authors, our pipeline integrates **SuGaR** by Guédon and Lepetit into Stage 5 for two vital reasons.

First, its Signed Distance Field normal-consistency prior forces ellipsoids flat against actual surfaces, **pruning 85 to 92 percent of floating water-column artifacts**.

Second, it reconstructs a watertight, UV-textured Poisson surface mesh for every model. This gives marine scientists millimeter-level surface geometry and physical area measurements, preventing unconstrained Gaussian drift between surveys."

</div>

**Transition to Slide 7:** <span class="cue">[ADVANCE SLIDE]</span> "Here is how all these components unify into our operational architecture."

</div>

<div class="page-break"></div>

---

### Slide 7: Proposed Solution: End-to-End 6-Stage CONOPS
<div class="card no-break">

**Timing:** `3:20 – 4:00` (`40s`) | **Word Count:** 89 words | **Pacing:** Structured, authoritative  
**Rubric Focus:** *Criterion 2 (Clear Methodology, Engineering Rigour, Public Reproducibility)*  
**Visual On Screen:** Full CONOPS pipeline map (`conops.jpg`), 6-stage HPC workflow badges, and public repository reference box.

**Stage Directions & Delivery:**
- <span class="action">[POINT TO: Public GitHub Callout at top: `github.com/Heckus/UMP`]</span>
- <span class="action">[SWEEP HAND: Left to Right across Stages 1 through 6]</span>

<div class="script-box">

"This CONOPS illustrates our complete temporal change detection pipeline.

Multi-temporal reef passes stream through:
1. Automated data validation;
2. Structure-from-Motion in COLMAP;
3. Monocular depth inversion via Depth-Anything-V2;
4. Underwater optical 3DGS training;
5. SuGaR surface regularization and mesh extraction; and
6. Held-out quantitative evaluation.

All custom PBS batch scripts, CUDA rasterizer patches, and automation code referenced throughout this presentation are published on GitHub at **github.com/Heckus/UMP**.

I engineered this into a turnkey six-stage automated pipeline operating on the **QUT Aqua supercomputer**."

</div>

**Transition to Slide 8:** <span class="cue">[ADVANCE SLIDE]</span> "Before scaling to terabytes of coral, we needed a rigorous engineering test suite."

</div>

---

### Slide 8: Experimental Strategy: Why the Submerged3D Test Dataset?
<div class="card no-break">

**Timing:** `4:00 – 4:40` (`40s`) | **Word Count:** 88 words | **Pacing:** Strategic, justified, self-aware  
**Rubric Focus:** *Criterion 2 (Experimental Strategy, Engineering Buffer, Transparent Limitations)*  
**Visual On Screen:** 20-image × 4-location animated grid (`submerged3d_4locations_20images.gif`) and 3-column justification.

**Stage Directions & Delivery:**
- <span class="action">[EMPHASIZE: Proactive engineering buffer while DTA is processed]</span>
- <span class="action">[POINT TO: 20-image grid cycling through the 4 shipwreck sites]</span>

<div class="script-box">

"Why begin with the Submerged3D dataset—specifically twenty images across four shipwreck sites?

First, it acted as a **proactive engineering buffer**. While our primary 1.35-terabyte coral dataset undergoes AIMS legal Data Transfer Agreement review, this compact benchmark allowed rapid development. Twenty images kept full six-stage training to under seventy minutes per run, allowing ten complete debugging cycles across eleven Conda environments.

Second, sparse views stress-tested our pipeline: low-contrast imagery on Cormoran and Isro exposed feature-matching limits early, proving our pre-flight data guards work."

</div>

**Transition to Slide 9:** <span class="cue">[ADVANCE SLIDE]</span> "This brings us to our primary ecological target."

</div>

<div class="page-break"></div>

---

### Slide 9: Production Target: Why the AIMS EcoRRAP Dataset (1.35 TB)?
<div class="card no-break">

**Timing:** `4:40 – 5:10` (`30s`) | **Word Count:** 68 words | **Pacing:** Visionary, impactful  
**Rubric Focus:** *Criterion 1 & 2 (Ecological Significance & Phase 2 Staging)*  
**Visual On Screen:** EcoRRAP 3-column card analysis and Phase 1 vs. Phase 2–4 comparison matrix.

**Stage Directions & Delivery:**
- <span class="action">[POINT TO: High-Density 70% Overlap Metric]</span>
- <span class="action">[CONFIDENT TONE: Pipeline is ready and waiting for data]</span>

<div class="script-box">

"Our production target is the **1.35-terabyte AIMS EcoRRAP repository**.

Unlike sparse test sets, EcoRRAP features dense, seventy-percent-overlap stereoscopic photogrammetry capturing permanent Great Barrier Reef quadrats across seasonal bleaching and cyclone events.

Our pipeline will allow marine ecologists to walk through interactive 3D digital twins, automatically isolating bleaching colour shifts from physical colony growth or breakage. Our turnkey HPC scripts are fully staged for immediate ingestion upon legal clearance."

</div>

**Transition to Slide 10:** <span class="cue">[ADVANCE SLIDE]</span> "Now let us examine the concrete engineering milestones achieved this semester."

</div>

---

### Slide 10: Progress: QUT Aqua HPC & The 15 / 15 Benchmark Milestone
<div class="card no-break">

**Timing:** `5:10 – 5:45` (`35s`) | **Word Count:** 78 words | **Pacing:** Energetic, rigorous, triumphant  
**Rubric Focus:** *Criterion 2 (Outstanding Engineering Progress & Forensic Technical Solutions)*  
**Visual On Screen:** KPI metric row (15/15 Pass, 11 Conda Envs, A100/H100 GPUs), Technical Fixes list, and clean green 15/15 Execution Table.

**Stage Directions & Delivery:**
- <span class="action">[GESTURE PROUDLY TO: Green "PASS (2/2)" Column in Table]</span>
- <span class="pronounce">[Pronounce: CUDA = KOO-duh | ABI = A-B-I | RANSAC = RAN-sak]</span>

<div class="script-box">

"Open-source underwater 3DGS codebases are notorious for conflicting dependencies, spanning Python 3.7 to 3.12 and incompatible CUDA rasterizers.

I engineered an automated provisioning suite on QUT Aqua, isolating **eleven Conda environments** across NVIDIA A100 and H100 nodes. Across ten intensive audit cycles, we diagnosed and resolved critical bugs—including COLMAP library linking, custom CUDA rasterizer gradient shapes, and SuGaR numerical NaN collapses.

This delivered our primary milestone: **15 out of 15 full-lifecycle benchmark runs succeeded with Exit Code 0**."

</div>

**Transition to Slide 11:** <span class="cue">[ADVANCE SLIDE]</span> "Let us inspect the quantitative performance of these models."

</div>

<div class="page-break"></div>

---

### Slide 11: Progress: Quantitative & Visual Underwater 3DGS Benchmark
<div class="card no-break">

**Timing:** `5:45 – 6:30` (`45s`) | **Word Count:** 99 words | **Pacing:** Analytical, deliberate, metric-focused  
**Rubric Focus:** *Criterion 2 & 3 (Technically Sound Evaluation, Media Polish, Rigorous Trade-off Analysis)*  
**Visual On Screen:** Master Quantitative Table (`Kwajalein` & `Tokai Maru`), and 4 orbiting model GIFs (`3D-UIR`, `SeaSplat`, `Gaussian Splashing`, `WaterSplatting`).

**Stage Directions & Delivery:**
- <span class="action">[POINT TO: 3D-UIR SSIM in Table: 0.8739 and 0.7085]</span>
- <span class="action">[POINT TO: SeaSplat Albedo Recovery in Tokai Orbit GIF]</span>

<div class="script-box">

"Here are our quantitative and visual results across Kwajalein and Tokai Maru.

While Gaussian Splashing achieved the highest raw PSNR at 27.93 dB on Kwajalein, its structural similarity collapsed under the heavy blue turbidity of Tokai Maru to 0.6142 due to severe over-smoothing. WaterSplatting was our fastest architecture at 43 minutes with the lowest perceptual error.

However, for change detection, structural integrity is paramount: **3D-UIR achieved the highest structural similarity on both scenes**—0.8739 and 0.7085—preserving fine metallic railings and biological textures. Combined with SeaSplat's superior physical backscatter removal, these two models form our winning backbones."

</div>

**Transition to Slide 12:** <span class="cue">[ADVANCE SLIDE]</span> "Next, we examine the extracted 3D surface meshes from Stage 5."

</div>

---

### Slide 12: Progress: Per-Model SuGaR 3D Surface Meshes
<div class="card no-break">

**Timing:** `6:30 – 7:00` (`30s`) | **Word Count:** 68 words | **Pacing:** Decisive, impactful  
**Rubric Focus:** *Criterion 2 (Creative Engineering Discovery & Mesh Metrology Proof)*  
**Visual On Screen:** Static bright renders of Kwajalein and Tokai Maru meshes (`sugar_kwaj_mesh_bright.png`, `sugar_tokai_mesh_bright.png`) and `--output_dir_tag` isolation badge.

**Stage Directions & Delivery:**
- <span class="action">[POINT TO: High-resolution mesh renders showing crisp hull surfaces without floaters]</span>
- <span class="action">[MENTION: Public code fix on GitHub]</span>

<div class="script-box">

"In Stage 5, every model generates a one-million-face watertight mesh.

During inspection, we uncovered a critical flaw in vanilla SuGaR: it cached meshes by scene name alone, causing all models to overwrite the first model's geometry. We engineered per-model namespace isolation via `--output_dir_tag`, published in our repository.

As seen in these static renders of Kwajalein and Tokai Maru, SuGaR successfully eliminated water floaters and recovered clean, measurable 3D hulls."

</div>

**Transition to Slide 13:** <span class="cue">[ADVANCE SLIDE]</span> "Finally, we validated our primary objective: Primitive-Space Change Detection."

</div>

<div class="page-break"></div>

---

### Slide 13: Progress: Primitive-Space Scene Change Detection (O-SCD)
<div class="card no-break">

**Timing:** `7:00 – 7:35` (`35s`) | **Word Count:** 78 words | **Pacing:** Climax, authoritative, highly engaged  
**Rubric Focus:** *Criterion 2 & 3 (Demonstration of Primary Thesis Goal & Sophisticated Visual Proof)*  
**Visual On Screen:** 4-panel multi-view change mask animation + 3D Orbiting Turbo Change Heatmap showing the thermal ghost of the removed red can.

**Stage Directions & Delivery:**
- <span class="action">[POINT TO: Volumetric thermal "ghost" in the orbiting 3D heatmap]</span>
- <span class="action">[EMPHASIZE: Zero false positives from camera angle changes]</span>

<div class="script-box">

"Here is our primary change detection engine—O-SCD—operating end-to-end on our dual-state benchmark.

On the left, across 122 viewpoints, the network accurately segments added, moved, and removed objects without false positives caused by camera movement.

On the right, we synthesized direct **3D primitive-space thermal heatmaps**. Notice how the 3D splat captures the volumetric thermal 'ghost' of the removed red soda can, while the updated scene achieves over 27 dB PSNR and 0.83 SSIM."

</div>

**Transition to Slide 14:** <span class="cue">[ADVANCE SLIDE]</span> "This brings us to our immediate research priorities and roadmap."

</div>

---

### Slide 14: Priorities for Next Steps: Phase 2–4 EcoRRAP Roadmap
<div class="card no-break">

**Timing:** `7:35 – 8:00` (`25s`) | **Word Count:** 56 words | **Pacing:** Crisp, forward-looking, definitive finish  
**Rubric Focus:** *Criterion 2 (Clear, Actionable Future Plan & Confident Conclusion)*  
**Visual On Screen:** Unified Phase 3 Architecture diagram, Phase 2–4 roadmap milestones, and professional acknowledgment.

**Stage Directions & Delivery:**
- <span class="action">[STEP FORWARD, CONFIDENT POSTURE]</span>
- <span class="action">[SMILE, OPEN HANDS TOWARD THE PANEL]</span>
- <span class="action">[FINISH PROMPTLY AT ~7m 50s — EXACTLY ON TIME!]</span>

<div class="script-box">

"Looking ahead: In Phase 2, as the AIMS agreement clears, our pipeline will ingest the 1.35-terabyte EcoRRAP dataset.

In Phase 3, we will graft our winning 3D-UIR and SeaSplat optical backbones directly into the O-SCD change engine.

This will deliver an automated, turbidity-invariant 3D monitoring tool for coral reef conservation.

Thank you, and I look forward to your questions."

</div>

</div>

<div class="page-break"></div>

---

# 2-Minute Q&A Defense Battle Card (Criterion 3: 8 pts)

*Deliver crisp, authoritative answers using the **PREP** method: **P**oint (5s) $\rightarrow$ **R**eason (10s) $\rightarrow$ **E**vidence (10s) $\rightarrow$ **P**oint (5s). Keep each answer strictly between 25 and 35 seconds.*

---

### Question 1: "Why only evaluate Kwajalein and Tokai Maru in the full benchmark table if Submerged3D contains 4 shipwreck locations?"
- **Target Response Time:** 30 seconds
- **Key Evidence:** COLMAP convergence on 20 sparse views; diverse optical regimes.
> **Response:**  
> "All four locations were tested in Stage 2 Structure-from-Motion. Because Submerged3D provides only twenty sparse frames per site, the extreme low-contrast green haze on *Cormoran* and *Isle Royale* prevented COLMAP SIFT features from converging into a single dense model across that few views.  
> That was an essential experimental finding—it validated our automated pre-flight checks and proved dense coverage is essential. *Kwajalein* and *Tokai Maru* converged completely, giving us two ideal, contrasting optical regimes: medium backscatter with biofouling versus extreme deep-blue wavelength attenuation, perfectly testing all seven 3DGS models."

---

### Question 2: "How do you prevent water turbidity differences between Time 0 and Time 1 from causing false positives in primitive-space change detection?"
- **Target Response Time:** 30 seconds
- **Key Evidence:** Three-tier defense: Jaffe-McGlamery optical model + SuGaR SDF pruning + Dual-kernel differencing.
> **Response:**  
> "We solve this through a three-stage architectural defense:  
> First, our optical backbones—3D-UIR and SeaSplat—embed the Jaffe-McGlamery equation to explicitly decouple water attenuation and backscatter during training, recovering true benthic albedo.  
> Second, SuGaR applies a Signed Distance Field normal prior that prunes over 85% of floating water-column Gaussians before differencing begins.  
> Finally, O-SCD compares primitives in 3D rather than 2D pixels, using independent geometric and appearance kernels so residual turbidity shifts cannot mimic physical structural displacement."

---

### Question 3: "Why extract SuGaR 3D surface meshes if your primary goal is detecting change directly on Gaussian primitives?"
- **Target Response Time:** 28 seconds
- **Key Evidence:** Literature recommendation (Galappaththige et al., 2026); metric surface evaluation; floater pruning.
> **Response:**  
> "There are two major reasons:  
> First, the authors of the 2026 O-SCD paper explicitly identified that unconstrained Gaussians drift across surfaces between independent runs, recommending SuGaR surface regularization to bind Gaussians to physical reality.  
> Second, extracting watertight UV-textured meshes provides an invaluable supporting output for marine scientists, allowing metric millimeter-scale area and volume calculations in tools like MeshLab while confirming which optical model yields the most accurate physical geometry."

---

### Question 4: "Why did 3D-UIR and SeaSplat outperform Gaussian Splashing on structural similarity despite Gaussian Splashing having higher PSNR?"
- **Target Response Time:** 28 seconds
- **Key Evidence:** PSNR pixel bias vs. SSIM edge preservation; volumetric over-smoothing.
> **Response:**  
> "PSNR is a pixel-level mean-squared-error metric that rewards blurry, smooth approximations in hazy regions, which is why Gaussian Splashing scored 27.93 dB on Kwajalein.  
> However, on Tokai Maru under severe turbidity, Gaussian Splashing over-smoothed the scene, dropping its SSIM to 0.61.  
> In contrast, 3D-UIR explicitly models homodirectional ray gradients, achieving the highest structural similarity across both scenes—0.87 on Kwajalein and 0.70 on Tokai—which preserves the crisp boundary edges essential for detecting real physical change."

---

### Question 5: "What is the exact status of the AIMS EcoRRAP dataset, and how will your pipeline ingest 1.35 terabytes?"
- **Target Response Time:** 25 seconds
- **Key Evidence:** Staged bash scripts; Globus endpoint; institutional DTA in progress.
> **Response:**  
> "The Data Transfer Agreement is currently undergoing standard inter-institutional review between AIMS and QUT legal teams.  
> To ensure zero project delay, our QUT Aqua HPC pipeline was completely built and validated on Submerged3D and Custom OSCD. We have established our Globus high-speed transfer endpoint, meaning as soon as clearance is granted, the EcoRRAP data will stream directly into our automated six-stage batch queue on cluster Lustre storage."

<div class="page-break"></div>

---

# Presenter's Pre-Flight Checklist (15 Minutes Before Talk)

1. **Display & Aspect Ratio:**
   - [ ] Verify HDMI/DisplayPort output is set to **16:9 widescreen (1920×1080)**.
   - [ ] Confirm PowerPoint (`ENN595_2A_Presentation_Slides.pptx` or `.html`) is running in Presentation Mode.
2. **Media Playback Verification:**
   - [ ] Check that orbiting GIFs loop smoothly on **Slide 5, Slide 11, Slide 12, and Slide 13**.
   - [ ] Ensure high-contrast mesh images render clearly on **Slide 12**.
3. **Pacing Anchor Reminders:**
   - [ ] **Slide 1:** Start slow. Establish authority. Breathe.
   - [ ] **Slide 7 (CONOPS):** You should be at exactly **4:00**. If you are at 3:45, you are perfect. If you are past 4:15, pick up the pace slightly.
   - [ ] **Slide 10 (15/15 Pass):** Show enthusiasm—this is your primary technical achievement!
   - [ ] **Slide 14 (Roadmap):** Finish before 8:00. Never rush the final sentence. Leave room for a crisp "Thank you."
4. **Physical Demeanour:**
   - [ ] Stand upright, open posture, avoid turning your back to look at the screen. Use your printed script or laptop presenter view.
   - [ ] Make eye contact with each member of the examination panel.
