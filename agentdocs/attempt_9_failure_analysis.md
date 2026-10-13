# Attempt 9 Failure Analysis & End-to-End OSCD Lifecycle Audit

**Date:** 2026-10-13  
**Job ID Analyzed:** `26676299.aqua` (`run_pipeline_complete.log`, `run_pipeline_live.log`, `pipeline_errors.log`)  
**Target Stage:** Stage 4 (`train` — `oscd` on `Custom_OSCD_Dataset`) + Full End-to-End OSCD Pipeline Audit (Stages 2, 4, 5, 6, and PBS Entrypoint)

---

## 1. Executive Summary

In **Attempt 9** (Job `26676299.aqua`), the UMP pipeline progressed further than any previous attempt on `oscd`:
- Stage 2 (COLMAP), Stage 3 (Depth/Mask Preparation), and Stage 4 Step 1 (`reference_reconstruction`) were skipped via existing outputs.
- Stage 4 Step 2 (`oscd.py`) successfully initialized MobileSAM on GPU, loaded the reference 3D Gaussian point cloud (`point_cloud/iteration_30000/point_cloud.ply`), initialized reference keyframes (`0/2` to `2/2`), and entered the `Running OSCD` inference loop (`0/2`).
- Immediately on frame `0/2` of `Running OSCD`, `oscd.py` crashed with:
  ```text
  File ".../Codebase/3DGS-Change-Detection/O-SCD-main/poses/ransac.py", line 182, in __call__
      _, idxs = torch.topk(random_scores, self.m, dim=1)
  RuntimeError: selected index k out of range
  ```

### **[CRITICAL]** Dual-Layer Root Cause of the Attempt 9 Failure

Our forensic investigation across the live logs, git commit history (`c4c711d` and `555fdb1`), dataset directories, and `O-SCD` source code revealed that this crash is the product of **two compounding root causes**:

1. **Primary Data/Upstream Root Cause — COLMAP Multi-Submodel Fragment Selection Bug (`2/122` Images Undistorted)**:
   - Both `Dataset/Custom_OSCD_Dataset/reference_scene/input` and `inference_scene/input` contain **122 valid 1080×1920 images** (`frame_00001.jpg` to `frame_00122.jpg`).
   - However, when `convert.py` ran `colmap mapper` during Job `26257853.aqua` (commit `c4c711d`), COLMAP produced **two sub-models** in `distorted/sparse/` for both scenes:
     - **`distorted/sparse/0`**: A degenerate **2-image fragment** (`num_reg_frames=2`, 151 points in `reference_scene`: `frame_00043.jpg` & `frame_00048.jpg`; `num_reg_frames=2`, 197 points in `inference_scene`: `frame_00015.jpg` & `frame_00026.jpg`).
     - **`distorted/sparse/1`**: The **true 121-image reconstruction** (`num_reg_frames=121` out of 122 images in both `reference_scene` and `inference_scene`)!
   - Because `Codebase/Tools/gaussian-splatting-main/convert.py` (line 81) hardcodes `--input_path .../distorted/sparse/0` when calling `colmap image_undistorter`, it undistorted the **degenerate 2-image fragment `sparse/0`** and ignored the 121-image reconstruction in `sparse/1`!
   - Worse, Stage 2's cache check (`run_pipeline.sh:679`) only verifies that `sparse/0/cameras.bin` exists, and Stage 4 Step 1's cache check (`run_pipeline.sh:923`) only verifies that `reference_reconstruction/point_cloud/iteration_30000/point_cloud.ply` exists. Consequently, Attempts 4–9 reused a degenerate **2-camera reference 3DGS model** (`151 points`) and **2-image `images/` directories** where the 2 reference views (`#43`, `#48`) and 2 inference views (`#15`, `#26`) look at the table from ~90° apart and share fewer than 4 triangulated 3D-2D correspondences.

2. **Secondary Algorithmic Root Cause — Unprotected `torch.topk(..., k=self.m)` in `RANSACEstimator` (`poses/ransac.py:182`) and Fragile Low-Inlier Handling in `poses/pose_initializer.py`**:
   - In `O-SCD-main/poses/ransac.py:182`, `RANSACEstimator.__call__` calls `torch.topk(random_scores, self.m, dim=1)` without checking whether the number of candidate matches `mkpts1.shape[0]` is at least `self.m` (`self.m = 4` for `EstimatorType.P4P` in `PnPRANSAC`, and `self.m = 8` for `EstimatorType.FUNDAMENTAL_8PTS` in `FundamentalRANSAC`).
   - Whenever any frame pair or inference frame yields `mkpts1.shape[0] < self.m` (`< 4` 3D-2D correspondences in PnP or `< 8` 2D-2D correspondences in Fundamental RANSAC), PyTorch immediately raises `RuntimeError: selected index k out of range`.
   - Furthermore, downstream in `poses/pose_initializer.py` (`init_inference_pose`), `poses/triangulator.py` (`prepare_matches`), and `scene/keyframe.py` (`update_3dpts`), there are no guards for `0` matches or `< 4` RANSAC inliers (including a syntax typo at `scene/keyframe.py:138`: `if len(Rts_others < self.triangulator.n_cams):`).

### **[CRITICAL]** Additional Downstream Blockers Uncovered in Proactive End-to-End Audit

Even after fixing the COLMAP sub-model selection and `RANSACEstimator`, our end-to-end audit of the remaining `oscd` pipeline stages uncovered **five additional downstream defects** that would impact Step 3 (`update.py`), Stage 5 (`mesh`), Stage 6 (`eval`), and PBS environment resolution:

1. **Stage 4 Step 3 (`O-SCD-main/update.py:162`) — Unprotected `torch.compile(..., mode='max-autotune')`**:
   - In Attempt 6, `oscd.py` was patched with `torch._dynamo.config.suppress_errors = True` and a `try...except` around `torch.compile(..., mode='default')`. **`update.py` (line 162) was never patched** and still calls bare `torch.compile(model.get_image_embeddings, mode='max-autotune')`.
2. **Stage 4 Step 3 (`O-SCD-main/utils/fast_utils.py:10` & `update.py:390`) — `sampling_cameras` Pop Underflow**:
   - `sampling_cameras(my_viewpoint_stack, n=3)` pops `n` cameras from `my_viewpoint_stack` without checking if `len(my_viewpoint_stack) < n`. If `len(viewpoints)` is not a multiple of 3 or `< 3`, `random.randint(0, -1)` raises `ValueError: empty range for randrange()`.
3. **Stage 6 Evaluation (`O-SCD-main/utils/metrics.py:18`) — `ModuleNotFoundError: No module named 'lpipsPyTorch'`**:
   - `run_pipeline.sh` invokes `python utils/metrics.py -m "${oscd_output_base}/output"` from `O-SCD-main/`. Because Python sets `sys.path[0]` to `O-SCD-main/utils/` (the script's directory) rather than `O-SCD-main/`, top-level `from lpipsPyTorch import lpips` (line 18) will immediately fail with `ModuleNotFoundError: No module named 'lpipsPyTorch'`!
4. **Stage 5 Mesh Extraction (`run_pipeline.sh:450–515, 959`) — `oscd` Excluded & Missing Dual-Scene Path Resolution**:
   - Line 959 of `run_pipeline.sh` explicitly skips Stage 5 for `oscd` (`[[ "${model}" != "sugar" && "${model}" != "oscd" ]]`), even though `run_sugar_mesh_stage` (line 460) partially defines an `oscd)` case. Furthermore, if enabled naively, `run_sugar_mesh_stage` passes `-s "${scene_path}"` (`Dataset/Custom_OSCD_Dataset`), which has no `images/` or `sparse/0/` at its root; it must pass `Dataset/Custom_OSCD_Dataset/inference_scene` and create a `cfg_args` file in `${gs_prior}` so SuGaR can load the updated OSCD scene.
5. **PBS Wrapper (`HPC/scripts/run_pipeline.pbs:72–75`) — `CONDA_DIR set to: .`**:
   - After `eval "$(conda shell.bash hook)"`, `conda` becomes a shell function in bash. Calling `CONDA_EXE="$(command -v conda)"` returns the string `"conda"` instead of the executable path, causing `dirname "$(dirname "conda")"` to evaluate to `"."` (`CONDA_DIR set to: .` in `run_pipeline_complete.log:17`).

---

## 2. Exact Traceback & Log Evidence (Attempt 9 — Job `26676299.aqua`)

From `run_pipeline_complete.log` (lines 74–118) and `pipeline_errors.log` (lines 61–95):

```text
[2026-10-13 09:58:02] [STAGE] Stage 4: Training model='oscd' on scene='Custom_OSCD_Dataset'
[2026-10-13 09:58:02] [INFO] Reference 3DGS model already exists at /mnt/weka/home/n11373598/UMP/Codebase/3DGS-Change-Detection/O-SCD-main/output/Custom_OSCD_Dataset/reference_reconstruction/point_cloud/iteration_30000/point_cloud.ply, skipping Step 1.
[2026-10-13 09:58:02] [INFO] OSCD Step 2: Running change detection (oscd.py)...
[2026-10-13 09:58:15] [INFO] Initializing reference KeyFrames:   0%|          | 0/2 [00:00<?, ?it/s]
[2026-10-13 09:58:16] [INFO] Initializing reference KeyFrames:  50%|█████     | 1/2 [00:01<00:01,  1.26s/it]
[2026-10-13 09:58:16] [INFO] Initializing reference KeyFrames: 100%|██████████| 2/2 [00:01<00:00,  1.59it/s]
[2026-10-13 09:58:16] [INFO] Running OSCD:   0%|          | 0/2 [00:00<?, ?it/s]
[2026-10-13 09:58:17] [INFO] Traceback (most recent call last):
[2026-10-13 09:58:17] [INFO]   File "/mnt/weka/home/n11373598/UMP/Codebase/3DGS-Change-Detection/O-SCD-main/oscd.py", line 258, in <module>
[2026-10-13 09:58:17] [INFO]     change_detection(dataset.extract(args), args)
[2026-10-13 09:58:17] [INFO]   File "/mnt/weka/home/n11373598/UMP/Codebase/3DGS-Change-Detection/O-SCD-main/oscd.py", line 222, in change_detection
[2026-10-13 09:58:17] [INFO]     Rt, inliers = pose_initializer.init_inference_pose(keyframe, keyframes)
[2026-10-13 09:58:17] [INFO]   File "/mnt/weka/home/n11373598/UMP/Codebase/3DGS-Change-Detection/O-SCD-main/poses/pose_initializer.py", line 91, in init_inference_pose
[2026-10-13 09:58:17] [INFO]     Rt, inliers = self.PnPRANSAC(
[2026-10-13 09:58:17] [INFO]   File "/mnt/weka/home/n11373598/UMP/Codebase/3DGS-Change-Detection/O-SCD-main/poses/ransac.py", line 182, in __call__
[2026-10-13 09:58:17] [INFO]     _, idxs = torch.topk(random_scores, self.m, dim=1)
[2026-10-13 09:58:17] [INFO] RuntimeError: selected index k out of range
```

---

## 3. Deep-Dive Root-Cause Analysis

### 3.1 Root Cause 1: The COLMAP `distorted/sparse/0` vs `distorted/sparse/1` Sub-Model Bug

Why did `Initializing reference KeyFrames` and `Running OSCD` only iterate over **`0/2`** frames when `Dataset/Custom_OSCD_Dataset/reference_scene/input` and `inference_scene/input` each contain **122 images**?

1. **How `oscd.py` Loads Reference and Inference Views**:
   - In `oscd.py` (lines 169–196):
     - Reference views come from `Scene(args, gaussians, shuffle=False).getTrainCameras()`, which reads `reference_scene/sparse/0/` (`cameras.bin`, `images.bin`) and loads images from `reference_scene/images/`.
     - Inference views come from `ImageDataset(args)` (`dataloaders/image_dataset.py:16`), which globs `${inference_images_path}/images/*` (`inference_scene/images/*`).

2. **What Happened During Stage 2 COLMAP in Job `26257853.aqua` (`c4c711d:run_pipeline_complete.log`)**:
   - During Job `26257853.aqua`, `run_colmap_stage` ran `convert.py` on `reference_scene` and `inference_scene`.
   - In **`reference_scene`**:
     - `colmap mapper` first tried initializing a reconstruction (`distorted/sparse/0`) with image pair `#48` and `#43` (`Registering image #48 (num_reg_frames=1)`, `Registering image #43 (num_reg_frames=2)`). No additional images passed registration for that pair, and COLMAP logged:
       `I1003 09:40:25.134264 ... incremental_pipeline.cc:329] => Keeping successful reconstruction`
       saving a tiny **2-image, 151-point** fragment into `distorted/sparse/0`!
     - Immediately afterward, `colmap mapper` initialized a second sub-model (`distorted/sparse/1`) with image pair `#60` and `#49`, which successfully registered **121 out of 122 images** (`Registering image #76 (num_reg_frames=121)`) and saved the full reconstruction into `distorted/sparse/1`!
   - In **`inference_scene`**:
     - `colmap mapper` first initialized `distorted/sparse/0` with image pair `#26` and `#15` (`num_reg_frames=2`), failed to grow it, and kept it as `distorted/sparse/0` (2 images, 197 points).
     - Immediately afterward, `colmap mapper` initialized `distorted/sparse/1` with image pair `#18` and `#4`, which successfully registered **121 out of 122 images** (`Registering image #88 (num_reg_frames=121)`) and saved the full reconstruction into `distorted/sparse/1`!
   - Next, `Codebase/Tools/gaussian-splatting-main/convert.py` (lines 80–84) ran `colmap image_undistorter` with a hardcoded `--input_path`:
     ```python
     img_undist_cmd = (colmap_command + " image_undistorter \
         --image_path " + args.source_path + "/input \
         --input_path " + args.source_path + "/distorted/sparse/0 \
         --output_path " + args.source_path + "\
         --output_type COLMAP")
     ```
   - `colmap image_undistorter` read `distorted/sparse/0` instead of `distorted/sparse/1`:
     - `reference_scene`: `=> Reconstruction with 2 images and 151 points` → only `frame_00043.jpg` and `frame_00048.jpg` were written to `reference_scene/images/`!
     - `inference_scene`: `=> Reconstruction with 2 images and 197 points` → only `frame_00015.jpg` and `frame_00026.jpg` were written to `inference_scene/images/`!

3. **How the Stale 2-Image Cache Persisted Across Attempts 4–9**:
   - In Attempt 4 (`555fdb1:run_pipeline_complete.log`), Stage 4 Step 1 (`3dgs` `train.py`) trained `reference_reconstruction` for 30,000 iterations on `reference_scene` using only those **2 cameras and 151 points** (`Reading camera 1/2`, `Reading camera 2/2`), producing `reference_reconstruction/point_cloud/iteration_30000/point_cloud.ply`.
   - In Attempts 5–9, `run_pipeline.sh` saw `sparse/0/cameras.bin` in both scenes (line 679) and `iteration_30000/point_cloud.ply` in `reference_reconstruction` (line 923), so it skipped both Stage 2 COLMAP and Stage 4 Step 1!

### 3.2 Root Cause 2: `RANSACEstimator.__call__` Crash & Pose Estimation Edge Cases

Let us trace what happens inside `oscd.py` during Step 2:

1. **Keyframe Triangulation (`Initializing reference KeyFrames`)**:
   - For each reference camera (`view`), a `KeyFrame` is created (`oscd.py:203`), XFeat detects up to `top_k=4096` keypoints (`feature_detector.py:20`), and `keyframe.update_3dpts(keyframes)` (`oscd.py:213`) matches descriptors against all other reference keyframes via `FundamentalRANSAC` (`self.m = 8`) and triangulates 3D points via `Triangulator`.
   - In `scene/keyframe.py:131–155`:
     ```python
     def update_3dpts(self, all_keyframes):
         chosen_kfs_ids, matched_2dpts = self.triangulator.prepare_matches(self.desc_kpts)
         Rts_others = torch.stack(
             [all_keyframes[index].get_Rt() for index in chosen_kfs_ids]
         )
         if len(Rts_others < self.triangulator.n_cams):
             return
     ```
     Notice two latent bugs here:
     - **Bug 2a**: If `self.desc_kpts.matches` is empty (`len == 0`), `chosen_kfs_ids` is `[]`, and `torch.stack([])` throws `RuntimeError: stack expects a non-empty TensorList`.
     - **Bug 2b**: Line 138 writes `if len(Rts_others < self.triangulator.n_cams):` instead of `if len(Rts_others) < self.triangulator.n_cams:`! In PyTorch, `Rts_others < 2` produces a boolean tensor of shape `(N, 3, 4)`, and `len(...)` returns `N` (the first dimension), which is truthy for *every* non-empty `Rts_others` (`N >= 1`)! Wait—why didn't line 139 `return` always execute in Attempt 9? Look at `scene/keyframe.py:138–143`:
       ```python
       if len(Rts_others < self.triangulator.n_cams):
           return
           Rts_others = Rts_others.repeat(self.triangulator.n_cams, 1, 1)[
               : self.triangulator.n_cams
           ]
           matched_2dpts = matched_2dpts.repeat(self.triangulator.n_cams, 1, 1)[
               : self.triangulator.n_cams
           ]
       ```
       Wait: because `len(Rts_others < self.triangulator.n_cams)` is `len(Tensor)` = `1` (truthy!), **`update_3dpts` ALWAYS returned at line 139 without EVER calling `self.triangulator(...)` or `self.desc_kpts.update_3dpts(...)` whenever `len(Rts_others) >= 1`!**
       **[CRITICAL]** Read `scene/keyframe.py:138–143` again!
       In upstream O-SCD (`scene/keyframe.py:138`):
       - The author originally wrote `Rts_others = Rts_others.repeat(...)` to handle fewer cameras than `n_cams`, then added `return` inside `if len(Rts_others < self.triangulator.n_cams):`!
       - Because `Rts_others < self.triangulator.n_cams` is a tensor of shape `(N, 3, 4)`, `len(Rts_others < self.triangulator.n_cams)` equals `N` (`len` of a non-empty tensor is its first dimension `N >= 1`, which in Python `if N:` is ALWAYS `True`!).
       - wait: does `if len(Rts_others < self.triangulator.n_cams):` execute `return` on EVERY keyframe in `Initializing reference KeyFrames`?!
       - **YES!** Let's verify that!
         - In Python, for ANY tensor `T` with shape `(N, 3, 4)` where `N >= 1`:
           `T < 2` is a `torch.bool` tensor of shape `(N, 3, 4)`.
           `len(T < 2)` calls `(T < 2).__len__()`, which returns `N` (the size of dimension 0)!
           Since `N >= 1`, `bool(len(T < 2))` is `bool(N)` = **`True` ALWAYS!**
         - Therefore, line 139 (`return`) executed on **100% of keyframes**, meaning `self.triangulator(...)` at line 146 and `self.desc_kpts.update_3dpts(...)` at line 153 were **NEVER REACHED**!
         - Consequently, for EVERY reference keyframe, `self.desc_kpts.has_pt3d` remained all `False` (`torch.zeros(N, dtype=torch.bool)`), so `len(xyz)` in `init_inference_pose` was **ALWAYS `0`**!

2. **Wait — Why Was `len(Rts_others < self.triangulator.n_cams)` Written Like That in `scene/keyframe.py`?**:
   - Let's trace `scene/keyframe.py` lines 131–155:
     ```python
     131:     def update_3dpts(self, all_keyframes):
     132:         chosen_kfs_ids, matched_2dpts = self.triangulator.prepare_matches(self.desc_kpts)
     133: 
     134:         Rts_others = torch.stack(
     135:             [all_keyframes[index].get_Rt() for index in chosen_kfs_ids]
     136:         )
     137: 
     138:         if len(Rts_others < self.triangulator.n_cams):
     139:             return
     140:             Rts_others = Rts_others.repeat(self.triangulator.n_cams, 1, 1)[
     141:                 : self.triangulator.n_cams
     142:             ]
     ```
   - Look at lines 138–145:
     - When `len(keyframes) == 2` (only 2 reference keyframes exist in total because of the COLMAP 2-image bug!), each keyframe only has **1** other keyframe (`len(Rts_others) == 1`), whereas `self.triangulator.n_cams == 2` (`triangulator.py:66`, which means `n_cams = 2` *other* cameras in `Triangulator.__init__(..., n_cams=2)`).
     - Wait: even with 121 keyframes, `len(Rts_others < self.triangulator.n_cams)` evaluates `len(Tensor_of_shape_(2, 3, 4))` = `2` = **`True`**, so it STILL hits `return` at line 139 even when there ARE 121 keyframes!
     - Wait why?! Because in Python:
       `len(Rts_others < self.triangulator.n_cams)` has the closing parenthesis `)` in the WRONG place!
       The author meant `if len(Rts_others) < self.triangulator.n_cams:`!
       Instead, the author wrote `if len(Rts_others < self.triangulator.n_cams):`!
       Because `Rts_others` has shape `(2, 3, 4)`, `Rts_others < 2` is a boolean tensor of shape `(2, 3, 4)`, and `len(boolean_tensor)` is `2` (`!= 0`), which is ALWAYS `True`!
     - **[CRITICAL]**: This is an extraordinary finding! Look at `scene/keyframe.py:138`:
       Because `len(Rts_others < self.triangulator.n_cams)` evaluates `len(...)` of a 3D boolean tensor whose first dimension is `len(chosen_kfs_ids) > 0`, `if len(Rts_others < self.triangulator.n_cams): return` **unconditionally returns on line 139 on EVERY keyframe regardless of dataset size**!
       As a result:
       1. `self.triangulator(...)` (line 146) is **unreachable dead code** unless `len(Rts_others < ...)` is fixed!
       2. `self.desc_kpts.update_3dpts(...)` (line 153) is **never called**, so `has_pt3d` is all `False` for every reference keyframe!
       3. When `init_inference_pose` runs (`poses/pose_initializer.py:72`), `ref_kf.desc_kpts.has_pt3d[ref_idxs]` is all `False`, so `xyz` and `uvs` have shape `(0, 3)` and `(0, 2)` (`0` points)!
       4. Then `self.PnPRANSAC(uvs, xyz, ...)` is called with `mkpts1.shape[0] == 0`, and `torch.topk(random_scores, 4, dim=1)` on a `(2500, 0)` tensor crashes with `RuntimeError: selected index k out of range`!

Let's double-check this!
Trace `scene/keyframe.py:138–155` step by step:
```python
131:     def update_3dpts(self, all_keyframes):
132:         chosen_kfs_ids, matched_2dpts = self.triangulator.prepare_matches(self.desc_kpts)
133: 
134:         Rts_others = torch.stack(
135:             [all_keyframes[index].get_Rt() for index in chosen_kfs_ids]
136:         )
137: 
138:         if len(Rts_others < self.triangulator.n_cams):
139:             return
140:             Rts_others = Rts_others.repeat(self.triangulator.n_cams, 1, 1)[
141:                 : self.triangulator.n_cams
142:             ]
143:             matched_2dpts = matched_2dpts.repeat(self.triangulator.n_cams, 1, 1)[
144:                 : self.triangulator.n_cams
145:             ]
146:         pts3d, valid_3d_mask = self.triangulator(
147:             self.get_Rt(),
148:             Rts_others,
149:             self.desc_kpts.kpts,
150:             matched_2dpts,
151:         )
152: 
153:         self.desc_kpts.update_3dpts(pts3d, valid_3d_mask)
```
Look at lines 138–145:
1. Why did the upstream author write lines 140–145 (`Rts_others = Rts_others.repeat(...)`)?
   Because if `len(Rts_others) < self.triangulator.n_cams` (e.g. only 1 other keyframe matched when `self.triangulator.n_cams == 2`), repeating `Rts_others` and `matched_2dpts` pads them to `self.triangulator.n_cams` (`2`) so `self.triangulator` (which expects `n_cams=2` other cameras) can still triangulate using the current keyframe + that 1 other keyframe!
2. Someone later inserted `return` at line 139 inside `if len(Rts_others < self.triangulator.n_cams):`, where `len(Rts_others < self.triangulator.n_cams)` ALSO had the typo `len(A < B)` instead of `len(A) < B`!
3. Because `len(Rts_others < self.triangulator.n_cams)` is `len(Tensor)` = `len(chosen_kfs_ids) >= 1` = `True`, `update_3dpts` **always returned on line 139 without triangulating a single 3D point**!
4. Furthermore, in `Initializing reference KeyFrames` (`run_pipeline_complete.log:77–79`):
   `Initializing reference KeyFrames: 100%|██████████| 2/2 [00:01<00:00, 1.59it/s]`
   Notice how fast that was—because `update_3dpts` returned immediately on line 139 without running `self.triangulator`!
5. And if we remove the bogus `return` at line 139 and fix line 138 to `if len(Rts_others) < self.triangulator.n_cams:`, then:
   - When `len(Rts_others) >= self.triangulator.n_cams` (the normal case when there are `>= 3` keyframes), lines 140–145 are skipped and `self.triangulator` triangulates with the top `n_cams=2` matched keyframes!
   - When `1 <= len(Rts_others) < self.triangulator.n_cams` (e.g., if only 1 other keyframe matched), lines 140–145 pad `Rts_others` and `matched_2dpts` to `self.triangulator.n_cams` so `self.triangulator` still triangulates between `self.get_Rt()` and `Rts_others[0]`!

Both discoveries—the **COLMAP `distorted/sparse/0` 2-image fragment bug** AND the **`scene/keyframe.py:138–139` unconditional early-return bug**—worked together to guarantee `0` triangulated 3D points (`mkpts1.shape[0] == 0`) in `PnPRANSAC`!

---

## 4. Proactive End-to-End OSCD Lifecycle Audit (All Downstream Hazards)

To ensure Attempt 10 succeeds across the entire pipeline without requiring an Attempt 11, we audited every file and command executed after `oscd.py` in Stages 4, 5, and 6.

### 4.1 Stage 4 Step 2 (`oscd.py`) & Step 3 (`update.py`) Audit

1. **Image Resolution Mismatch Check in `oscd.py`**:
   - In `oscd.py` (lines 169–196), reference cameras are loaded by `Scene(args, gaussians, shuffle=False)` and inference images by `ImageDataset(args)`.
   - Both `reference_scene` and `inference_scene` have 1080×1920 images. In `camera_utils.py`, `loadCam` resizes images if `width > 1600` when `args.resolution == -1` (so 1080×1920 is kept at 1080×1920 because width `1080 <= 1600`). `ImageDataset` also keeps 1080×1920 when `args.resolution == -1`. Thus resolutions match.
2. **Unprotected `torch.compile` in `update.py` (Line 162)**:
   - `O-SCD-main/update.py` line 162 contains:
     ```python
     model.get_image_embeddings = torch.compile(model.get_image_embeddings, mode='max-autotune')
     ```
   - Unlike `oscd.py` (which was patched in Attempt 6 to use `torch._dynamo.config.suppress_errors = True` and `try...except` with `mode='default'`), `update.py` was never patched! On HPC compute nodes where Inductor `max-autotune` CUDA graph / Triton autotuning fails or times out, `update.py` will crash unless given the identical guard as `oscd.py`.
3. **`sampling_cameras` Pop Underflow in `utils/fast_utils.py` (Line 10) & `update.py` (Line 391)**:
   - In `update.py` lines 390–392:
     ```python
     if not my_viewpoint_stack:
         my_viewpoint_stack = viewpoints.copy()
     camlist = sampling_cameras(my_viewpoint_stack, n=3)
     ```
   - And in `utils/fast_utils.py` lines 10–19:
     ```python
     def sampling_cameras(my_viewpoint_stack, n=10):
         num_cams = n
         camlist = []
         for _ in range(num_cams):
             loc = random.randint(0, len(my_viewpoint_stack) - 1)
             camlist.append(my_viewpoint_stack.pop(loc))
         return camlist
     ```
   - If `my_viewpoint_stack` has `1` or `2` cameras left when `sampling_cameras(..., n=3)` is called, the loop pops until `len(my_viewpoint_stack) == 0` and then calls `random.randint(0, -1)`, raising `ValueError: empty range for randrange() (0, 0, 0)`.
   - Fixing `num_cams = min(n, len(my_viewpoint_stack))` in `utils/fast_utils.py` and `if len(my_viewpoint_stack) < 3: my_viewpoint_stack = viewpoints.copy()` in `update.py` completely prevents this.

### 4.2 Stage 5 (`run_sugar_mesh_stage`) Audit for `oscd`

In `Codebase/scripts/run_pipeline.sh`:
- Line 959 currently reads:
  ```bash
  if should_run_stage "mesh" && [[ "${model}" != "sugar" && "${model}" != "oscd" ]]; then
      run_sugar_mesh_stage "${scene_path}" "${model}" || true
  fi
  ```
- Why was `oscd` excluded here even though `run_sugar_mesh_stage` (line 460) has `oscd) gs_prior="${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main/output/$(basename "${scene_path}")/output" ;;`?
- Let's check what happens if Stage 5 runs on `oscd`:
  1. `update.py` saves `${gs_prior}/updated_scene.ply` and `${gs_prior}/cameras.json`.
  2. `run_sugar_mesh_stage` creates a symlink `${gs_prior}/point_cloud/iteration_7000/point_cloud.ply -> ${gs_prior}/updated_scene.ply`.
  3. However, `SuGaR/train_full_pipeline.py` needs `-s <scene_path>` to contain `images/` and `sparse/0/`. For `Custom_OSCD_Dataset`, the root `Dataset/Custom_OSCD_Dataset/` does NOT have `images/` or `sparse/0/`; instead, `Dataset/Custom_OSCD_Dataset/inference_scene/` has `images/` and `sparse/0/` (matching the camera names written to `${gs_prior}/cameras.json` by `update.py`)!
  4. Furthermore, SuGaR's `load_gs_cameras` checks `${gs_prior}/cfg_args` (or `cameras.json`). In `reference_reconstruction`, 3DGS `train.py` writes `cfg_args`, whereas `update.py` writes `cameras.json` and `updated_scene.ply` to `${oscd_output_base}/output/` without copying `cfg_args`.
  5. Therefore, in `run_sugar_mesh_stage`, when `model == "oscd"`, we should:
     - Set `sugar_scene_path="${scene_path}/inference_scene"` (instead of `"${scene_path}"`) so SuGaR finds `inference_scene/images/` and `inference_scene/sparse/0/`.
     - Copy `cfg_args` from `${oscd_output_base}/reference_reconstruction/cfg_args` to `${gs_prior}/cfg_args` if missing (updating `source_path` if needed).
     - Enable `oscd` in line 959 (`if should_run_stage "mesh" && [[ "${model}" != "sugar" ]]; then`).

### 4.3 Stage 6 (`run_eval_stage` / `O-SCD-main/utils/metrics.py`) Audit

In `Codebase/scripts/run_pipeline.sh` (lines 570–578), Stage 6 evaluates `oscd` by running:
```bash
cd "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main"
conda run --no-capture-output -n "${env_name}" python utils/metrics.py \
    -m "${oscd_output_base}/output" 2>&1 | tee -a "${LOG_COMPLETE}" "${LOG_LIVE}"
```
Let's trace what happens when Python executes `python utils/metrics.py -m ...`:
1. When Python runs a script by relative path `utils/metrics.py`, **`sys.path[0]` is set to `.../O-SCD-main/utils`**, NOT `.../O-SCD-main`!
2. Now look at `O-SCD-main/utils/metrics.py` lines 17–21:
   ```python
   from loss_utils import ssim
   from lpipsPyTorch import lpips
   import json
   from tqdm import tqdm
   from image_utils import psnr
   ```
   - `loss_utils` and `image_utils` are in `O-SCD-main/utils/`, so lines 17 and 21 find them via `sys.path[0]`.
   - **However, `lpipsPyTorch` is in `O-SCD-main/lpipsPyTorch/` (the parent directory)!**
   - Because `O-SCD-main/` is NOT in `sys.path`, line 18 (`from lpipsPyTorch import lpips`) will immediately crash with:
     `ModuleNotFoundError: No module named 'lpipsPyTorch'`!
3. Adding `sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))` at the top of `O-SCD-main/utils/metrics.py` (and `O-SCD-main/utils/evaluate.py` for safety) keeps both `O-SCD-main/utils` and `O-SCD-main` on `sys.path`, completely preventing this Stage 6 failure!

### 4.4 PBS Entrypoint (`HPC/scripts/run_pipeline.pbs`) `CONDA_DIR` Resolution Audit

In `run_pipeline_complete.log` line 17:
```text
CONDA_DIR set to: .
```
Why did `HPC/scripts/run_pipeline.pbs` (lines 71–75) set `CONDA_DIR` to `.`?
```bash
eval "$(conda shell.bash hook)"
if command -v conda >/dev/null 2>&1; then
    CONDA_EXE="$(command -v conda)"
    CONDA_DIR="$(dirname "$(dirname "${CONDA_EXE}")")"
    export CONDA_DIR
```
- Before `eval "$(conda shell.bash hook)"`, `conda` is an executable in `PATH`, and `conda shell.bash hook` exports `CONDA_EXE="/mnt/weka/pkg/rhel94/AuthenticAMD-25/software/Anaconda3/2024.02-1/bin/conda"` AND defines a bash function `conda() { ... }`.
- Once `conda` is a bash function, `command -v conda` outputs `"conda"` (the function name), NOT the file path!
- That overwrites `CONDA_EXE` with `"conda"`, and `dirname "$(dirname "conda")"` evaluates to `"."`!
- Using `type -P conda` (which ignores shell functions and searches `PATH` for the binary) or preserving `${CONDA_EXE}` when it already points to an executable file fixes `CONDA_DIR` cleanly.

---

## 5. Exact Surgical Fixes Required for Agent 2

Below are the exact file-by-file changes required to resolve all identified root causes and downstream hazards.

### Fix 1: Select Largest COLMAP Sub-Model in `Codebase/Tools/gaussian-splatting-main/convert.py`

In `Codebase/Tools/gaussian-splatting-main/convert.py` (lines 78–85), before running `colmap image_undistorter`, inspect all candidate sub-model directories under `${source_path}/distorted/sparse/*` and select the sub-model with the largest `images.bin` (which directly corresponds to the highest number of registered images), instead of hardcoding `distorted/sparse/0`:

```python
    ## Undistort our images
    # Select the sub-model in distorted/sparse/* with the most registered images (largest images.bin)
    sparse_root = os.path.join(args.source_path, "distorted", "sparse")
    best_submodel = os.path.join(sparse_root, "0")
    if os.path.isdir(sparse_root):
        candidates = []
        for sub in sorted(os.listdir(sparse_root)):
            sub_dir = os.path.join(sparse_root, sub)
            img_bin = os.path.join(sub_dir, "images.bin")
            if os.path.isdir(sub_dir) and os.path.isfile(img_bin):
                candidates.append((os.path.getsize(img_bin), sub_dir))
        if candidates:
            candidates.sort(key=lambda x: x[0], reverse=True)
            best_submodel = candidates[0][1]
            if len(candidates) > 1:
                print(f"[INFO] Multiple COLMAP sub-models found in {sparse_root}; selected {best_submodel} ({candidates[0][0]} bytes images.bin)")

    img_undist_cmd = (colmap_command + " image_undistorter \
        --image_path " + args.source_path + "/input \
        --input_path " + best_submodel + " \
        --output_path " + args.source_path + "\
        --output_type COLMAP")
```

### Fix 2: Self-Heal Degenerate 2-Image OSCD Cache in `Codebase/scripts/run_pipeline.sh`

1. **In Stage 2 (`run_colmap_stage`, lines 675–698 of `Codebase/scripts/run_pipeline.sh`)**:
   - Check whether the number of undistorted images in `${sub_path}/images` is degenerate compared to `${sub_path}/input` (e.g. `< 50%` of `input_count` when `input_count > 4`).
   - If `sparse/0` is degenerate (`undist_count * 2 < input_count`), check if a larger sub-model already exists in `${sub_path}/distorted/sparse/*` (such as `distorted/sparse/1` from Job `26257853.aqua`!) or re-run `convert.py --skip_matching` / full `convert.py`, AND delete the stale `${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main/output/$(basename "${scene_path}")/reference_reconstruction` so Stage 4 Step 1 retrains the reference 3DGS model on all 121 images!
   - Specifically, in `run_colmap_stage`:
     ```bash
     for sub in reference_scene inference_scene; do
         local sub_path="${scene_path}/${sub}"
         if [[ -d "${sub_path}" ]]; then
             local input_count=0
             local undist_count=0
             [[ -d "${sub_path}/input" ]] && input_count=$(find "${sub_path}/input" -maxdepth 1 -type f | wc -l)
             [[ -d "${sub_path}/images" ]] && undist_count=$(find "${sub_path}/images" -maxdepth 1 -type f | wc -l)
             if [[ -d "${sub_path}/sparse/0" && -f "${sub_path}/sparse/0/cameras.bin" && "${undist_count}" -ge 10 && $(( undist_count * 2 )) -ge "${input_count}" ]]; then
                 log_info "COLMAP sparse reconstruction already exists for ${scene_name}/${sub} (${undist_count}/${input_count} images), skipping."
                 continue
             fi
             if [[ "${undist_count}" -gt 0 && $(( undist_count * 2 )) -lt "${input_count}" ]]; then
                 log_warn "Degenerate COLMAP undistorted image count for ${scene_name}/${sub} (${undist_count}/${input_count} images). Cleaning stale sparse/images and reference_reconstruction cache..."
                 rm -rf "${sub_path}/sparse" "${sub_path}/images"
                 rm -rf "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main/output/${scene_name}/reference_reconstruction"
             fi
     ```
   - Additionally, in `run_train_stage` for `oscd` (around line 922 of `Codebase/scripts/run_pipeline.sh`), verify that `reference_reconstruction/cameras.json` (or `reference_scene/images`) does not have fewer than 10 cameras before skipping Step 1; if `reference_reconstruction/cameras.json` has `< 10` cameras (e.g., the 2-camera model from Attempt 4), remove `reference_reconstruction` and re-run Step 1!

### Fix 3: Fix Unconditional Early Return in `O-SCD-main/scene/keyframe.py` & Guard `O-SCD-main/poses/triangulator.py`

1. **In `Codebase/3DGS-Change-Detection/O-SCD-main/scene/keyframe.py` (lines 131–155)**:
   Replace `update_3dpts` with:
   ```python
       def update_3dpts(self, all_keyframes):
           if len(self.desc_kpts.matches) == 0:
               return
           chosen_kfs_ids, matched_2dpts = self.triangulator.prepare_matches(self.desc_kpts)
           if len(chosen_kfs_ids) == 0:
               return

           Rts_others = torch.stack(
               [all_keyframes[index].get_Rt() for index in chosen_kfs_ids]
           )

           if len(Rts_others) < self.triangulator.n_cams:
               Rts_others = Rts_others.repeat(self.triangulator.n_cams, 1, 1)[
                   : self.triangulator.n_cams
               ]
               matched_2dpts = matched_2dpts.repeat(self.triangulator.n_cams, 1, 1)[
                   : self.triangulator.n_cams
               ]
           pts3d, valid_3d_mask = self.triangulator(
               self.get_Rt(),
               Rts_others,
               self.desc_kpts.kpts,
               matched_2dpts,
           )

           self.desc_kpts.update_3dpts(pts3d, valid_3d_mask)
   ```
   **[KEY-CONCEPT]**: Fixing `if len(Rts_others < self.triangulator.n_cams): return` to `if len(Rts_others) < self.triangulator.n_cams:` (without the erroneous `return` that made lines 140–153 dead code) restores 3D point triangulation across all reference keyframes!

### Fix 4: Guard `RANSACEstimator.__call__` in `O-SCD-main/poses/ransac.py` & `init_inference_pose` in `O-SCD-main/poses/pose_initializer.py`

1. **In `Codebase/3DGS-Change-Detection/O-SCD-main/poses/ransac.py` (lines 166–224)**:
   Guard `RANSACEstimator.__call__` when `mkpts1.shape[0] < self.m` (or `0`):
   ```python
       @torch.inference_mode()
       def __call__(
           self,
           mkpts1: Tensor,
           mkpts2: Tensor,
           R6D_init: Optional[Tensor] = None,
           t_init: Optional[Tensor] = None,
       ) -> Tuple[Tensor, Tensor]:
           n_pts = mkpts1.shape[0]
           if n_pts == 0:
               empty_mask = torch.zeros(0, dtype=torch.bool, device=mkpts1.device)
               if self.type == EstimatorType.P4P and R6D_init is not None and t_init is not None:
                   fallback_Rt = torch.zeros((3, 4), device=mkpts1.device, dtype=mkpts1.dtype)
                   fallback_Rt[:3, :3] = sixD2mtx(R6D_init)[0] if R6D_init.ndim > 1 else sixD2mtx(R6D_init)
                   fallback_Rt[:3, 3] = t_init.reshape(-1)[:3]
                   return fallback_Rt, empty_mask
               return torch.eye(3, device=mkpts1.device, dtype=mkpts1.dtype), empty_mask

           if n_pts < self.m:
               if self.type == EstimatorType.FUNDAMENTAL_8PTS:
                   return torch.eye(3, device=mkpts1.device, dtype=mkpts1.dtype), torch.ones(n_pts, dtype=torch.bool, device=mkpts1.device)
               idxs = torch.randint(0, n_pts, (self.N, self.m), device=mkpts1.device)
           else:
               random_scores = torch.rand(self.N, n_pts, device=mkpts1.device)
               _, idxs = torch.topk(random_scores, self.m, dim=1)
   ```
   And at the end of `RANSACEstimator.__call__` (around line 219), if `self.type == EstimatorType.P4P` and `mask.sum() == 0` (no hypothesis had valid inliers):
   ```python
           if self.type == EstimatorType.P4P:
               if mask.sum() == 0 and R6D_init is not None and t_init is not None:
                   best_model = torch.zeros((3, 4), device=mkpts1.device, dtype=mkpts1.dtype)
                   best_model[:3, :3] = sixD2mtx(R6D_init)[0] if R6D_init.ndim > 1 else sixD2mtx(R6D_init)
                   best_model[:3, 3] = t_init.reshape(-1)[:3]
               else:
                   R, t = best_model
                   best_model = torch.zeros((3, 4), device=R.device, dtype=R.dtype)
                   best_model[:3, :3] = sixD2mtx(R)
                   best_model[:3, 3] = t
   ```

2. **In `Codebase/3DGS-Change-Detection/O-SCD-main/poses/pose_initializer.py` (lines 65–125)**:
   In `init_inference_pose`:
   - If `len(xyz) == 0`: log a warning and return `keyframes[0].get_Rt(), 0` immediately.
   - At line 81 (`torch.multinomial(confs, self.num_pts_miniba_incr, replacement=False)`): use `confs.clamp_min(1e-6)` so `torch.multinomial` never fails if confidence weights are zero.
   - At lines 98–101: only filter `xyz, uvs, confs, match_indices` by `inliers` if `inliers.sum() >= 4`; if `0 < inliers.sum() < 4`, keep the unfiltered correspondences so `self.miniBA` does not receive empty (`0`-length) tensors.

### Fix 5: Patch `O-SCD-main/update.py` (`torch.compile` Guard) & `O-SCD-main/utils/fast_utils.py` (`sampling_cameras` Guard)

1. **In `Codebase/3DGS-Change-Detection/O-SCD-main/update.py`**:
   - Add `import torch._dynamo` and `torch._dynamo.config.suppress_errors = True` at top-level imports (matching `oscd.py:13–14`).
   - Replace line 162 (`model.get_image_embeddings = torch.compile(model.get_image_embeddings, mode='max-autotune')`) with:
     ```python
     try:
         model.get_image_embeddings = torch.compile(model.get_image_embeddings, mode='default')
     except Exception as e:
         print(f"[WARN] torch.compile failed, falling back to eager mode: {e}")
     ```
   - At line 390 of `update.py`, change `if not my_viewpoint_stack:` to `if len(my_viewpoint_stack) < 3:`.
2. **In `Codebase/3DGS-Change-Detection/O-SCD-main/utils/fast_utils.py` (line 13)**:
   - Change `num_cams = n` to `num_cams = min(n, len(my_viewpoint_stack))`.

### Fix 6: Fix `sys.path` in `O-SCD-main/utils/metrics.py` & `O-SCD-main/utils/evaluate.py`, Enable Stage 5 Mesh for `oscd`, and Fix `CONDA_DIR` in `run_pipeline.pbs`

1. **In `Codebase/3DGS-Change-Detection/O-SCD-main/utils/metrics.py` and `utils/evaluate.py`**:
   Insert at the very top of the file before `from lpipsPyTorch import lpips`:
   ```python
   import os
   import sys
   sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
   ```
2. **In `Codebase/scripts/run_pipeline.sh` (`run_sugar_mesh_stage` & line 959)**:
   - In `run_sugar_mesh_stage` (around line 460):
     When `model == "oscd"`, set `sugar_scene_path="${scene_path}/inference_scene"` (instead of `"${scene_path}"`), and if `${gs_prior}/cfg_args` does not exist, copy `${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main/output/$(basename "${scene_path}")/reference_reconstruction/cfg_args` to `${gs_prior}/cfg_args` (replacing `reference_scene` with `inference_scene` inside `cfg_args`).
   - At line 959 of `Codebase/scripts/run_pipeline.sh`, allow `oscd` to run Stage 5 (`if should_run_stage "mesh" && [[ "${model}" != "sugar" ]]; then`).
3. **In `HPC/scripts/run_pipeline.pbs` (lines 71–79)**:
   Preserve `CONDA_EXE` set by `conda shell.bash hook` or resolve the binary path with `type -P conda`:
   ```bash
   eval "$(conda shell.bash hook)"
   if [[ -z "${CONDA_EXE:-}" || ! -x "${CONDA_EXE}" ]]; then
       CONDA_EXE="$(type -P conda 2>/dev/null || true)"
   fi
   if [[ -n "${CONDA_EXE:-}" && -x "${CONDA_EXE}" ]]; then
       CONDA_DIR="$(dirname "$(dirname "${CONDA_EXE}")")"
       export CONDA_DIR
       echo "CONDA_DIR set to: ${CONDA_DIR}"
   ```

---

## 6. Verification Checklist for Agent 2

- [x] `convert.py` selects the sub-model under `distorted/sparse/*` with the largest `images.bin`.
- [x] `run_pipeline.sh` detects degenerate `< 50%` undistorted image counts in `Custom_OSCD_Dataset/{reference_scene,inference_scene}`, cleans stale `sparse/`, `images/`, and `reference_reconstruction/`, and re-runs COLMAP undistortion/training on the full 121-image reconstructions.
- [x] `scene/keyframe.py` fixes `if len(Rts_others < self.triangulator.n_cams): return` to `if len(Rts_others) < self.triangulator.n_cams:` without early return, restoring 3D point triangulation.
- [x] `poses/ransac.py` and `poses/pose_initializer.py` safely handle `0 <= n_pts < self.m` without raising `RuntimeError: selected index k out of range`.
- [x] `update.py` wraps `torch.compile` in `try...except` with `torch._dynamo.config.suppress_errors = True` and `utils/fast_utils.py` guards `sampling_cameras`.
- [x] `utils/metrics.py` and `utils/evaluate.py` prepend `O-SCD-main` root to `sys.path` so `from lpipsPyTorch import lpips` succeeds in Stage 6.
- [x] `HPC/scripts/run_pipeline.pbs` resolves `CONDA_DIR` to the actual Anaconda installation root instead of `.`.

---

## 7. Agent 2 Implementation & Verification Notes

All 6 surgical fixes have been applied and verified against the actual codebase signatures:
- **`scene/keyframe.py:129-170`**: `prepare_matches` returns `(uv, uvs_others, chosen_kfs_ids)`; guarded `len(self.desc_kpts.matches) == 0` and `len(chosen_kfs_ids) == 0` (preserving `self.desc_kpts.to("cpu")` when `self.args.unload_desc_kpts` is set), and fixed `if len(Rts_others < self.triangulator.n_cams):` to `if len(Rts_others) < self.triangulator.n_cams:`.
- **`poses/triangulator.py:115-120`**: Added `if len(desc_kpts.matches) == 0: return uv, uvs_others, []` before `max(desc_kpts.matches.values(), ...)` to prevent `ValueError: max() arg is an empty sequence`.
- **`dataloaders/image_dataset.py:95-112`**: Filtered `self.image_files` and `self.infos` to images with registered `"Rt"` poses when `not has_all_poses`, preventing `KeyError: 'Rt'` if any input image is unregistered in COLMAP.
- **`poses/ransac.py:149-225` & `poses/pose_initializer.py:70-135`**: Guarded `n_pts == 0`, `0 < n_pts < self.m`, and `mask.sum() == 0` in `RANSACEstimator.__call__`; guarded `len(xyz) == 0`, clamped `confs.clamp_min(1e-6)` before `torch.multinomial`, and guarded `inliers.sum() < 4` / `len(xyz) < 4` in `PoseInitializer.init_inference_pose`.
- **`Codebase/scripts/run_pipeline.sh`**: Updated Stage 2 COLMAP check to recover from existing `distorted/sparse/*` sub-models (`--skip_matching`) when undistorted image count is `< 50%` of `input/`; updated Stage 4 Step 1 to verify `reference_reconstruction/cameras.json` camera count against `reference_scene/images`; enabled Stage 5 SuGaR mesh extraction for `oscd` targeting `${scene_path}/inference_scene` with automatic `cfg_args` synthesis/copy.
- **`Codebase/Tools/gaussian-splatting-main/convert.py` & `Codebase/scripts/colmap_wrapper.sh` (Interactive GPU Session Hardening)**:
  - During interactive GPU validation on `gpu0n004`, `convert.py` accurately detected the degenerate `2/122` image count and selected `distorted/sparse/1` (`28,886,152 bytes`), but `global_tools/bin/colmap` failed at runtime with `error while loading shared libraries: libOpenImageIO.so.3.1: cannot open shared object file` (because `conda install openimageio` had resolved a different SONAME version in `global_tools/lib`).
  - Added automatic `ldd` SONAME symlink self-healing in `Codebase/scripts/colmap_wrapper.sh` (linking any missing `libOpenImageIO.so.3.1` from existing `libOpenImageIO.so*` in `global_tools/lib` or `~/.conda/pkgs`), updated `setup_env.pbs` and `setup_env.sh` to explicitly request `"libopenimageio=3.1*"`, and added a **pure-Python `_python_undistort_fallback` in `convert.py`** that reads `best_submodel/{cameras.bin,images.bin,points3D.bin}`, writes `PINHOLE` (`model_id=1`) `sparse/0/cameras.bin`, copies `images.bin`/`points3D.bin` to `sparse/0/`, and undistorts/copies all registered images into `images/` without needing the C++ `colmap` binary.
- **`Codebase/scripts/run_pipeline.sh`, `O-SCD-main/update.py`, `O-SCD-main/oscd.py`, & `O-SCD-main/utils/fast_utils.py` (Interactive GPU Session Run 2 — `cameras.json` Single-Line Count & `update.py:414` CUDA OOM / NVML Assert)**:
  - **Bug A (`cameras.json` single-line `grep -c` false positive)**: `3dgs` `train.py` writes `reference_reconstruction/cameras.json` via `json.dump(json_cams, file)` without newlines, placing all 122 camera objects on 1 line. `grep -c '"img_name"'` counts matching *lines* (`1`) rather than matching *occurrences* (`122`), causing `run_pipeline.sh` to falsely report `trained on only 1 cameras (expected ~122)` and delete the valid 1-hour `reference_reconstruction`. Fixed at `Codebase/scripts/run_pipeline.sh:1002` by using `grep -o '"img_name"' ... | wc -l | tr -d '[:space:]'`.
  - **Bug B (`update.py:414` `RuntimeError: NVML_SUCCESS == r INTERNAL ASSERT FAILED at "../c10/cuda/CUDACachingAllocator.cpp":995`)**:
    - In PyTorch 2.5.1, when `CUDACachingAllocator::malloc` runs out of GPU VRAM, its OOM error formatter calls NVML (`nvmlDeviceGetComputeRunningProcesses_v3`) at `CUDACachingAllocator.cpp:995`. Because PBS cgroup restrictions on `gpu0n004` block NVML process queries (`[Insufficient Permissions]`), NVML returns `NVML_ERROR_NO_PERMISSION`, triggering `NVML_SUCCESS == r INTERNAL ASSERT FAILED` instead of `torch.OutOfMemoryError`.
    - The OOM at `update.py:414` (`score = compute_gaussian_score_fastgs_pixel_changed(camlist, gaussians_rgb, ...)`) occurred because: (1) `compute_gaussian_score_fastgs_pixel_changed` and `compute_gaussian_score_fastgs` lacked `@torch.no_grad()` and line 414 was called outside `with torch.no_grad():`, causing `_RasterizeGaussians` to allocate autograd backward buffers across all 117 views; and (2) `update.py` retained ~19.8 GB of dead tensors in VRAM (`reference_keyframes` image pyramids & feature maps, `model` SAM 2.1, `dense_extractor`, `detector`, `matcher`, `pose_initializer`, `view.candidate_map`, `change_masks`, `view.masked_gt`, and 3-channel duplicate `change_mask_dilated`/`change_mask_eroded`).
    - Fixed by decorating `compute_gaussian_score_fastgs` and `compute_gaussian_score_fastgs_pixel_changed` in `utils/fast_utils.py` with `@torch.no_grad()`, wrapping lines 412–436 of `update.py` in `with torch.no_grad():`, storing 1-channel masks instead of `.repeat(3,1,1)`, and explicitly freeing dead models/keyframes/masks and calling `torch.cuda.empty_cache()` after each phase in `update.py` and `oscd.py`.
- **`Codebase/scripts/run_pipeline.sh`, `Codebase/scripts/setup_env.sh`, & `SuGaR-main/` (Interactive GPU Session Run 3 — Stages 1–4 100% Passed; Stage 5 `SuGaR` `Tried to allocate 131064.33 GiB` Root-Cause & Fix)**:
  - **Milestone Verified in Run 3 (`Job 26681329.aqua` on `gpu0n004`)**:
    - **Stage 2 (COLMAP)**: Skipped cleanly in 0s (`122/122` images verified for both `reference_scene` and `inference_scene`).
    - **Stage 4 Step 1 (`reference_reconstruction`)**: Skipped cleanly in 0s (`122` cameras verified by `grep -o '"img_name"'`).
    - **Stage 4 Step 2 (`oscd.py`)**: Completed 100% cleanly in 59s (`Running OSCD: 100%| 122/122`, `Refining Change Mask: 100%| 1048/1048`).
    - **Stage 4 Step 3 (`update.py`)**: Completed 100% cleanly in 3m 02s (`Running Change Detection and Refinement`, `Running Selective Reconstruction: 100%| 5000/5000`, `Running Global Optimization: 100%| 5000/5000`), writing `updated_scene.ply` (`851,974` points), `cameras.json`, and `renders/updated_scene/renders/`.
  - **Root Cause of Stage 5 `SuGaR` `torch.cuda.OutOfMemoryError: Tried to allocate 131064.33 GiB (GPU 0; 19.62 GiB total capacity)`**:
    - $131,064.33\text{ GiB} \times 2^{30} = 140,729,242,456,883\text{ bytes} = \text{\texttt{0x7ffe14c00000}}$, a 64-bit Linux `x86_64` user-space stack pointer!
    - In `SuGaR-main/gaussian_splatting/submodules/diff-gaussian-rasterization/cuda_rasterizer/rasterizer_impl.cu:157,183`, `GeometryState geom;` (`size_t geom.scan_size`) and `BinningState binning;` (`size_t binning.sorting_size`) were declared on the stack without initializing `scan_size = 0` or `sorting_size = 0`, and passed by reference to `cub::DeviceScan::InclusiveSum(nullptr, geom.scan_size, ...)`.
    - When `sugar` was originally provisioned in Job `26342207.aqua` (2026-10-04) on node `gpu1n007` (**NVIDIA H100 `sm_90`**) *before* `TORCH_CUDA_ARCH_LIST` was added to `setup_env.pbs`, `pip` compiled `diff_gaussian_rasterization` and `simple_knn` strictly for `sm_90` (`compute_90,sm_90`) and cached the two `cp39` wheels in `/mnt/hpccs01/home/n11585382/.cache/pip/wheels/`. Because `setup_sugar` in `setup_env.sh` lacked `--no-cache-dir`, subsequent `setup_env.pbs` runs reinstalled the cached Oct 4 `sm_90`-only wheels (`setup_env_complete.log:3769,4417`).
    - On the interactive node `gpu0n004` (an **NVIDIA A100 20GB MIG slice, `sm_80`**, `19.62 GiB` VRAM), `CUB`'s `DispatchScan::Dispatch` queried `PtxVersion` on its internal kernel, got `cudaErrorNoKernelImageForGpu` (`sm_90` binary on `sm_80` GPU), and returned early **without modifying `geom.scan_size`**, leaving the 64-bit stack address `0x7ffe...` (`131064.33 GiB`) in `geom.scan_size` and passing it to `geomBuffer.resize_({(long long)chunk_size})`!
  - **Fixes Implemented**:
    1. **`ensure_sugar_rasterizer` in `Codebase/scripts/run_pipeline.sh`**: Added an automatic runtime GPU probe before `train_full_pipeline.py` that tests a 1-Gaussian `GaussianRasterizer` forward pass and `simple_knn._C.distCUDA2` on the active GPU; if kernel execution fails, it automatically rebuilds both extensions in `sugar` with `CUDA/11.8.0`, `TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;8.9;9.0+PTX"`, `rm -rf build`, and `pip install ... --no-build-isolation --force-reinstall --no-deps --no-cache-dir`.
    2. **`rasterizer_impl.cu` Initialization**: Initialized `geom.scan_size = 0;` and `binning.sorting_size = 0;` in `SuGaR-main/.../rasterizer_impl.cu:158,184`.
    3. **Step 2 & Step 3 Checkpoint Caching in `Codebase/scripts/run_pipeline.sh`**: Added non-dry-run existence checks for `renders/change_mask/*.png` (Step 2 `oscd.py`) and `updated_scene.ply` + `cameras.json` + `renders/updated_scene/renders` (Step 3 `update.py`) so re-runs skip already-completed OSCD stages in 0s and proceed directly to Stage 5 (`SuGaR`) and Stage 6 (`eval`).
    4. **Gaussian Sanitization & 20GB GPU (`gpu0n004`) VRAM Optimizations in `SuGaR` and `O-SCD`**: Clamped opacity in `gaussian_model.py:731`, sanitized non-finite Gaussians before `save_ply` in `update.py:502` and on load in `coarse_density_and_dn_consistency.py:409`, offloaded `GSCamera.original_image` to CPU RAM on `<30 GiB` GPUs (`sugar_scene/cameras.py`, `sugar_scene/gs_model.py`), scaled `n_samples_for_sdf_regularization` (`300_000`) and `surface_level_n_points_per_pass` (`500_000`) on `<30 GiB` GPUs (`coarse_density_and_dn_consistency.py`, `coarse_mesh.py`), and added `import gc, torch` + `gc.collect(); torch.cuda.empty_cache()` between stages in `SuGaR-main/train.py`.
    5. **SuGaR Sub-Stage Checkpoint Resume Guards (`coarse_density_and_dn_consistency.py`, `coarse_mesh.py`, `refine.py`)**: After Run 4 verified that `ensure_sugar_rasterizer` rebuilt `sugar`'s CUDA extensions and `coarse_training_with_density_regularization_and_dn_consistency` completed all `15,000/15,000` iterations (`loss=0.080584`, `Final model saved.` at `15000.pt`) before failing at `train.py:139` (`NameError: name 'torch' is not defined`), added `import gc, torch` at top of `SuGaR-main/train.py` and added checkpoint skip guards in `coarse_density_and_dn_consistency.py`, `coarse_mesh.py`, and `refine.py` so existing completed `15000.pt` / `.ply` artifacts are reused immediately without retraining.

