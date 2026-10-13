#!/usr/bin/env python3
"""
collect_metrics.py
==================
Scans all 15 model outputs, parses quantitative benchmark metrics (results.json
and evaluation.json), and generates publication-grade LaTeX, Markdown, CSV, and
JSON comparative tables for thesis assessment and supervisor evaluation.
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import Dict, List, Any, Optional


CATEGORY_ORDER = [
    "01_Physics_Based_3DGS",
    "02_Image_Restoration_3DGS",
    "03_Supplementary_3DGS",
    "04_Surface_Geometry_Mesh",
    "05_Scene_Change_Detection",
]

CATEGORY_LABELS = {
    "01_Physics_Based_3DGS": "Physics-Based Optical Formulations",
    "02_Image_Restoration_3DGS": "Restoration-Guided Photogrammetry",
    "03_Supplementary_3DGS": "Supplementary Underwater 3DGS",
    "04_Surface_Geometry_Mesh": "Surface Mesh Reconstruction (SuGaR)",
    "05_Scene_Change_Detection": "Primitive-Space Scene Change Detection",
}


def parse_results_json(filepath: Path) -> Dict[str, Any]:
    """Extracts PSNR, SSIM, LPIPS, and change detection metrics from a results file."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"[WARN] Failed to read {filepath}: {e}")
        return {}

    metrics = {}

    # Nerfstudio / WaterSplatting format: {"results": {"psnr": ..., "ssim": ..., "lpips": ...}}
    if "results" in data and isinstance(data["results"], dict):
        res = data["results"]
        metrics["psnr"] = res.get("psnr")
        metrics["ssim"] = res.get("ssim")
        metrics["lpips"] = res.get("lpips")
    else:
        # Standard & specialized 3DGS formats (ours_30000, ours_15000, Test, test, updated_scene)
        candidates = [
            "updated_scene",
            "ours_30000", "our_30000",
            "ours_15000", "our_15000",
            "ours_7000", "our_7000",
            "test_!redsquare!", "Test", "test",
            "ours", "our",
        ]
        target_dict = None
        for k in candidates:
            if k in data and isinstance(data[k], dict):
                target_dict = data[k]
                break

        # Fallback: check any dictionary entry containing psnr or ssim keys
        if not target_dict:
            for k, v in data.items():
                if isinstance(v, dict) and any(m in str(k_sub).lower() for k_sub in v.keys() for m in ["psnr", "ssim"]):
                    target_dict = v
                    break

        if not target_dict:
            target_dict = data

        for k, v in target_dict.items():
            k_lower = k.lower().strip()
            if "psnr" in k_lower and isinstance(v, (int, float)):
                metrics["psnr"] = float(v)
            elif "ssim" in k_lower and isinstance(v, (int, float)):
                metrics["ssim"] = float(v)
            elif "lpips" in k_lower and isinstance(v, (int, float)):
                metrics["lpips"] = float(v)

    # OSCD evaluation metrics (Precision, Recall, F1, IoU)
    for k, v in data.items():
        k_lower = k.lower().strip()
        if "iou" in k_lower and isinstance(v, (int, float)):
            metrics["iou"] = float(v)
        elif "f1" in k_lower and isinstance(v, (int, float)):
            metrics["f1"] = float(v)
        elif "precision" in k_lower and isinstance(v, (int, float)):
            metrics["precision"] = float(v)
        elif "recall" in k_lower and isinstance(v, (int, float)):
            metrics["recall"] = float(v)

    return metrics


def find_metric_files(search_dir: Path) -> List[Dict[str, Any]]:
    """Discovers all results.json and evaluation.json files and associates them with models."""
    records = []
    seen_paths = set()

    for path in search_dir.rglob("results.json"):
        if path in seen_paths or ".cache" in str(path):
            continue
        seen_paths.add(path)

        # Infer model, scene, and category from path hierarchy
        path_str = str(path).lower()
        model = "Unknown"
        if "seasplat" in path_str:
            model = "SeaSplat"
        elif "3d-uir" in path_str:
            model = "3D-UIR"
        elif "gaussiansplashing" in path_str or "gaussian_splashing" in path_str:
            model = "Gaussian_Splashing"
        elif "water-splatting" in path_str or "watersplatting" in path_str:
            model = "WaterSplatting"
        elif "rusplatting" in path_str:
            model = "RUSplatting"
        elif "uw-gs" in path_str:
            model = "UW-GS"
        elif "sugar" in path_str:
            model = "SuGaR"
        elif "oscd" in path_str or "o-scd" in path_str:
            model = "O-SCD"

        category = "General"
        if model in ["SeaSplat", "3D-UIR"]:
            category = "01_Physics_Based_3DGS"
        elif model in ["Gaussian_Splashing", "WaterSplatting"]:
            category = "02_Image_Restoration_3DGS"
        elif model in ["RUSplatting", "UW-GS"]:
            category = "03_Supplementary_3DGS"
        elif model == "SuGaR":
            category = "04_Surface_Geometry_Mesh"
        elif model == "O-SCD":
            category = "05_Scene_Change_Detection"

        scene = "Unknown"
        if "kwaj" in path_str:
            scene = "Kwaj"
        elif "tokai" in path_str:
            scene = "Tokai"
        elif "custom_oscd_dataset" in path_str or "oscd" in path_str or "inference_scene" in path_str:
            scene = "Custom_OSCD_Dataset"

        for p in path.parts:
            if p in CATEGORY_ORDER:
                category = p

        metrics = parse_results_json(path)
        records.append({
            "category": category,
            "model": model,
            "scene": scene,
            "file": path,
            "metrics": metrics,
        })

    # Also search for evaluation.json (OSCD change detection scores)
    for path in search_dir.rglob("evaluation.json"):
        if path in seen_paths:
            continue
        seen_paths.add(path)
        eval_metrics = parse_results_json(path)
        # Check if we can merge into an existing OSCD record
        merged = False
        for r in records:
            if "oscd" in r["model"].lower() or "o-scd" in r["model"].lower():
                r["metrics"].update(eval_metrics)
                merged = True
                break
        if not merged:
            records.append({
                "category": "05_Scene_Change_Detection",
                "model": "O-SCD",
                "scene": "Custom_OSCD_Dataset",
                "file": path,
                "metrics": eval_metrics,
            })

    return records


def format_val(val: Optional[float], decimals: int = 4) -> str:
    """Formats float value with precision, or returns a dash if missing."""
    if val is None or not isinstance(val, (int, float)):
        return "--"
    return f"{val:.{decimals}f}"


def build_markdown_table(records: List[Dict[str, Any]]) -> str:
    """Generates an elegant GitHub Markdown comparison table."""
    lines = [
        "# UMP 15-Model Master Quantitative Benchmark Table",
        "",
        "| Architecture Category | Model | Target Scene | PSNR (dB) $\\uparrow$ | SSIM $\\uparrow$ | LPIPS $\\downarrow$ | Notes / Extended Metrics |",
        "|:---|:---|:---|:---:|:---:|:---:|:---|",
    ]

    for cat_key in CATEGORY_ORDER:
        cat_records = [r for r in records if r["category"] == cat_key]
        if not cat_records:
            continue
        cat_title = CATEGORY_LABELS.get(cat_key, cat_key)
        lines.append(f"| **{cat_title}** | | | | | | |")

        for r in sorted(cat_records, key=lambda x: (x["model"], x["scene"])):
            m = r["metrics"]
            psnr_str = format_val(m.get("psnr"), 2)
            ssim_str = format_val(m.get("ssim"), 4)
            lpips_str = format_val(m.get("lpips"), 4)

            notes = []
            if "iou" in m:
                notes.append(f"IoU: {m['iou']:.3f}")
            if "f1" in m:
                notes.append(f"F1: {m['f1']:.3f}")
            notes_str = ", ".join(notes) if notes else "Full 6-stage NVS"

            lines.append(f"| | `{r['model']}` | `{r['scene']}` | **{psnr_str}** | **{ssim_str}** | {lpips_str} | {notes_str} |")

    return "\n".join(lines)


def build_latex_table(records: List[Dict[str, Any]]) -> str:
    """Generates an academic-grade LaTeX table formatted for the QUT Thesis template."""
    lines = [
        "% ----------------------------------------------------------------------",
        "% Master Benchmark Comparison Table for QUT Thesis / Paper",
        "% Requires: \\usepackage{booktabs}, \\usepackage{multirow}",
        "% ----------------------------------------------------------------------",
        "\\begin{table*}[t]",
        "\\centering",
        "\\small",
        "\\caption{Comprehensive Quantitative Evaluation of Underwater 3D Gaussian Splatting and Scene Change Detection Models across Novel View Synthesis Benchmarks.}",
        "\\label{tab:master_ump_benchmarks}",
        "\\begin{tabular}{lllccc}",
        "\\toprule",
        "\\textbf{Research Domain} & \\textbf{Model} & \\textbf{Scene} & \\textbf{PSNR (dB)} $\\uparrow$ & \\textbf{SSIM} $\\uparrow$ & \\textbf{LPIPS} $\\downarrow$ \\\\",
        "\\midrule",
    ]

    for i, cat_key in enumerate(CATEGORY_ORDER):
        cat_records = [r for r in records if r["category"] == cat_key]
        if not cat_records:
            continue

        cat_title = CATEGORY_LABELS.get(cat_key, cat_key)
        lines.append(f"\\multicolumn{{6}}{{l}}{{\\textit{{{cat_title}}}}} \\\\")
        lines.append("\\midrule")

        for r in sorted(cat_records, key=lambda x: (x["model"], x["scene"])):
            m = r["metrics"]
            psnr = format_val(m.get("psnr"), 2)
            ssim = format_val(m.get("ssim"), 4)
            lpips = format_val(m.get("lpips"), 4)
            model_escaped = r["model"].replace("_", "\\_")
            scene_escaped = r["scene"].replace("_", "\\_")
            lines.append(f"  & {model_escaped} & {scene_escaped} & {psnr} & {ssim} & {lpips} \\\\")

        if i < len(CATEGORY_ORDER) - 1:
            lines.append("\\midrule")

    lines.extend([
        "\\bottomrule",
        "\\end{tabular}",
        "\\end{table*}",
        "",
    ])
    return "\n".join(lines)


def build_csv_data(records: List[Dict[str, Any]]) -> str:
    """Generates a standard CSV representation for spreadsheet inspection."""
    header = "Category,Model,Scene,PSNR_dB,SSIM,LPIPS,Extra_Metrics\n"
    rows = [header]
    for r in records:
        m = r["metrics"]
        extra = []
        for k in ["iou", "f1", "precision", "recall"]:
            if k in m:
                extra.append(f"{k}={m[k]}")
        extra_str = ";".join(extra)
        rows.append(f'"{r["category"]}","{r["model"]}","{r["scene"]}",{format_val(m.get("psnr"), 2)},{format_val(m.get("ssim"), 4)},{format_val(m.get("lpips"), 4)},"{extra_str}"\n')
    return "".join(rows)


def main():
    parser = argparse.ArgumentParser(
        description="Aggregate quantitative metrics from all 15 models into LaTeX, Markdown, and CSV."
    )
    parser.add_argument(
        "-i", "--input",
        type=str,
        default=None,
        help="Directory to scan for results.json and evaluation.json (default: checks ./organized, ~/UMP_15_outputs, ./raw)."
    )
    parser.add_argument(
        "-o", "--output-dir",
        type=str,
        default=None,
        help="Directory to save generated comparison tables (default: same as input or ./organized)."
    )

    args = parser.parse_args()
    script_dir = Path(__file__).resolve().parent

    candidates = []
    if args.input:
        candidates.append(Path(args.input).expanduser().resolve())
    else:
        candidates.extend([
            script_dir / "organized",
            Path.home() / "UMP_15_outputs",
            script_dir / "raw",
            script_dir,
            script_dir.parent,
        ])

    search_dir = None
    for cand in candidates:
        if cand.exists() and cand.is_dir():
            if list(cand.rglob("results.json")):
                search_dir = cand
                break

    if not search_dir:
        print("[ERROR] Could not find any results.json files in candidate locations.")
        print("Please specify the directory containing results using `--input /path/to/folder`.")
        sys.exit(1)

    out_dir = Path(args.output_dir) if args.output_dir else (script_dir / "organized")
    out_dir.mkdir(parents=True, exist_ok=True)

    print("======================================================================")
    print(" Aggregating UMP Quantitative Benchmark Metrics")
    print(f" Scanning Directory: {search_dir}")
    print(f" Output Directory:   {out_dir}")
    print("======================================================================")

    records = find_metric_files(search_dir)
    print(f"[INFO] Discovered {len(records)} metric evaluation records.")

    # 1. Write Markdown Table
    md_content = build_markdown_table(records)
    md_path = out_dir / "master_benchmark_table.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(md_content)
    print(f"[SUCCESS] Markdown comparison table: {md_path}")

    # 2. Write LaTeX Table
    tex_content = build_latex_table(records)
    tex_path = out_dir / "master_benchmark_table.tex"
    with open(tex_path, "w", encoding="utf-8") as f:
        f.write(tex_content)
    print(f"[SUCCESS] Academic LaTeX table:      {tex_path}")

    # 3. Write CSV
    csv_content = build_csv_data(records)
    csv_path = out_dir / "master_benchmark_table.csv"
    with open(csv_path, "w", encoding="utf-8") as f:
        f.write(csv_content)
    print(f"[SUCCESS] Spreadsheet CSV export:    {csv_path}")

    # 4. Write JSON
    json_path = out_dir / "master_benchmark_table.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(records, f, indent=2, default=str)
    print(f"[SUCCESS] Structured JSON export:    {json_path}")

    print("======================================================================")
    print(md_content)
    print("======================================================================")


if __name__ == "__main__":
    main()
