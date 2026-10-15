#!/usr/bin/env python3
"""
generate_change_heatmaps.py
===========================
Transforms binary 2D change masks and 3DGS checkpoints into:
  1. Reconstructed Video Heat Map:
     - Overlay MP4 (oscd_change_heatmap_overlay.mp4)
     - 4-Panel Side-by-Side MP4: [Reference | Inference | Thermal Overlay | Binary Mask]
     - 2x2 Quad Grid MP4 for standard 16:9 monitors (oscd_change_comparison_2x2_grid.mp4)
  2. Two 3D Viewable Turbo Heat Map Gaussian Splats (.ply) for SuperSplat:
     - Output A (O-SCD_3D_Change_Heatmap_Turbo.ply):
       Clean Turbo heatmap showing the updated scene with moved/added objects highlighted.
     - Output B (O-SCD_3D_Change_Heatmap_Turbo_All_Changes.ply):
       Shows ALL changes including the 3D volumetric "ghost" of the removed red soda can
       and previous object positions spliced from the reference 3DGS model and lit up as
       bright red thermal hotspots.
  3. High-resolution publication-quality 4-column keyframe comparison figure.

Usage:
    python Model_Outputs/generate_change_heatmaps.py
"""

import json
import struct
import shutil
import argparse
from pathlib import Path
from typing import List, Tuple, Optional, Dict

import cv2
import numpy as np
import scipy.spatial
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import connected_components


# SH constant for DC component: RGB = SH_C0 * f_dc + 0.5
SH_C0 = 0.28209479177387814


def apply_turbo_colormap_array(values: np.ndarray) -> np.ndarray:
    """
    Maps a 1D float array in [0, 1] to exact Google Turbo RGB values in [0, 1]
    using OpenCV's built-in 256-entry lookup table.
    """
    uint8_vals = np.clip(values * 255.0, 0, 255).astype(np.uint8)
    bgr = cv2.applyColorMap(uint8_vals.reshape(-1, 1), cv2.COLORMAP_TURBO).reshape(-1, 3)
    rgb = bgr[:, ::-1].astype(np.float32) / 255.0
    return rgb


def read_ply_data(ply_path: Path):
    """
    Parses a binary little endian 3D Gaussian Splatting PLY file.
    Returns (header_text, properties_list, raw_data, vertex_count).
    """
    with open(ply_path, "rb") as f:
        header_lines = []
        while True:
            line = f.readline().decode("latin1")
            header_lines.append(line)
            if line.strip() == "end_header":
                break

        header_text = "".join(header_lines)
        num_vertices = 0
        properties = []

        for line in header_lines:
            tokens = line.strip().split()
            if len(tokens) >= 3 and tokens[0] == "element" and tokens[1] == "vertex":
                num_vertices = int(tokens[2])
            elif len(tokens) >= 3 and tokens[0] == "property":
                properties.append((tokens[2], tokens[1]))

        dt_list = []
        for prop_name, prop_type in properties:
            if prop_type in ["float", "float32"]:
                dt_list.append((prop_name, "<f4"))
            elif prop_type in ["double", "float64"]:
                dt_list.append((prop_name, "<f8"))
            elif prop_type in ["int", "int32"]:
                dt_list.append((prop_name, "<i4"))
            elif prop_type in ["uchar", "uint8"]:
                dt_list.append((prop_name, "u1"))
            else:
                dt_list.append((prop_name, "<f4"))

        dt = np.dtype(dt_list)
        raw_data = np.fromfile(f, dtype=dt, count=num_vertices)
        return header_text, properties, raw_data, num_vertices


def write_ply_data(out_path: Path, properties: List[Tuple[str, str]], raw_data: np.ndarray):
    """Writes a structured numpy array to a binary little endian PLY file."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    num_vertices = len(raw_data)

    header = [
        "ply",
        "format binary_little_endian 1.0",
        f"element vertex {num_vertices}",
    ]
    for p_name, p_type in properties:
        header.append(f"property {p_type} {p_name}")
    header.append("end_header\n")

    with open(out_path, "wb") as f:
        f.write("\n".join(header).encode("latin1"))
        raw_data.tofile(f)


def zero_higher_order_sh(data: np.ndarray, mask: Optional[np.ndarray] = None):
    """
    Zeros out higher-order Spherical Harmonics (f_rest_0 .. f_rest_44) so that
    view-dependent directional SH coefficients do not corrupt false-color heatmaps.
    """
    field_names = data.dtype.names or ()
    for name in field_names:
        if name.startswith("f_rest_"):
            if mask is None:
                data[name] = 0.0
            else:
                data[name][mask] = 0.0


# ==============================================================================
# COLMAP Camera Pose Loader & Multi-View 2D Change Mask Back-Projection
# ==============================================================================
def qvec2rotmat(qvec: np.ndarray) -> np.ndarray:
    """Converts COLMAP quaternion (qw, qx, qy, qz) to 3x3 rotation matrix."""
    return np.array([
        [1 - 2 * qvec[2]**2 - 2 * qvec[3]**2,
         2 * qvec[1] * qvec[2] - 2 * qvec[0] * qvec[3],
         2 * qvec[3] * qvec[1] + 2 * qvec[0] * qvec[2]],
        [2 * qvec[1] * qvec[2] + 2 * qvec[0] * qvec[3],
         1 - 2 * qvec[1]**2 - 2 * qvec[3]**2,
         2 * qvec[2] * qvec[3] - 2 * qvec[0] * qvec[1]],
        [2 * qvec[3] * qvec[1] - 2 * qvec[0] * qvec[2],
         2 * qvec[2] * qvec[3] + 2 * qvec[0] * qvec[1],
         1 - 2 * qvec[1]**2 - 2 * qvec[2]**2]
    ], dtype=np.float32)


def load_colmap_cameras_and_images(sparse_dir: Path) -> List[Dict]:
    """
    Reads COLMAP binary (cameras.bin, images.bin) or text (cameras.txt, images.txt)
    files to allow exact projection of 3D Gaussians into the 2D change_masks.
    """
    cameras = {}
    poses = []

    cam_bin = sparse_dir / "cameras.bin"
    img_bin = sparse_dir / "images.bin"
    cam_txt = sparse_dir / "cameras.txt"
    img_txt = sparse_dir / "images.txt"

    CAMERA_MODELS = {
        0: ("SIMPLE_PINHOLE", 3),
        1: ("PINHOLE", 4),
        2: ("SIMPLE_RADIAL", 4),
        3: ("RADIAL", 5),
        4: ("OPENCV", 8),
    }

    if cam_bin.exists() and img_bin.exists():
        try:
            with open(cam_bin, "rb") as f:
                num_cams = struct.unpack("<Q", f.read(8))[0]
                for _ in range(num_cams):
                    cam_id, model_id, width, height = struct.unpack("<iiQQ", f.read(24))
                    _, n_params = CAMERA_MODELS.get(model_id, ("PINHOLE", 4))
                    params = struct.unpack(f"<{n_params}d", f.read(8 * n_params))
                    if model_id in (0, 2, 3):
                        fx = fy = params[0]
                        cx, cy = params[1], params[2]
                    else:
                        fx, fy, cx, cy = params[0], params[1], params[2], params[3]
                    cameras[cam_id] = (width, height, fx, fy, cx, cy)

            with open(img_bin, "rb") as f:
                num_imgs = struct.unpack("<Q", f.read(8))[0]
                for _ in range(num_imgs):
                    binary_header = f.read(64)
                    if len(binary_header) < 64:
                        break
                    data = struct.unpack("<idddddddi", binary_header)
                    qvec = np.array(data[1:5], dtype=np.float32)
                    tvec = np.array(data[5:8], dtype=np.float32)
                    cam_id = data[8]
                    name_bytes = b""
                    while True:
                        ch = f.read(1)
                        if ch == b"\x00" or ch == b"":
                            break
                        name_bytes += ch
                    img_name = name_bytes.decode("utf-8", errors="ignore")
                    num_pts2d = struct.unpack("<Q", f.read(8))[0]
                    f.seek(num_pts2d * 24, 1)
                    if cam_id in cameras:
                        w, h, fx, fy, cx, cy = cameras[cam_id]
                        poses.append({
                            "name": Path(img_name).stem.lower(),
                            "R": qvec2rotmat(qvec),
                            "t": tvec,
                            "w": w, "h": h,
                            "fx": fx, "fy": fy, "cx": cx, "cy": cy,
                        })
            return poses
        except Exception as e:
            print(f"  [WARN] Failed to parse binary COLMAP files in {sparse_dir}: {e}")

    if cam_txt.exists() and img_txt.exists():
        try:
            with open(cam_txt, "r", encoding="utf-8") as f:
                for line in f:
                    if line.startswith("#") or not line.strip():
                        continue
                    parts = line.strip().split()
                    cam_id = int(parts[0])
                    model_name = parts[1]
                    w, h = int(parts[2]), int(parts[3])
                    params = [float(x) for x in parts[4:]]
                    if "SIMPLE" in model_name or model_name == "RADIAL":
                        fx = fy = params[0]
                        cx, cy = params[1], params[2]
                    else:
                        fx, fy, cx, cy = params[0], params[1], params[2], params[3]
                    cameras[cam_id] = (w, h, fx, fy, cx, cy)

            with open(img_txt, "r", encoding="utf-8") as f:
                lines = [l.strip() for l in f if not l.startswith("#") and l.strip()]
                for i in range(0, len(lines), 2):
                    parts = lines[i].split()
                    qvec = np.array([float(x) for x in parts[1:5]], dtype=np.float32)
                    tvec = np.array([float(x) for x in parts[5:8]], dtype=np.float32)
                    cam_id = int(parts[8])
                    img_name = parts[9]
                    if cam_id in cameras:
                        w, h, fx, fy, cx, cy = cameras[cam_id]
                        poses.append({
                            "name": Path(img_name).stem.lower(),
                            "R": qvec2rotmat(qvec),
                            "t": tvec,
                            "w": w, "h": h,
                            "fx": fx, "fy": fy, "cx": cx, "cy": cy,
                        })
            return poses
        except Exception as e:
            print(f"  [WARN] Failed to parse text COLMAP files in {sparse_dir}: {e}")

    return []


def load_cameras_json(json_path: Path) -> List[Dict]:
    """Loads 3DGS cameras.json if present in the model output directory."""
    if not json_path.exists():
        return []
    try:
        with open(json_path, "r", encoding="utf-8") as f:
            cams = json.load(f)
        poses = []
        for c in cams:
            R_c2w = np.array(c["rotation"], dtype=np.float32)
            pos = np.array(c["position"], dtype=np.float32)
            R_w2c = R_c2w.T
            t_w2c = -R_w2c @ pos
            w, h = int(c["width"]), int(c["height"])
            fx, fy = float(c["fx"]), float(c["fy"])
            poses.append({
                "name": Path(c.get("img_name", "")).stem.lower(),
                "R": R_w2c,
                "t": t_w2c,
                "w": w, "h": h,
                "fx": fx, "fy": fy, "cx": w / 2.0, "cy": h / 2.0,
            })
        return poses
    except Exception:
        return []


def compute_multiview_mask_scores(
    xyz: np.ndarray,
    masks_dir: Path,
    search_roots: List[Path],
) -> Optional[np.ndarray]:
    """
    Projects 3D Gaussians into all calibrated camera views and accumulates multi-view
    consensus from the 2D O-SCD change masks.
    """
    if not masks_dir or not masks_dir.exists():
        return None

    mask_files = sorted(list(masks_dir.glob("*.png")) + list(masks_dir.glob("*.jpg")))
    if not mask_files:
        return None

    poses = []
    for root in search_roots:
        if not root or not root.exists():
            continue
        for sparse_cand in [
            root / "inference_scene" / "sparse" / "0",
            root / "reference_scene" / "sparse" / "0",
            root / "sparse" / "0",
        ] + list(root.rglob("sparse/0")):
            if sparse_cand.exists():
                poses = load_colmap_cameras_and_images(sparse_cand)
                if poses:
                    print(f"  -> Loaded {len(poses)} COLMAP camera poses from: {sparse_cand}")
                    break
        if poses:
            break
        for cam_json in root.rglob("cameras.json"):
            poses = load_cameras_json(cam_json)
            if poses:
                print(f"  -> Loaded {len(poses)} camera poses from: {cam_json}")
                break
        if poses:
            break

    if not poses:
        return None

    mask_by_stem = {m.stem.lower(): m for m in mask_files}
    poses_sorted = sorted(poses, key=lambda p: p["name"])

    n_pts = len(xyz)
    visible_counts = np.zeros(n_pts, dtype=np.float32)
    positive_votes = np.zeros(n_pts, dtype=np.float32)

    matched_views = 0
    for idx, pose in enumerate(poses_sorted):
        m_path = mask_by_stem.get(pose["name"])
        if m_path is None and idx < len(mask_files):
            m_path = mask_files[idx]
        if m_path is None:
            continue

        raw_mask = cv2.imread(str(m_path), cv2.IMREAD_GRAYSCALE)
        if raw_mask is None:
            continue

        mh, mw = raw_mask.shape[:2]
        mask = raw_mask.copy()
        mask[: int(mh * 0.22), :] = 0
        mask[int(mh * 0.92) :, :] = 0
        mask[:, : int(mw * 0.08)] = 0
        mask[:, int(mw * 0.92) :] = 0

        R = pose["R"]
        t = pose["t"]
        p_cam = (xyz @ R.T) + t
        z = p_cam[:, 2]

        valid_z = z > 0.05
        if not np.any(valid_z):
            continue

        sx = mw / float(pose["w"])
        sy = mh / float(pose["h"])
        fx = pose["fx"] * sx
        fy = pose["fy"] * sy
        cx = pose["cx"] * sx
        cy = pose["cy"] * sy

        u = np.zeros(n_pts, dtype=np.int32)
        v = np.zeros(n_pts, dtype=np.int32)
        u[valid_z] = np.round((p_cam[valid_z, 0] * fx / z[valid_z]) + cx).astype(np.int32)
        v[valid_z] = np.round((p_cam[valid_z, 1] * fy / z[valid_z]) + cy).astype(np.int32)

        in_bounds = (
            valid_z
            & (u >= int(mw * 0.08))
            & (u < int(mw * 0.92))
            & (v >= int(mh * 0.22))
            & (v < int(mh * 0.92))
        )
        if not np.any(in_bounds):
            continue

        vis_idx = np.where(in_bounds)[0]
        visible_counts[vis_idx] += 1.0
        mask_vals = (mask[v[vis_idx], u[vis_idx]] > 127).astype(np.float32)
        positive_votes[vis_idx] += mask_vals
        matched_views += 1

    if matched_views < 3:
        return None

    valid_vis = visible_counts >= max(5.0, matched_views * 0.20)
    mask_ratio = np.zeros(n_pts, dtype=np.float32)
    mask_ratio[valid_vis] = positive_votes[valid_vis] / visible_counts[valid_vis]
    print(f"  -> Back-projected {matched_views} 2D change masks onto 3D Gaussians.")
    return mask_ratio


# ==============================================================================
# 1. Clean 3D Turbo Change Heatmap Generator (Standard + All-Changes with Ghost)
# ==============================================================================
def filter_small_3d_clusters(
    xyz: np.ndarray,
    active_mask: np.ndarray,
    connect_radius: float,
    min_cluster_size: int = 80,
) -> np.ndarray:
    """
    Finds 3D connected components among active changed Gaussians and removes
    any small isolated clusters/speckles (< min_cluster_size Gaussians).
    """
    active_idx = np.where(active_mask)[0]
    if len(active_idx) == 0:
        return active_mask

    pts = xyz[active_idx]
    tree = scipy.spatial.cKDTree(pts)
    pairs = tree.query_pairs(r=connect_radius, output_type="ndarray")

    if len(pairs) == 0:
        return np.zeros_like(active_mask, dtype=bool)

    n_act = len(active_idx)
    row = np.concatenate([pairs[:, 0], pairs[:, 1]])
    col = np.concatenate([pairs[:, 1], pairs[:, 0]])
    data = np.ones(len(row), dtype=np.int8)
    graph = csr_matrix((data, (row, col)), shape=(n_act, n_act))

    n_components, labels = connected_components(csgraph=graph, directed=False)
    counts = np.bincount(labels, minlength=n_components)

    valid_labels = np.where(counts >= min_cluster_size)[0]
    keep_local = np.isin(labels, valid_labels)

    cleaned_mask = np.zeros_like(active_mask, dtype=bool)
    cleaned_mask[active_idx[keep_local]] = True
    return cleaned_mask


def build_turbo_ply_array(
    base_data: np.ndarray,
    rgb_upd: np.ndarray,
    valid_fg_mask: np.ndarray,
    dist_from_center: np.ndarray,
    roi_radius: float,
    change_scores: np.ndarray,
) -> np.ndarray:
    """Colors a 3DGS structured array using the scientific Turbo colormap."""
    data_turbo = base_data.copy()
    lum = (0.299 * rgb_upd[:, 0] + 0.587 * rgb_upd[:, 1] + 0.114 * rgb_upd[:, 2])[:, np.newaxis]

    turbo_input = np.where(valid_fg_mask, 0.06 + 0.90 * change_scores, 0.04)
    turbo_rgb = apply_turbo_colormap_array(turbo_input)

    bg_blend = 0.82 * turbo_rgb + 0.18 * lum
    w_turbo = np.clip(change_scores * 2.5, 0.0, 1.0)[:, np.newaxis]
    final_turbo_rgb = (1.0 - w_turbo) * bg_blend + w_turbo * turbo_rgb

    data_turbo["f_dc_0"] = ((final_turbo_rgb[:, 0] - 0.5) / SH_C0).astype(np.float32)
    data_turbo["f_dc_1"] = ((final_turbo_rgb[:, 1] - 0.5) / SH_C0).astype(np.float32)
    data_turbo["f_dc_2"] = ((final_turbo_rgb[:, 2] - 0.5) / SH_C0).astype(np.float32)

    zero_higher_order_sh(data_turbo, mask=None)

    data_turbo["opacity"] = np.where(
        dist_from_center > roi_radius * 1.4,
        base_data["opacity"] - 1.2,
        np.where(change_scores > 0.50, np.maximum(base_data["opacity"], 1.5), base_data["opacity"]),
    )
    return data_turbo


def generate_3d_change_heatmap(
    updated_ply_path: Path,
    reference_ply_path: Path,
    out_turbo_ply: Path,
    out_turbo_all_changes_ply: Path,
    masks_dir: Optional[Path] = None,
    search_roots: Optional[List[Path]] = None,
):
    """
    Generates TWO 3D Turbo Change Heatmap Splats:
      1. out_turbo_ply (O-SCD_3D_Change_Heatmap_Turbo.ply):
         Exact clean Turbo heatmap of the updated scene (as before).
      2. out_turbo_all_changes_ply (O-SCD_3D_Change_Heatmap_Turbo_All_Changes.ply):
         Lights up all moved/added objects PLUS the removed objects (the "ghost" of the
         red soda can and old pencil case position) as bright red 3D hotspots.
    """
    print(f"\n[1/3] Reading 3D Gaussian Splats for Turbo Change Heatmaps...")
    print(f"  -> Updated Scene:   {updated_ply_path}")
    print(f"  -> Reference Scene: {reference_ply_path}")

    _, props_upd, data_upd, n_upd = read_ply_data(updated_ply_path)
    _, props_ref, data_ref, n_ref = read_ply_data(reference_ply_path)

    print(f"  -> Loaded {n_upd:,} updated Gaussians and {n_ref:,} reference Gaussians.")

    xyz_upd = np.stack([data_upd["x"], data_upd["y"], data_upd["z"]], axis=1)
    xyz_ref = np.stack([data_ref["x"], data_ref["y"], data_ref["z"]], axis=1)

    rgb_upd = np.stack([
        np.clip(SH_C0 * data_upd["f_dc_0"] + 0.5, 0.0, 1.0),
        np.clip(SH_C0 * data_upd["f_dc_1"] + 0.5, 0.0, 1.0),
        np.clip(SH_C0 * data_upd["f_dc_2"] + 0.5, 0.0, 1.0),
    ], axis=1)

    rgb_ref = np.stack([
        np.clip(SH_C0 * data_ref["f_dc_0"] + 0.5, 0.0, 1.0),
        np.clip(SH_C0 * data_ref["f_dc_1"] + 0.5, 0.0, 1.0),
        np.clip(SH_C0 * data_ref["f_dc_2"] + 0.5, 0.0, 1.0),
    ], axis=1)

    alpha_upd = 1.0 / (1.0 + np.exp(-np.clip(data_upd["opacity"], -20.0, 20.0)))
    alpha_ref = 1.0 / (1.0 + np.exp(-np.clip(data_ref["opacity"], -20.0, 20.0)))

    if all(k in data_upd.dtype.names for k in ("scale_0", "scale_1", "scale_2")):
        scales_upd = np.exp(np.stack([data_upd["scale_0"], data_upd["scale_1"], data_upd["scale_2"]], axis=1))
        max_scale_upd = np.max(scales_upd, axis=1)
        scale_cutoff = np.percentile(max_scale_upd, 78)
    else:
        max_scale_upd = np.zeros(n_upd, dtype=np.float32)
        scale_cutoff = 1e9

    if all(k in data_ref.dtype.names for k in ("scale_0", "scale_1", "scale_2")):
        scales_ref = np.exp(np.stack([data_ref["scale_0"], data_ref["scale_1"], data_ref["scale_2"]], axis=1))
        max_scale_ref = np.max(scales_ref, axis=1)
        scale_cutoff_ref = np.percentile(max_scale_ref, 80)
    else:
        max_scale_ref = np.zeros(n_ref, dtype=np.float32)
        scale_cutoff_ref = 1e9

    # 1. Estimate the tabletop center and ROI radius
    core_ref_mask = alpha_ref > 0.35
    core_ref_xyz = xyz_ref[core_ref_mask] if np.any(core_ref_mask) else xyz_ref
    scene_center = np.median(core_ref_xyz, axis=0)
    dist_from_center = np.linalg.norm(xyz_upd - scene_center, axis=1)
    ref_radii = np.linalg.norm(core_ref_xyz - scene_center, axis=1)
    roi_radius = np.percentile(ref_radii, 52)

    valid_fg_mask = (
        (dist_from_center <= roi_radius)
        & (alpha_upd >= 0.30)
        & (max_scale_upd <= scale_cutoff)
    )

    print("[2/3] Computing Bidirectional 3D Change Detection & Ghost Object Extraction...")
    solid_ref_mask = (
        (alpha_ref >= 0.30)
        & (np.linalg.norm(xyz_ref - scene_center, axis=1) <= roi_radius)
        & (max_scale_ref <= scale_cutoff_ref)
    )
    solid_ref_indices = np.where(solid_ref_mask)[0]
    solid_ref_xyz = xyz_ref[solid_ref_indices] if len(solid_ref_indices) > 0 else xyz_ref
    solid_ref_rgb = rgb_ref[solid_ref_indices] if len(solid_ref_indices) > 0 else rgb_ref

    tree_ref = scipy.spatial.cKDTree(solid_ref_xyz)
    dists_fwd, nn_idx = tree_ref.query(xyz_upd, k=5, workers=-1)
    geo_dist_fwd = np.mean(dists_fwd, axis=1)
    fg_geo = geo_dist_fwd[valid_fg_mask]

    # Fit tabletop plane via SVD on static tabletop points
    static_table_mask = valid_fg_mask & (geo_dist_fwd <= np.percentile(fg_geo, 50))
    if np.sum(static_table_mask) > 100:
        table_pts = xyz_upd[static_table_mask]
        table_centroid = np.mean(table_pts, axis=0)
        _, _, vh = np.linalg.svd(table_pts - table_centroid, full_matrices=False)
        table_normal = vh[2, :]
    else:
        table_centroid = scene_center
        table_normal = np.array([0.0, 0.0, 1.0], dtype=np.float32)

    # --- Signal 1: Forward 3D Geometry (Current Scene Added/Moved Objects) ---
    g_low = np.percentile(fg_geo, 82) if len(fg_geo) > 0 else 0.01
    g_high = np.percentile(fg_geo, 96.5) if len(fg_geo) > 0 else 0.05
    fwd_geo_score = np.clip((geo_dist_fwd - g_low) / max(g_high - g_low, 1e-6), 0.0, 1.0)
    fwd_geo_score[~valid_fg_mask] = 0.0

    # --- Signal 2: Flat Non-Wood Objects on the Table (Ruler & Highlighter) ---
    matched_ref_rgb = np.mean(solid_ref_rgb[nn_idx], axis=1)
    rgb_diff_ref = np.linalg.norm(rgb_upd - matched_ref_rgb, axis=1)

    r_u, g_u, b_u = rgb_upd[:, 0], rgb_upd[:, 1], rgb_upd[:, 2]
    is_wood_tone = (r_u > g_u * 1.06) & (g_u > b_u * 1.12) & (r_u > 0.22) & (r_u < 0.85)

    non_wood_color_score = np.where(
        (~is_wood_tone) & valid_fg_mask & (geo_dist_fwd > np.percentile(fg_geo, 68)),
        np.clip((rgb_diff_ref - 0.18) / 0.25, 0.0, 1.0),
        0.0,
    )

    # --- Signal 3: Reverse 3D KD-Tree (Extract "Ghost" of Removed Red Soda Can & Old Objects) ---
    fg_upd_xyz = xyz_upd[valid_fg_mask]
    removed_footprint_subtle = np.zeros(n_upd, dtype=np.float32)
    removed_footprint_strong = np.zeros(n_upd, dtype=np.float32)
    ghost_ref_indices = np.array([], dtype=np.int64)

    if len(fg_upd_xyz) > 100 and len(solid_ref_xyz) > 100:
        tree_upd = scipy.spatial.cKDTree(fg_upd_xyz)
        dists_rev, nn_upd_idx = tree_upd.query(solid_ref_xyz, k=3, workers=-1)
        rev_dist = np.mean(dists_rev, axis=1)

        # Also check non-wood color in Reference scene (e.g., bright red soda can, black pencil case)
        r_r, g_r, b_r = solid_ref_rgb[:, 0], solid_ref_rgb[:, 1], solid_ref_rgb[:, 2]
        is_ref_wood = (r_r > g_r * 1.06) & (g_r > b_r * 1.12) & (r_r > 0.22) & (r_r < 0.85)
        # Red soda can has strong red dominance (R >> G and R >> B)
        is_red_can_color = (r_r > 0.35) & (r_r > g_r * 1.55) & (r_r > b_r * 1.55)

        rev_thresh = np.percentile(rev_dist, 86)
        removed_cand_mask = (rev_dist > rev_thresh) | (
            (~is_ref_wood | is_red_can_color) & (rev_dist > np.percentile(rev_dist, 72))
        )

        # Filter removed reference Gaussians into clean 3D object clusters (Red Can + Old Pencil Case)
        clean_removed_local = filter_small_3d_clusters(
            xyz=solid_ref_xyz,
            active_mask=removed_cand_mask,
            connect_radius=roi_radius * 0.04,
            min_cluster_size=75,
        )

        if np.any(clean_removed_local):
            ghost_ref_indices = solid_ref_indices[clean_removed_local]
            core_removed_pts = solid_ref_xyz[clean_removed_local]

            # Project removed object footprint onto the Updated tabletop directly underneath
            core_rem_tree = scipy.spatial.cKDTree(core_removed_pts)
            d_to_rem, _ = core_rem_tree.query(xyz_upd, k=1, workers=-1)

            # Subtle footprint for Output 1 (as before)
            footprint_rad_subtle = roi_radius * 0.085
            removed_footprint_subtle = np.where(
                valid_fg_mask & (d_to_rem < footprint_rad_subtle),
                np.clip(1.0 - (d_to_rem / footprint_rad_subtle), 0.0, 1.0) * 0.85,
                0.0,
            )

            # Strong tabletop hotspot for Output 2 (lights up the table beneath the ghost red can)
            # Measure tangent distance along the tabletop plane so the full circular base under
            # the tall soda can lights up solid red on the desk
            vec_to_upd = xyz_upd[:, np.newaxis, :] if len(core_removed_pts) < 10 else None
            # Project both updated points and removed points onto the 2D tabletop plane
            upd_proj = xyz_upd - np.outer((xyz_upd - table_centroid) @ table_normal, table_normal)
            rem_proj = core_removed_pts - np.outer((core_removed_pts - table_centroid) @ table_normal, table_normal)
            proj_tree = scipy.spatial.cKDTree(rem_proj)
            d_plane_rem, _ = proj_tree.query(upd_proj, k=1, workers=-1)

            footprint_rad_strong = roi_radius * 0.065
            removed_footprint_strong = np.where(
                valid_fg_mask & (d_plane_rem < footprint_rad_strong),
                np.clip(1.0 - (d_plane_rem / footprint_rad_strong) ** 2, 0.0, 1.0),
                0.0,
            )

    # Multi-view 2D change mask back-projection (if camera poses exist)
    mask_vote_scores = compute_multiview_mask_scores(xyz_upd, masks_dir, search_roots or [])

    # ==========================================================================
    # OUTPUT 1: Standard Clean Turbo Splat (Same as your previous screenshot)
    # ==========================================================================
    scores_std = np.maximum(fwd_geo_score, np.maximum(non_wood_color_score, removed_footprint_subtle))
    if mask_vote_scores is not None:
        mask_norm = np.clip((mask_vote_scores - 0.42) / 0.35, 0.0, 1.0)
        mask_norm[~valid_fg_mask] = 0.0
        scores_std = np.where(
            mask_norm > 0.05,
            np.maximum(scores_std * 0.8, mask_norm),
            scores_std * 0.5,
        )

    raw_active_std = (scores_std > 0.32) & valid_fg_mask
    clean_active_std = filter_small_3d_clusters(
        xyz=xyz_upd,
        active_mask=raw_active_std,
        connect_radius=roi_radius * 0.035,
        min_cluster_size=90,
    )
    scores_std[~clean_active_std] = 0.0

    clean_idx_std = np.where(clean_active_std)[0]
    fg_indices = np.where(valid_fg_mask)[0]
    if len(clean_idx_std) > 20 and len(fg_indices) > 50:
        clean_tree = scipy.spatial.cKDTree(xyz_upd[clean_idx_std])
        d_to_cluster, _ = clean_tree.query(xyz_upd[fg_indices], k=1, workers=-1)
        halo_radius = roi_radius * 0.045
        halo_score = np.clip(1.0 - (d_to_cluster / halo_radius), 0.0, 1.0) ** 1.4
        cluster_member = np.isin(fg_indices, clean_idx_std)
        final_fg_std = np.where(
            cluster_member,
            np.clip(0.80 + 0.20 * scores_std[fg_indices], 0.82, 1.0),
            halo_score * 0.65,
        )
        scores_std[:] = 0.0
        scores_std[fg_indices] = final_fg_std

    print("[3/3] Synthesizing BOTH Turbo 3DGS PLY files...")
    data_turbo_std = build_turbo_ply_array(
        base_data=data_upd,
        rgb_upd=rgb_upd,
        valid_fg_mask=valid_fg_mask,
        dist_from_center=dist_from_center,
        roi_radius=roi_radius,
        change_scores=scores_std,
    )
    write_ply_data(out_turbo_ply, props_upd, data_turbo_std)
    print(f"[SUCCESS] Exported Output 1 (Standard Turbo):     {out_turbo_ply}")

    # ==========================================================================
    # OUTPUT 2: All-Changes Turbo Splat (Includes 3D Ghost of Red Soda Can!)
    # ==========================================================================
    scores_all = np.maximum(scores_std, removed_footprint_strong)
    raw_active_all = (scores_all > 0.30) & valid_fg_mask
    clean_active_all = filter_small_3d_clusters(
        xyz=xyz_upd,
        active_mask=raw_active_all,
        connect_radius=roi_radius * 0.040,
        min_cluster_size=110,
    )
    scores_all[~clean_active_all] = 0.0

    clean_idx_all = np.where(clean_active_all)[0]
    if len(clean_idx_all) > 20 and len(fg_indices) > 50:
        clean_tree_all = scipy.spatial.cKDTree(xyz_upd[clean_idx_all])
        d_to_cluster_all, _ = clean_tree_all.query(xyz_upd[fg_indices], k=1, workers=-1)
        halo_radius_all = roi_radius * 0.055
        halo_score_all = np.clip(1.0 - (d_to_cluster_all / halo_radius_all), 0.0, 1.0) ** 1.3
        # Solidify the interior of all active clusters & footprints so there are no blue gaps
        solid_core_member = np.isin(fg_indices, clean_idx_all) | (d_to_cluster_all < roi_radius * 0.018)
        final_fg_all = np.where(
            solid_core_member,
            np.clip(0.86 + 0.14 * scores_all[fg_indices], 0.88, 1.0),
            halo_score_all * 0.72,
        )
        scores_all[:] = 0.0
        scores_all[fg_indices] = final_fg_all

    data_turbo_all = build_turbo_ply_array(
        base_data=data_upd,
        rgb_upd=rgb_upd,
        valid_fg_mask=valid_fg_mask,
        dist_from_center=dist_from_center,
        roi_radius=roi_radius,
        change_scores=scores_all,
    )

    # Splicing the 3D "Ghost" Gaussians of the removed Red Soda Can & Old Objects from Reference PLY
    if len(ghost_ref_indices) > 0 and data_ref.dtype == data_upd.dtype:
        ghost_gaussians = data_ref[ghost_ref_indices].copy()
        ghost_xyz = xyz_ref[ghost_ref_indices]

        # Color the 3D ghost Gaussians with a glowing Turbo Red/Orange gradient (0.85 -> 0.98)
        # based on distance from the ghost cluster's outer boundary so it has a 3D thermal core
        ghost_tree = scipy.spatial.cKDTree(ghost_xyz)
        d_ghost_nn, _ = ghost_tree.query(ghost_xyz, k=min(15, len(ghost_xyz)), workers=-1)
        density_score = np.clip(1.0 - (np.mean(d_ghost_nn, axis=1) / (roi_radius * 0.03)), 0.0, 1.0)
        ghost_turbo_vals = 0.78 + 0.20 * density_score
        ghost_rgb = apply_turbo_colormap_array(ghost_turbo_vals)

        ghost_gaussians["f_dc_0"] = ((ghost_rgb[:, 0] - 0.5) / SH_C0).astype(np.float32)
        ghost_gaussians["f_dc_1"] = ((ghost_rgb[:, 1] - 0.5) / SH_C0).astype(np.float32)
        ghost_gaussians["f_dc_2"] = ((ghost_rgb[:, 2] - 0.5) / SH_C0).astype(np.float32)
        zero_higher_order_sh(ghost_gaussians, mask=None)

        # Give the 3D ghost a crisp, slightly translucent thermal glow (log-opacity = 0.85 -> ~70% alpha)
        ghost_gaussians["opacity"] = np.clip(ghost_gaussians["opacity"], 0.65, 1.35)

        data_turbo_all = np.concatenate([data_turbo_all, ghost_gaussians])
        print(f"  -> Spliced {len(ghost_gaussians):,} 3D 'Ghost' Gaussians (Removed Red Can & Old Objects) into All-Changes Splat.")

    write_ply_data(out_turbo_all_changes_ply, props_upd, data_turbo_all)
    print(f"[SUCCESS] Exported Output 2 (All Changes + Ghost): {out_turbo_all_changes_ply}")


# ==============================================================================
# 2. Reconstructed Video Heatmap Generator (With Reference Scene Comparison)
# ==============================================================================
def draw_panel_badge(img: np.ndarray, title: str, accent_bgr: Tuple[int, int, int]) -> np.ndarray:
    """Draws a clean, legible semi-transparent header badge on a video panel."""
    out = img.copy()
    overlay = out.copy()
    box_w = max(290, int(len(title) * 13) + 30)
    cv2.rectangle(overlay, (12, 12), (box_w, 52), (18, 18, 18), -1)
    cv2.addWeighted(overlay, 0.78, out, 0.22, 0, out)
    cv2.rectangle(out, (12, 12), (box_w, 52), accent_bgr, 2)
    cv2.putText(
        out,
        title,
        (24, 39),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )
    return out


def match_frame_triplets(
    ref_dir: Optional[Path],
    inf_dir: Path,
    masks_dir: Path,
) -> List[Tuple[Optional[Path], Path, Path]]:
    """
    Synchronizes (reference_frame, inference_frame, change_mask) across directories
    by matching frame numbers or stems, falling back to sorted index pairing.
    """
    inf_files = sorted(list(inf_dir.glob("*.jpg")) + list(inf_dir.glob("*.png")))
    mask_files = sorted(list(masks_dir.glob("*.png")) + list(masks_dir.glob("*.jpg")))
    ref_files = (
        sorted(list(ref_dir.glob("*.jpg")) + list(ref_dir.glob("*.png")))
        if (ref_dir and ref_dir.exists())
        else []
    )

    if not inf_files or not mask_files:
        return []

    ref_by_stem = {r.stem.lower(): r for r in ref_files}
    mask_by_stem = {m.stem.lower(): m for m in mask_files}

    triplets = []
    for idx, inf_f in enumerate(inf_files):
        stem = inf_f.stem.lower()
        m_path = mask_by_stem.get(stem)
        if m_path is None and idx < len(mask_files):
            m_path = mask_files[idx]
        if m_path is None:
            continue

        r_path = ref_by_stem.get(stem)
        if r_path is None and idx < len(ref_files):
            r_path = ref_files[idx]

        triplets.append((r_path, inf_f, m_path))

    return triplets


def generate_reconstructed_video_heatmap(
    ref_frames_dir: Optional[Path],
    inf_frames_dir: Path,
    masks_dir: Path,
    out_video_overlay: Path,
    out_video_sbs_4panel: Path,
    out_video_grid_2x2: Path,
    out_strip_image: Path,
    fps: float = 15.0,
):
    """
    Renders synchronized MP4 videos & keyframe strips comparing:
      [1. Reference Scene] | [2. Inference Scene] | [3. Thermal Heatmap Overlay] | [4. Binary Change Mask]
    """
    print(f"\n[1/3] Scanning Reference frames, Inference frames, and Change Masks...")
    print(f"  -> Reference Dir: {ref_frames_dir}")
    print(f"  -> Inference Dir: {inf_frames_dir}")
    print(f"  -> Masks Dir:     {masks_dir}")

    triplets = match_frame_triplets(ref_frames_dir, inf_frames_dir, masks_dir)
    if not triplets:
        print(f"[ERROR] Could not pair frames and masks from {inf_frames_dir} and {masks_dir}")
        return

    has_ref = any(t[0] is not None for t in triplets)
    print(f"  -> Paired {len(triplets)} synchronized frames (Reference images found: {'YES' if has_ref else 'NO'}).")

    sample_img = cv2.imread(str(triplets[0][1]))
    h, w = sample_img.shape[:2]

    target_w = 720
    target_h = int(h * target_w / w)
    if target_h % 2 != 0:
        target_h += 1

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    out_video_overlay.parent.mkdir(parents=True, exist_ok=True)

    writer_overlay = cv2.VideoWriter(str(out_video_overlay), fourcc, fps, (target_w, target_h))
    writer_4panel = cv2.VideoWriter(str(out_video_sbs_4panel), fourcc, fps, (target_w * 4, target_h))
    writer_grid = cv2.VideoWriter(str(out_video_grid_2x2), fourcc, fps, (target_w * 2, target_h * 2))

    print(f"[2/3] Rendering 4-panel comparison videos and thermal overlays at {fps} FPS...")
    keyframe_samples = []
    sample_indices = np.linspace(0, len(triplets) - 1, 6, dtype=int)

    for idx, (ref_path, inf_path, mask_path) in enumerate(triplets):
        inf_img = cv2.imread(str(inf_path))
        mask = cv2.imread(str(mask_path), cv2.IMREAD_GRAYSCALE)

        if inf_img is None or mask is None:
            continue

        if ref_path is not None and ref_path.exists():
            ref_img = cv2.imread(str(ref_path))
        else:
            ref_img = np.zeros_like(inf_img)

        if ref_img.shape[:2] != (target_h, target_w):
            ref_img = cv2.resize(ref_img, (target_w, target_h), interpolation=cv2.INTER_AREA)
        if inf_img.shape[:2] != (target_h, target_w):
            inf_img = cv2.resize(inf_img, (target_w, target_h), interpolation=cv2.INTER_AREA)
        if mask.shape[:2] != (target_h, target_w):
            mask = cv2.resize(mask, (target_w, target_h), interpolation=cv2.INTER_NEAREST)

        blur_mask = cv2.GaussianBlur(mask, (15, 15), 0)
        norm_mask = blur_mask.astype(np.float32) / 255.0
        heatmap_color = cv2.applyColorMap(blur_mask, cv2.COLORMAP_TURBO)

        alpha = np.clip(norm_mask * 0.72, 0.0, 0.85)[:, :, np.newaxis]
        overlay = (inf_img.astype(np.float32) * (1.0 - alpha) + heatmap_color.astype(np.float32) * alpha).astype(np.uint8)

        binary_thresh = (mask > 128).astype(np.uint8)
        contours, _ = cv2.findContours(binary_thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        cv2.drawContours(overlay, contours, -1, (0, 255, 255), 2, cv2.LINE_AA)

        overlay_hud = draw_panel_badge(
            overlay,
            f"O-SCD CHANGE HEATMAP | Frame {idx+1:03d}/{len(triplets):03d}",
            (0, 165, 255),
        )
        writer_overlay.write(overlay_hud)

        mask_3ch = cv2.cvtColor(mask, cv2.COLOR_GRAY2BGR)
        cv2.drawContours(mask_3ch, contours, -1, (0, 255, 255), 1, cv2.LINE_AA)

        p1_ref = draw_panel_badge(ref_img, f"1. REFERENCE (Before) [{idx+1:03d}]", (255, 180, 0))
        p2_inf = draw_panel_badge(inf_img, f"2. INFERENCE (After) [{idx+1:03d}]", (0, 220, 0))
        p3_ovl = draw_panel_badge(overlay, "3. CHANGE HEATMAP OVERLAY", (0, 140, 255))
        p4_msk = draw_panel_badge(mask_3ch, "4. BINARY CHANGE MASK", (220, 220, 220))

        frame_4panel = np.hstack([p1_ref, p2_inf, p3_ovl, p4_msk])
        writer_4panel.write(frame_4panel)

        top_row = np.hstack([p1_ref, p2_inf])
        bot_row = np.hstack([p3_ovl, p4_msk])
        frame_grid = np.vstack([top_row, bot_row])
        writer_grid.write(frame_grid)

        if idx in sample_indices:
            keyframe_samples.append(frame_4panel)

    writer_overlay.release()
    writer_4panel.release()
    writer_grid.release()

    print(f"[SUCCESS] Overlay Video exported:          {out_video_overlay}")
    print(f"[SUCCESS] 4-Panel Side-by-Side exported:   {out_video_sbs_4panel}")
    print(f"[SUCCESS] 2x2 Quad Grid Video exported:    {out_video_grid_2x2}")

    if keyframe_samples:
        strip = np.vstack(keyframe_samples)
        cv2.imwrite(str(out_strip_image), strip)
        print(f"[SUCCESS] 4-Column Keyframe Strip saved:   {out_strip_image}")


# ==============================================================================
# Main Orchestrator
# ==============================================================================
def main():
    parser = argparse.ArgumentParser(description="Generate 3D Turbo Splatting Heatmaps and 4-Panel Reference/Inference Video Overlays.")
    parser.add_argument("-b", "--base", type=str, default=None, help="Repository root or Model_Outputs directory.")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = Path(args.base).expanduser().resolve() if args.base else script_dir.parent

    oscd_dir = script_dir / "organized" / "05_Scene_Change_Detection" / "O-SCD" / "Custom_OSCD_Dataset"
    if not oscd_dir.exists():
        oscd_dir = script_dir / "05_Scene_Change_Detection" / "O-SCD" / "Custom_OSCD_Dataset"

    upd_ply = oscd_dir / "O-SCD_Custom_OSCD_Dataset_point_cloud.ply"
    ref_ply = oscd_dir / "checkpoints" / "iteration_30000.ply"

    dataset_candidates = [
        repo_root / "Dataset" / "Custom_OSCD_Dataset",
        repo_root.parent / "Dataset" / "Custom_OSCD_Dataset",
        Path.home() / "UMP" / "Dataset" / "Custom_OSCD_Dataset",
        Path.home() / "UMP_15_outputs" / "Dataset" / "Custom_OSCD_Dataset",
    ]
    dataset_root = next((d for d in dataset_candidates if d.exists()), dataset_candidates[0])

    ref_frames_dir = dataset_root / "reference_scene" / "input"
    inf_frames_dir = dataset_root / "inference_scene" / "input"
    masks_dir = oscd_dir / "change_masks"

    deprecated_hybrid_ply = oscd_dir / "O-SCD_3D_Change_Heatmap_Hybrid.ply"
    if deprecated_hybrid_ply.exists():
        try:
            deprecated_hybrid_ply.unlink()
        except OSError:
            pass

    out_turbo_ply = oscd_dir / "O-SCD_3D_Change_Heatmap_Turbo.ply"
    out_turbo_all_ply = oscd_dir / "O-SCD_3D_Change_Heatmap_Turbo_All_Changes.ply"

    out_video_overlay = oscd_dir / "oscd_change_heatmap_overlay.mp4"
    out_video_3panel_compat = oscd_dir / "oscd_change_comparison_3panel.mp4"
    out_video_4panel = oscd_dir / "oscd_change_comparison_4panel.mp4"
    out_video_grid = oscd_dir / "oscd_change_comparison_2x2_grid.mp4"
    out_strip = oscd_dir / "oscd_change_keyframe_strip.png"

    print("======================================================================")
    print(" O-SCD Change Detection: Dual 3D Turbo Heatmaps & 4-Panel Video")
    print("======================================================================")

    if upd_ply.exists() and ref_ply.exists():
        search_roots = [
            dataset_root,
            oscd_dir,
            script_dir / "raw",
            Path.home() / "UMP_15_outputs",
            repo_root,
        ]
        generate_3d_change_heatmap(
            updated_ply_path=upd_ply,
            reference_ply_path=ref_ply,
            out_turbo_ply=out_turbo_ply,
            out_turbo_all_changes_ply=out_turbo_all_ply,
            masks_dir=masks_dir,
            search_roots=search_roots,
        )
    else:
        print(f"[WARN] 3DGS point cloud checkpoints not found for 3D heatmap:\n  {upd_ply}\n  {ref_ply}")

    if inf_frames_dir.exists() and masks_dir.exists():
        generate_reconstructed_video_heatmap(
            ref_frames_dir=ref_frames_dir,
            inf_frames_dir=inf_frames_dir,
            masks_dir=masks_dir,
            out_video_overlay=out_video_overlay,
            out_video_sbs_4panel=out_video_4panel,
            out_video_grid_2x2=out_video_grid,
            out_strip_image=out_strip,
        )
        if out_video_4panel.exists():
            shutil.copy2(out_video_4panel, out_video_3panel_compat)
    else:
        print(f"[WARN] Inspection frames ({inf_frames_dir}) or change masks ({masks_dir}) not found.")

    print("\n======================================================================")
    print(" Heatmap Synthesis Complete!")
    print(f" 1. Standard Turbo Splat:    {out_turbo_ply}")
    print(f" 2. All-Changes Ghost Splat: {out_turbo_all_ply}")
    print("======================================================================")


if __name__ == "__main__":
    main()