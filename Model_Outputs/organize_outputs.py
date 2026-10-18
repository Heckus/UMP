#!/usr/bin/env python3
"""
organize_outputs.py
===================
Intelligent organizer for all UMP 15-model benchmark outputs.
Automatically parses, standardizes, and renames:
  1. Multi-iteration 3D Gaussian point clouds (iteration_7000, 12000, 15000, 30000, splat.ply, updated_scene.ply)
     -> Identifies the FINAL highest-iteration model as the primary point cloud.
     -> Neatly organizes intermediate checkpoints into a 'checkpoints/' subfolder.
  2. Complex SuGaR 90-char textured meshes (sugarfine_3Dgs7000_...gaussperface1.{obj,mtl,png})
     -> Simplifies into clean, human-readable names (e.g. SuGaR_Kwaj_refined_mesh.obj).
     -> Preserves texture (.png) and material (.mtl) associations so MeshLab and Blender load seamlessly.
     -> Resolves inference_scene meshes for OSCD.
  3. WaterSplatting timestamped directories (2026-10-02_221207/export/splat.ply & results.json).
  4. Quantitative metrics (results.json and evaluation.json).
  5. OSCD 2D change detection masks (change_masks/).

Supports symbolic links (default, 0 extra disk space on Ubuntu) and physical copy mode.
"""

import os
import re
import sys
import shutil
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any


MODEL_SPECS = [
    # 01. Physics-Based 3DGS
    {
        "category": "01_Physics_Based_3DGS",
        "model_name": "SeaSplat",
        "scene": "Kwaj",
        "model_aliases": ["seasplat-master", "seasplat"],
        "scene_aliases": ["Kwaj", "kwaj"],
    },
    {
        "category": "01_Physics_Based_3DGS",
        "model_name": "SeaSplat",
        "scene": "Tokai",
        "model_aliases": ["seasplat-master", "seasplat"],
        "scene_aliases": ["Tokai", "tokai"],
    },
    {
        "category": "01_Physics_Based_3DGS",
        "model_name": "3D-UIR",
        "scene": "Kwaj",
        "model_aliases": ["3D-UIR-main", "3d-uir", "3D-UIR"],
        "scene_aliases": ["Kwaj", "kwaj"],
    },
    {
        "category": "01_Physics_Based_3DGS",
        "model_name": "3D-UIR",
        "scene": "Tokai",
        "model_aliases": ["3D-UIR-main", "3d-uir", "3D-UIR"],
        "scene_aliases": ["Tokai", "tokai"],
    },

    # 02. Image Restoration 3DGS
    {
        "category": "02_Image_Restoration_3DGS",
        "model_name": "Gaussian_Splashing",
        "scene": "Kwaj",
        "model_aliases": ["gaussianSplashing-main", "gaussiansplashing", "gaussianSplashing", "Gaussian_Splashing"],
        "scene_aliases": ["Kwaj", "kwaj"],
    },
    {
        "category": "02_Image_Restoration_3DGS",
        "model_name": "Gaussian_Splashing",
        "scene": "Tokai",
        "model_aliases": ["gaussianSplashing-main", "gaussiansplashing", "gaussianSplashing", "Gaussian_Splashing"],
        "scene_aliases": ["Tokai", "tokai"],
    },
    {
        "category": "02_Image_Restoration_3DGS",
        "model_name": "WaterSplatting",
        "scene": "Kwaj",
        "model_aliases": ["water-splatting-main", "watersplatting", "water-splatting", "WaterSplatting"],
        "scene_aliases": ["Kwaj", "kwaj"],
    },
    {
        "category": "02_Image_Restoration_3DGS",
        "model_name": "WaterSplatting",
        "scene": "Tokai",
        "model_aliases": ["water-splatting-main", "watersplatting", "water-splatting", "WaterSplatting"],
        "scene_aliases": ["Tokai", "tokai"],
    },

    # 03. Supplementary 3DGS
    {
        "category": "03_Supplementary_3DGS",
        "model_name": "RUSplatting",
        "scene": "Kwaj",
        "model_aliases": ["RUSplatting-main", "rusplatting", "RUSplatting"],
        "scene_aliases": ["Kwaj", "kwaj"],
    },
    {
        "category": "03_Supplementary_3DGS",
        "model_name": "RUSplatting",
        "scene": "Tokai",
        "model_aliases": ["RUSplatting-main", "rusplatting", "RUSplatting"],
        "scene_aliases": ["Tokai", "tokai"],
    },
    {
        "category": "03_Supplementary_3DGS",
        "model_name": "UW-GS",
        "scene": "Kwaj",
        "model_aliases": ["UW-GS-main", "uw-gs", "UW-GS"],
        "scene_aliases": ["Kwaj", "kwaj"],
    },
    {
        "category": "03_Supplementary_3DGS",
        "model_name": "UW-GS",
        "scene": "Tokai",
        "model_aliases": ["UW-GS-main", "uw-gs", "UW-GS"],
        "scene_aliases": ["Tokai", "tokai"],
    },

    # 04. Surface Geometry Reconstruction (SuGaR)
    {
        "category": "04_Surface_Geometry_Mesh",
        "model_name": "SuGaR",
        "scene": "Kwaj",
        "model_aliases": ["SuGaR-main", "sugar", "SuGaR"],
        "scene_aliases": ["Kwaj", "kwaj"],
    },
    {
        "category": "04_Surface_Geometry_Mesh",
        "model_name": "SuGaR",
        "scene": "Tokai",
        "model_aliases": ["SuGaR-main", "sugar", "SuGaR"],
        "scene_aliases": ["Tokai", "tokai"],
    },
    {
        "category": "04_Surface_Geometry_Mesh",
        "model_name": "SuGaR",
        "scene": "Custom_OSCD_Dataset",
        "model_aliases": ["SuGaR-main", "sugar", "SuGaR"],
        "scene_aliases": ["inference_scene", "Custom_OSCD_Dataset", "oscd"],
    },

    # 05. Scene Change Detection (O-SCD)
    {
        "category": "05_Scene_Change_Detection",
        "model_name": "O-SCD",
        "scene": "Custom_OSCD_Dataset",
        "model_aliases": ["O-SCD-main", "oscd", "O-SCD"],
        "scene_aliases": ["Custom_OSCD_Dataset", "inference_scene", "reference_scene", "oscd"],
    },
]


def link_or_copy(src: Path, dst: Path, mode: str = "symlink"):
    """Safely symlinks or copies src to dst."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.is_symlink() or dst.exists():
        if dst.is_dir() and not dst.is_symlink():
            shutil.rmtree(dst)
        else:
            dst.unlink()

    if mode == "symlink":
        try:
            os.symlink(src.resolve(), dst)
            return
        except OSError:
            pass

    if src.is_dir():
        shutil.copytree(src, dst)
    else:
        shutil.copy2(src, dst)


def match_path(path_str: str, model_aliases: List[str], scene_aliases: List[str]) -> bool:
    """Checks whether a given path string contains both model and scene aliases."""
    has_model = any(m.lower() in path_str.lower() for m in model_aliases)
    has_scene = any(s.lower() in path_str.lower() for s in scene_aliases)
    return has_model and has_scene


def extract_iteration(ply_path: Path) -> int:
    """Extracts integer iteration count from path like 'iteration_15000' or returns 0."""
    if "updated_scene" in ply_path.name:
        return 99999  # Prioritize updated_scene as the final representation for O-SCD
    match = re.search(r"iteration_(\d+)", str(ply_path))
    if match:
        return int(match.group(1))
    if "splat" in ply_path.name:
        return 30000
    return 0


def find_point_clouds(input_dir: Path, spec: Dict) -> Tuple[Optional[Path], List[Path]]:
    """
    Finds all point clouds for a model/scene, picks the highest iteration as final,
    and returns (final_ply, other_iterations).
    """
    model_name = spec["model_name"]
    model_aliases = spec["model_aliases"]
    scene_aliases = spec["scene_aliases"]

    candidates = []
    for ply in input_dir.rglob("*.ply"):
        if ".cache" in str(ply) or "submodules" in str(ply):
            continue
        ply_str = str(ply)

        if model_name == "O-SCD":
            if "updated_scene.ply" in ply.name or ("O-SCD" in ply_str and "point_cloud.ply" in ply.name):
                candidates.append(ply)
        elif model_name == "WaterSplatting":
            if match_path(ply_str, model_aliases, scene_aliases) and ("splat.ply" in ply.name or "point_cloud.ply" in ply.name):
                candidates.append(ply)
        else:
            if match_path(ply_str, model_aliases, scene_aliases) and "point_cloud.ply" in ply.name:
                candidates.append(ply)

    if not candidates:
        return None, []

    # Sort candidates by iteration count descending
    candidates.sort(key=lambda p: (extract_iteration(p), p.stat().st_mtime if p.exists() else 0), reverse=True)
    final_ply = candidates[0]
    other_plys = candidates[1:]
    return final_ply, other_plys


OTHER_UNDERWATER_ALIASES = [
    "seasplat", "3d-uir", "3d_uir", "gaussiansplashing", "gaussian_splashing",
    "watersplatting", "water-splatting", "water_splatting", "rusplatting", "uw-gs", "uw_gs",
]


def find_sugar_meshes(input_dir: Path, spec: Dict) -> List[Path]:
    """Finds all SuGaR refined mesh files (.obj, .mtl, .png) specific to a given model and scene."""
    scene_aliases = spec["scene_aliases"]
    model_aliases = spec["model_aliases"]
    model_name = spec["model_name"]

    matched_assets = []
    for p in input_dir.rglob("*"):
        if not p.is_file() or p.suffix.lower() not in [".obj", ".mtl", ".png", ".jpg"]:
            continue
        p_str = str(p)
        p_lower = p_str.lower().replace("\\", "/")

        # Skip non-mesh PNGs
        if p.suffix.lower() in [".png", ".jpg"] and "sugarfine" not in p.name.lower() and "texture" not in p_lower and "refined_mesh" not in p_lower:
            continue

        if "refined_mesh" not in p_lower and "sugarfine" not in p.name.lower():
            continue

        if model_name == "O-SCD":
            # For OSCD, SuGaR meshes live under inference_scene or oscd or Custom_OSCD_Dataset
            if any(s.lower() in p_lower for s in ["inference_scene", "oscd", "custom_oscd_dataset"]):
                matched_assets.append(p)
        elif model_name == "SuGaR":
            # Standalone SuGaR model: match explicit /sugar/ tag or legacy un-namespaced refined_mesh/<scene>/
            # while excluding paths belonging to a specific underwater model (e.g., /seasplat/, /3d-uir/)
            has_scene = any(s.lower() in p_lower for s in scene_aliases)
            has_other_model = any(f"/{m}/" in p_lower for m in OTHER_UNDERWATER_ALIASES)
            if has_scene and not has_other_model:
                matched_assets.append(p)
        else:
            # Specific underwater 3DGS model (SeaSplat, 3D-UIR, Gaussian_Splashing, WaterSplatting, RUSplatting, UW-GS):
            # MUST match both the model alias AND the scene alias in the path so different models never share a mesh
            has_scene = any(s.lower() in p_lower for s in scene_aliases)
            has_model = any(
                f"/{m.lower()}/" in p_lower or f"_{m.lower()}_" in p_lower or p.name.lower().startswith(f"{m.lower()}_")
                for m in model_aliases
            )
            if has_scene and has_model:
                matched_assets.append(p)

    return matched_assets


def find_results_json(input_dir: Path, spec: Dict) -> Tuple[Optional[Path], Optional[Path]]:
    """Finds results.json and optional evaluation.json for a model/scene."""
    model_name = spec["model_name"]
    model_aliases = spec["model_aliases"]
    scene_aliases = spec["scene_aliases"]

    res_match = None
    eval_match = None

    for j in input_dir.rglob("*.json"):
        j_str = str(j)
        if "results.json" in j.name:
            if model_name == "O-SCD" and any(a in j_str for a in ["O-SCD", "oscd", "Custom_OSCD_Dataset"]):
                res_match = j
            elif match_path(j_str, model_aliases, scene_aliases):
                res_match = j
        elif "evaluation.json" in j.name and model_name == "O-SCD":
            if any(a in j_str for a in ["O-SCD", "oscd", "Custom_OSCD_Dataset"]):
                eval_match = j

    return res_match, eval_match


def find_change_masks(input_dir: Path) -> List[Path]:
    """Finds all rendered change masks for OSCD."""
    masks = []
    for p in input_dir.rglob("*.png"):
        if "change_mask" in str(p):
            masks.append(p)
    return sorted(masks, key=lambda x: x.name)


def main():
    parser = argparse.ArgumentParser(
        description="Intelligent organizer for UMP 15-model outputs, multi-iteration point clouds, and SuGaR meshes."
    )
    parser.add_argument("-i", "--input", type=str, default=None, help="Path to unzipped raw outputs folder.")
    parser.add_argument("-o", "--output", type=str, default="organized", help="Destination organized directory.")
    parser.add_argument("--mode", choices=["symlink", "copy"], default="symlink", help="Symlink or copy files.")

    args = parser.parse_args()
    script_dir = Path(__file__).resolve().parent

    # Locate input folder
    candidates = []
    if args.input:
        candidates.append(Path(args.input).expanduser().resolve())
    else:
        candidates.extend([
            Path.home() / "UMP_15_outputs",
            script_dir / "raw",
            script_dir,
            script_dir.parent,
        ])

    input_dir = None
    for cand in candidates:
        if cand.exists() and cand.is_dir():
            if list(cand.glob("**/results.json")) or (cand / "Codebase").exists() or (cand / "Dataset").exists():
                input_dir = cand
                break

    if not input_dir:
        print("[ERROR] Could not automatically locate the unzipped outputs directory.")
        print("Please specify `--input /path/to/extracted/folder`.")
        sys.exit(1)

    out_dir = Path(args.output)
    if not out_dir.is_absolute():
        out_dir = script_dir / out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    print("======================================================================")
    print(" Intelligent UMP Output Reorganizer & Version Resolver")
    print(f" Source Directory:      {input_dir}")
    print(f" Destination Directory: {out_dir}")
    print(f" Linking Mode:          {args.mode.upper()}")
    print("======================================================================")

    organized_records = []
    total_processed = 0

    for spec in MODEL_SPECS:
        cat = spec["category"]
        model = spec["model_name"]
        scene = spec["scene"]
        target_dir = out_dir / cat / model / scene
        target_dir.mkdir(parents=True, exist_ok=True)

        rec = {
            "category": cat,
            "model": model,
            "scene": scene,
            "target_dir": target_dir,
            "rel_target_dir": str(target_dir.relative_to(out_dir)),
            "ply_final": None,
            "ply_iterations": [],
            "mesh_obj": None,
            "mesh_assets": [],
            "results": None,
            "evaluation": None,
            "masks_count": 0,
        }

        # 1. Point Clouds (Multi-iteration aware)
        final_ply, other_plys = find_point_clouds(input_dir, spec)
        if final_ply:
            iter_num = extract_iteration(final_ply)
            iter_tag = f"iter_{iter_num}" if iter_num > 0 else "final"
            dst_final = target_dir / f"{model}_{scene}_point_cloud_{iter_tag}.ply"
            link_or_copy(final_ply, dst_final, mode=args.mode)
            # Create a clean default alias
            dst_alias = target_dir / f"{model}_{scene}_point_cloud.ply"
            link_or_copy(final_ply, dst_alias, mode=args.mode)
            rec["ply_final"] = dst_alias

            # Organize intermediate iterations into checkpoints/ subfolder
            if other_plys:
                ckpt_dir = target_dir / "checkpoints"
                ckpt_dir.mkdir(parents=True, exist_ok=True)
                for op in other_plys:
                    it_val = extract_iteration(op)
                    dst_it = ckpt_dir / f"iteration_{it_val}.ply"
                    link_or_copy(op, dst_it, mode=args.mode)
                    rec["ply_iterations"].append(dst_it)

        # 2. SuGaR Meshes (handles 90-char names and multi-asset textures)
        mesh_assets = find_sugar_meshes(input_dir, spec)
        obj_files = [m for m in mesh_assets if m.suffix.lower() == ".obj"]
        if obj_files:
            # Sort to prioritize sugarfine meshes (which contain vertex/UV textures) over bare exports
            obj_files.sort(key=lambda x: ("sugarfine" in x.name.lower(), x.stat().st_size if x.exists() else 0), reverse=True)
            primary_obj = obj_files[0]
            mesh_subdir = target_dir / "mesh"
            mesh_subdir.mkdir(parents=True, exist_ok=True)

            # Link clean named files at target_dir root
            dst_clean_obj = target_dir / f"{model}_{scene}_refined_mesh.obj"
            link_or_copy(primary_obj, dst_clean_obj, mode=args.mode)
            rec["mesh_obj"] = dst_clean_obj

            # In mesh/ folder, preserve all original filenames and assets (.mtl, .png)
            # This ensures MeshLab and Blender find the texture maps without broken paths
            for asset in mesh_assets:
                link_or_copy(asset, mesh_subdir / asset.name, mode=args.mode)
                # Also link original asset names in target_dir so relative mtllib / map_Kd lookups succeed
                if asset != primary_obj:
                    link_or_copy(asset, target_dir / asset.name, mode=args.mode)
                if asset.suffix.lower() in [".png", ".jpg"]:
                    link_or_copy(asset, target_dir / f"{model}_{scene}_texture.png", mode=args.mode)
                elif asset.suffix.lower() == ".mtl":
                    link_or_copy(asset, target_dir / f"{model}_{scene}_refined_mesh.mtl", mode=args.mode)
                rec["mesh_assets"].append(asset.name)

            # If no .mtl was generated by SuGaR, but texture .png exists (common in custom/inference scenes),
            # synthesize a clean .mtl companion so 3D viewers automatically display textures
            has_mtl = any(a.suffix.lower() == ".mtl" for a in mesh_assets)
            png_assets = [a for a in mesh_assets if a.suffix.lower() in [".png", ".jpg"]]
            if not has_mtl and png_assets:
                tex_name = png_assets[0].name
                fallback_mtl = target_dir / f"{model}_{scene}_refined_mesh.mtl"
                try:
                    with open(fallback_mtl, "w", encoding="utf-8") as f_mtl:
                        f_mtl.write(f"newmtl material_0\nKa 1.000 1.000 1.000\nKd 1.000 1.000 1.000\nmap_Kd {tex_name}\n")
                    shutil.copy2(fallback_mtl, mesh_subdir / f"{primary_obj.stem}.mtl")
                    rec["mesh_assets"].append(f"{primary_obj.stem}.mtl")
                except Exception:
                    pass

        # 3. Metrics (results.json and evaluation.json)
        res_json, eval_json = find_results_json(input_dir, spec)
        if res_json:
            dst_res = target_dir / "results.json"
            link_or_copy(res_json, dst_res, mode=args.mode)
            rec["results"] = dst_res
        if eval_json:
            dst_eval = target_dir / "evaluation.json"
            link_or_copy(eval_json, dst_eval, mode=args.mode)
            rec["evaluation"] = dst_eval

        # 4. OSCD Change Masks
        if model == "O-SCD":
            mask_files = find_change_masks(input_dir)
            if mask_files:
                mask_dir = target_dir / "change_masks"
                mask_dir.mkdir(parents=True, exist_ok=True)
                for mf in mask_files:
                    link_or_copy(mf, mask_dir / mf.name, mode=args.mode)
                rec["masks_count"] = len(mask_files)

        total_processed += 1
        ply_status = f"[PLY {extract_iteration(final_ply)}]" if rec["ply_final"] else "[      ]"
        other_status = f"(+{len(rec['ply_iterations'])} ckpts)" if rec['ply_iterations'] else ""
        mesh_status = f"[OBJ Mesh]" if rec["mesh_obj"] else "[        ]"
        res_status = f"[METRICS]" if rec["results"] else "[       ]"
        mask_status = f"[{rec['masks_count']} Masks]" if rec['masks_count'] else ""

        print(f" -> [{total_processed:02d}/{len(MODEL_SPECS):02d}] {model:18s} ({scene:18s}) : {ply_status} {other_status:12s} {mesh_status} {res_status} {mask_status}")
        organized_records.append(rec)

    # Copy top-level pipeline logs into organized directory
    logs_dir = out_dir / "00_Pipeline_Execution_Logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    for log_file in input_dir.glob("*.log"):
        link_or_copy(log_file, logs_dir / log_file.name, mode=args.mode)

    # Generate Markdown portfolio guide
    generate_portfolio_index(out_dir, organized_records)

    print("======================================================================")
    print(f" Organization Complete! All 15 models organized in: {out_dir}")
    print("======================================================================")


def generate_portfolio_index(out_dir: Path, records: List[Dict]):
    """Creates a comprehensive Markdown navigation guide for supervisors."""
    index_file = out_dir / "PORTFOLIO_INDEX.md"
    lines = [
        "# UMP 15-Model Research Benchmark Portfolio",
        "",
        "This directory contains the cleaned, standardized outputs from the QUT Engineering Research Thesis:",
        "**'Investigation of Primitive-Space Scene Change Detection in Underwater 3D Gaussian Splatting Models'**.",
        "",
        "---",
        "",
        "## Output Directory Hierarchy",
        "",
    ]

    current_cat = None
    for r in records:
        cat = r["category"]
        if cat != current_cat:
            current_cat = cat
            cat_title = cat.replace("_", " ")
            lines.extend([f"### {cat_title}", ""])

        model = r["model"]
        scene = r["scene"]
        rel_dir = r["rel_target_dir"]

        lines.append(f"- **{model}** (`{scene}`): [`{rel_dir}`]({rel_dir})")
        if r["ply_final"]:
            lines.append(f"  - **Point Cloud (Final):** `{r['ply_final'].name}`")
        if r["ply_iterations"]:
            lines.append(f"  - **Intermediate Checkpoints:** `{len(r['ply_iterations'])} iterations in checkpoints/`")
        if r["mesh_obj"]:
            lines.append(f"  - **Textured Surface Mesh:** `{r['mesh_obj'].name}` (Texture & materials in `mesh/`)")
        if r["results"]:
            lines.append(f"  - **Quantitative Metrics:** `results.json`")
        if r["evaluation"]:
            lines.append(f"  - **Extended Evaluation:** `evaluation.json`")
        if r["masks_count"]:
            lines.append(f"  - **Change Detection Masks:** `{r['masks_count']} images in change_masks/`")
        lines.append("")

    lines.extend([
        "---",
        "",
        "## Quick Inspection Commands",
        "",
        "- **View Metrics Table:** Run `python Model_Outputs/collect_metrics.py`",
        "- **Interactive 3D Visualizer:** Run `python Model_Outputs/view_outputs.py`",
        "- **Mesh Viewing:** `meshlab <path_to_mesh.obj>`",
        "- **Point Cloud Viewing:** Open in [SuperSplat](https://playcanvas.com/supersplat/editor) or CloudCompare.",
        "",
    ])

    with open(index_file, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"[SUCCESS] Portfolio index generated: {index_file}")


if __name__ == "__main__":
    main()
