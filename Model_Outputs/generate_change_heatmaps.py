#!/usr/bin/env python3
"""
generate_change_heatmaps.py
===========================
Transforms binary 2D change masks and 3DGS checkpoints into:
  1. Reconstructed Video Heat Map (Overlay & 3-Panel Side-by-Side MP4 videos).
  2. 3D Viewable Heat Map Gaussian Splats (.ply) renderable in SuperSplat & CloudCompare.
  3. High-resolution publication-quality keyframe comparison figures.

Usage:
    python Model_Outputs/generate_change_heatmaps.py
"""

import os
import sys
import glob
import json
import struct
import argparse
from pathlib import Path
from typing import List, Tuple, Optional, Dict

import cv2
import numpy as np
import scipy.spatial


# SH constant for DC component
SH_C0 = 0.28209479177387814


def colormap_turbo_rgb(val: float) -> Tuple[float, float, float]:
    """Evaluates Turbo colormap polynomial approximation for val in [0, 1]."""
    x = np.clip(val, 0.0, 1.0)
    # Polynomial fit for Google Turbo Colormap
    r = 0.1357 + x * (4.5974 - x * (42.3277 - x * (130.5887 - x * (150.5667 - x * 58.1375))))
    g = 0.0914 + x * (2.1856 + x * (4.8052 - x * (14.0195 - x * (4.2109 - x * 2.7747))))
    b = 0.1067 + x * (12.5732 - x * (80.1471 - x * (222.0251 - x * (240.2297 - x * 88.6302))))
    return (float(np.clip(r, 0.0, 1.0)), float(np.clip(g, 0.0, 1.0)), float(np.clip(b, 0.0, 1.0)))


def read_ply_data(ply_path: Path):
    """
    Parses a binary little endian 3D Gaussian Splatting PLY file.
    Returns (header_text, properties_list, data_dict, vertex_count).
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

        # Read binary body as structured numpy array
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


# ==============================================================================
# 1. 3D Change Heatmap Generator (.ply for SuperSplat & CloudCompare)
# ==============================================================================
def generate_3d_change_heatmap(
    updated_ply_path: Path,
    reference_ply_path: Path,
    out_hybrid_ply: Path,
    out_turbo_ply: Path,
):
    """
    Computes 3D primitive-space change metric between updated and reference 3DGS
    point clouds, and generates photorealistic hybrid & thermal false-color splats.
    """
    print(f"\n[1/3] Reading 3D Gaussian Splats for Primitive-Space Differential...")
    print(f"  -> Updated Scene:   {updated_ply_path}")
    print(f"  -> Reference Scene: {reference_ply_path}")

    _, props_upd, data_upd, n_upd = read_ply_data(updated_ply_path)
    _, _, data_ref, n_ref = read_ply_data(reference_ply_path)

    print(f"  -> Loaded {n_upd:,} updated Gaussians and {n_ref:,} reference Gaussians.")

    xyz_upd = np.stack([data_upd["x"], data_upd["y"], data_upd["z"]], axis=1)
    xyz_ref = np.stack([data_ref["x"], data_ref["y"], data_ref["z"]], axis=1)

    print("[2/3] Constructing spatial KD-Tree to query primitive displacements...")
    tree_ref = scipy.spatial.cKDTree(xyz_ref)
    
    # Query nearest neighbor distance in reference scene for every updated primitive
    # Newly added or modified physical objects will have large nearest-neighbor distances
    distances, _ = tree_ref.query(xyz_upd, k=1, workers=-1)

    # Calculate change confidence scores with robust adaptive percentiles
    p10 = np.percentile(distances, 10)
    p95 = np.percentile(distances, 95)
    spread = max(p95 - p10, 1e-6)

    # Normalized change magnitude in [0, 1]
    change_scores = np.clip((distances - p10) / spread, 0.0, 1.0)
    # Sigmoid contrast enhancement to cleanly separate changed objects from background
    change_confidence = 1.0 / (1.0 + np.exp(-10.0 * (change_scores - 0.5)))

    print(f"  -> Primitive change score stats: min={change_scores.min():.3f}, max={change_scores.max():.3f}, mean={change_scores.mean():.3f}")

    # Generate Model 1: Hybrid Saliency (Photorealistic background + Glowing Heat on changes)
    print(f"[3/3] Synthesizing 3D Gaussian Splatting Color Fields...")
    data_hybrid = data_upd.copy()
    data_turbo = data_upd.copy()

    # Original RGB from 0-th order SH: RGB = SH_C0 * f_dc + 0.5
    f_dc_0 = data_upd["f_dc_0"]
    f_dc_1 = data_upd["f_dc_1"]
    f_dc_2 = data_upd["f_dc_2"]
    orig_r = np.clip(SH_C0 * f_dc_0 + 0.5, 0.0, 1.0)
    orig_g = np.clip(SH_C0 * f_dc_1 + 0.5, 0.0, 1.0)
    orig_b = np.clip(SH_C0 * f_dc_2 + 0.5, 0.0, 1.0)

    # High change color: Intense glowing flame red/orange
    heat_r = 1.00
    heat_g = 0.22
    heat_b = 0.05

    # Interpolate hybrid color
    w = change_confidence[:, np.newaxis]
    rgb_orig = np.stack([orig_r, orig_g, orig_b], axis=1)
    rgb_heat = np.array([heat_r, heat_g, heat_b])
    rgb_hybrid = (1.0 - w) * rgb_orig + w * rgb_heat

    # Map back to DC spherical harmonics: f_dc = (RGB - 0.5) / SH_C0
    data_hybrid["f_dc_0"] = ((rgb_hybrid[:, 0] - 0.5) / SH_C0).astype(np.float32)
    data_hybrid["f_dc_1"] = ((rgb_hybrid[:, 1] - 0.5) / SH_C0).astype(np.float32)
    data_hybrid["f_dc_2"] = ((rgb_hybrid[:, 2] - 0.5) / SH_C0).astype(np.float32)

    # For changed primitives, boost opacity so the change stands out prominently in 3D
    data_hybrid["opacity"] = np.where(change_confidence > 0.4, np.maximum(data_upd["opacity"], 2.0), data_upd["opacity"])

    # Generate Model 2: Full Scientific Turbo Colormap
    turbo_colors = np.array([colormap_turbo_rgb(val) for val in change_scores], dtype=np.float32)
    data_turbo["f_dc_0"] = ((turbo_colors[:, 0] - 0.5) / SH_C0).astype(np.float32)
    data_turbo["f_dc_1"] = ((turbo_colors[:, 1] - 0.5) / SH_C0).astype(np.float32)
    data_turbo["f_dc_2"] = ((turbo_colors[:, 2] - 0.5) / SH_C0).astype(np.float32)

    # Write output PLY files
    write_ply_data(out_hybrid_ply, props_upd, data_hybrid)
    print(f"[SUCCESS] Exported Hybrid 3DGS Heatmap: {out_hybrid_ply}")

    write_ply_data(out_turbo_ply, props_upd, data_turbo)
    print(f"[SUCCESS] Exported Full Turbo 3DGS Heatmap: {out_turbo_ply}")


# ==============================================================================
# 2. Reconstructed Video Heatmap Generator (MP4 & Side-by-Side)
# ==============================================================================
def generate_reconstructed_video_heatmap(
    frames_dir: Path,
    masks_dir: Path,
    out_video_overlay: Path,
    out_video_side_by_side: Path,
    out_strip_image: Path,
    fps: float = 15.0,
):
    """
    Renders synchronized MP4 videos with thermal heat map overlay and
    side-by-side comparison ([Original Inspection] | [Thermal Glow] | [Binary Mask]).
    """
    print(f"\n[1/3] Scanning inspection video frames and change masks...")
    frame_files = sorted(list(frames_dir.glob("*.jpg")) + list(frames_dir.glob("*.png")))
    mask_files = sorted(list(masks_dir.glob("*.png")) + list(masks_dir.glob("*.jpg")))

    if not frame_files:
        print(f"[ERROR] No frame images found in: {frames_dir}")
        return
    if not mask_files:
        print(f"[ERROR] No mask images found in: {masks_dir}")
        return

    # Match frames to masks by stem or index
    pairs = []
    mask_dict = {m.stem.lower(): m for m in mask_files}
    for f in frame_files:
        stem = f.stem.lower()
        if stem in mask_dict:
            pairs.append((f, mask_dict[stem]))

    if not pairs:
        # Fallback to pairing by index
        count = min(len(frame_files), len(mask_files))
        pairs = [(frame_files[i], mask_files[i]) for i in range(count)]

    print(f"  -> Paired {len(pairs)} synchronized camera frames and change masks.")

    # Read first frame to initialize video writers
    sample_img = cv2.imread(str(pairs[0][0]))
    h, w = sample_img.shape[:2]

    # Resize if too large to ensure fast video encoding
    target_w = 960
    target_h = int(h * target_w / w)
    
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    out_video_overlay.parent.mkdir(parents=True, exist_ok=True)

    writer_overlay = cv2.VideoWriter(str(out_video_overlay), fourcc, fps, (target_w, target_h))
    writer_sbs = cv2.VideoWriter(str(out_video_side_by_side), fourcc, fps, (target_w * 3, target_h))

    print(f"[2/3] Rendering thermal heat map overlays and video frames at {fps} FPS...")
    keyframe_samples = []
    sample_indices = np.linspace(0, len(pairs) - 1, 6, dtype=int)

    for idx, (f_path, m_path) in enumerate(pairs):
        img = cv2.imread(str(f_path))
        mask = cv2.imread(str(m_path), cv2.IMREAD_GRAYSCALE)

        if img is None or mask is None:
            continue

        if img.shape[:2] != (target_h, target_w):
            img = cv2.resize(img, (target_w, target_h), interpolation=cv2.INTER_AREA)
        if mask.shape[:2] != (target_h, target_w):
            mask = cv2.resize(mask, (target_w, target_h), interpolation=cv2.INTER_NEAREST)

        # Smooth mask for realistic thermal heat bloom
        blur_mask = cv2.GaussianBlur(mask, (15, 15), 0)
        norm_mask = blur_mask.astype(np.float32) / 255.0

        # Apply vibrant Turbo colormap
        heatmap_color = cv2.applyColorMap(blur_mask, cv2.COLORMAP_TURBO)

        # Alpha blend onto original frame: Frame + 55% Thermal Glow in changed regions
        alpha = (norm_mask * 0.65)[:, :, np.newaxis]
        overlay = (img * (1.0 - alpha) + heatmap_color * alpha).astype(np.uint8)

        # Draw glowing neon boundary contours around detected changes
        contours, _ = cv2.findContours((mask > 128).astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        cv2.drawContours(overlay, contours, -1, (0, 255, 255), 2)  # Glowing cyan/yellow contour

        # Add HUD overlay badges
        cv2.rectangle(overlay, (15, 15), (380, 55), (20, 20, 20), -1)
        cv2.rectangle(overlay, (15, 15), (380, 55), (0, 165, 255), 2)
        cv2.putText(
            overlay,
            f"O-SCD CHANGE HEATMAP | Frame {idx+1:03d}/{len(pairs):03d}",
            (25, 42),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (255, 255, 255),
            2,
            cv2.LINE_AA,
        )

        writer_overlay.write(overlay)

        # 3-Panel Side-by-Side: [Original Video] | [Thermal Heatmap Overlay] | [Binary Mask]
        mask_3ch = cv2.cvtColor(mask, cv2.COLOR_GRAY2BGR)

        # Label panels
        cv2.putText(img, "INSPECTION RGB", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.putText(overlay, "THERMAL HEATMAP OVERLAY", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
        cv2.putText(mask_3ch, "O-SCD CHANGE MASK", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)

        sbs_frame = np.hstack([img, overlay, mask_3ch])
        writer_sbs.write(sbs_frame)

        if idx in sample_indices:
            keyframe_samples.append(sbs_frame)

    writer_overlay.release()
    writer_sbs.release()

    print(f"[SUCCESS] Reconstructed Video Heatmap exported: {out_video_overlay}")
    print(f"[SUCCESS] 3-Panel Comparison Video exported:    {out_video_side_by_side}")

    # Generate Keyframe Comparison Image Strip for Papers/Thesis
    if keyframe_samples:
        strip = np.vstack(keyframe_samples)
        cv2.imwrite(str(out_strip_image), strip)
        print(f"[SUCCESS] Keyframe Comparison Strip exported:   {out_strip_image}")


# ==============================================================================
# Main Orchestrator
# ==============================================================================
def main():
    parser = argparse.ArgumentParser(description="Generate 3D Splatting Heatmaps and Reconstructed Video Overlays.")
    parser.add_argument("-b", "--base", type=str, default=None, help="Repository root or Model_Outputs directory.")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent

    # Target directory paths
    oscd_dir = script_dir / "organized" / "05_Scene_Change_Detection" / "O-SCD" / "Custom_OSCD_Dataset"
    if not oscd_dir.exists():
        oscd_dir = script_dir / "05_Scene_Change_Detection" / "O-SCD" / "Custom_OSCD_Dataset"

    upd_ply = oscd_dir / "O-SCD_Custom_OSCD_Dataset_point_cloud.ply"
    ref_ply = oscd_dir / "checkpoints" / "iteration_30000.ply"

    frames_dir = repo_root / "Dataset" / "Custom_OSCD_Dataset" / "inference_scene" / "input"
    masks_dir = oscd_dir / "change_masks"

    out_hybrid_ply = oscd_dir / "O-SCD_3D_Change_Heatmap_Hybrid.ply"
    out_turbo_ply = oscd_dir / "O-SCD_3D_Change_Heatmap_Turbo.ply"

    out_video_overlay = oscd_dir / "oscd_change_heatmap_overlay.mp4"
    out_video_sbs = oscd_dir / "oscd_change_comparison_3panel.mp4"
    out_strip = oscd_dir / "oscd_change_keyframe_strip.png"

    print("======================================================================")
    print(" O-SCD Change Detection: 3D Gaussian Heatmap & Video Synthesizer")
    print("======================================================================")

    # 1. Generate 3D Gaussian Splatting Heatmaps
    if upd_ply.exists() and ref_ply.exists():
        generate_3d_change_heatmap(upd_ply, ref_ply, out_hybrid_ply, out_turbo_ply)
    else:
        print(f"[WARN] 3DGS point cloud checkpoints not found for 3D heatmap: {upd_ply} or {ref_ply}")

    # 2. Generate Reconstructed Video Heatmap
    if frames_dir.exists() and masks_dir.exists():
        generate_reconstructed_video_heatmap(frames_dir, masks_dir, out_video_overlay, out_video_sbs, out_strip)
    else:
        print(f"[WARN] Inspection frames or change masks not found for video heatmap.")

    print("\n======================================================================")
    print(" Heatmap Synthesis Complete!")
    print(f" Outputs saved in: {oscd_dir}")
    print("======================================================================")


if __name__ == "__main__":
    main()
