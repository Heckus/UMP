#!/usr/bin/env python3
"""
view_outputs.py
===============
Interactive terminal and CLI visualizer for the UMP 15-model outputs on Ubuntu/Linux.
Supports viewing:
  1. 3D Gaussian Splatting Point Clouds (.ply) via SuperSplat WebGL / CloudCompare / MeshLab
  2. Textured Surface Meshes (.obj) via 3DViewer.net WebGL / MeshLab / Blender
  3. OSCD Reconstructed Video Heatmaps (.mp4) via VLC / mpv / system player
  4. OSCD 2D Change Detection Masks (.png) via Matplotlib interactive grid / image viewers
  5. OSCD 4-Column Keyframe Comparison Strips (.png)
  6. Master Quantitative Benchmark Table (PSNR, SSIM, LPIPS) across all models
"""

import os
import sys
import glob
import json
import shutil
import argparse
import subprocess
import webbrowser
from pathlib import Path
from typing import List, Optional, Tuple, Dict, Any


def find_system_app(app_names: List[str]) -> Optional[str]:
    """Checks if any of the given application binaries exist on the system PATH."""
    for name in app_names:
        cmd = shutil.which(name)
        if cmd:
            return cmd
    return None


def open_file_manager(path: Path):
    """Opens the directory containing the file in the desktop file manager."""
    try:
        folder = path if path.is_dir() else path.parent
        subprocess.Popen(
            ["xdg-open", str(folder)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception as e:
        print(f"[WARN] Could not launch file manager: {e}")


def view_point_cloud(ply_path: Path):
    """Launches a viewer for a 3D Gaussian Splatting .ply point cloud."""
    if not ply_path.exists():
        print(f"[ERROR] Point cloud file not found: {ply_path}")
        return

    size_mb = ply_path.stat().st_size / (1024 * 1024)
    print("\n" + "=" * 70)
    print(f" 3D Gaussian Splatting Visualizer: {ply_path.name}")
    print(f" File Size: {size_mb:.1f} MB | Path: {ply_path.resolve()}")
    print("=" * 70)
    print(" * Note: 3DGS models contain millions of volumetric ellipsoids and spherical")
    print("   harmonics. General point cloud tools (CloudCompare/MeshLab) only display")
    print("   raw (x,y,z) coordinate points.")
    print("   To render the photorealistic continuous 3D scene, use SuperSplat WebGL.")
    print("-" * 70)
    print(" [1] Launch SuperSplat WebGL Renderer (Photorealistic 3DGS - Recommended)")
    print(" [2] Open in CloudCompare (Raw Point Cloud & Geometry Inspection)")
    print(" [3] Open in MeshLab (Raw Point Cloud)")
    print(" [4] Open Directory in Desktop File Manager")
    print(" [b] Back to previous menu")
    print("=" * 70)

    choice = input("Select viewing mode [default: 1]: ").strip().lower()

    if choice in ["", "1", "s", "supersplat"]:
        print("\n -> Opening PlayCanvas SuperSplat WebGL viewer in your browser...")
        print("    1. Browser opened: https://playcanvas.com/supersplat/editor")
        print(f"    2. Drag and drop '{ply_path.name}' into the open browser window.")
        print(f"    (Opening directory in your file manager for drag-and-drop...)\n")
        webbrowser.open("https://playcanvas.com/supersplat/editor")
        open_file_manager(ply_path)
    elif choice in ["2", "c", "cloudcompare"]:
        cc_bin = find_system_app(["cloudcompare.CloudCompare", "cloudcompare", "CloudCompare"])
        if cc_bin:
            print(f" -> Launching CloudCompare ({cc_bin}) in background...")
            subprocess.Popen(
                [cc_bin, str(ply_path)],
                cwd=str(ply_path.parent),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        else:
            print("[INFO] CloudCompare binary not found on PATH.")
            print("Install on Ubuntu: sudo snap install cloudcompare")
            print("Install on Arch:   sudo pacman -S cloudcompare")
            open_file_manager(ply_path)
    elif choice in ["3", "m", "meshlab"]:
        ml_bin = find_system_app(["meshlab", "MeshLab"])
        if ml_bin:
            print(f" -> Launching MeshLab ({ml_bin}) in background...")
            subprocess.Popen(
                [ml_bin, str(ply_path)],
                cwd=str(ply_path.parent),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        else:
            print("[INFO] MeshLab binary not found on PATH.")
            print("Install on Ubuntu: sudo apt install meshlab (or sudo snap install meshlab)")
            print("Install on Arch:   sudo pacman -S meshlab")
            open_file_manager(ply_path)
    elif choice == "4":
        open_file_manager(ply_path)


def view_mesh(obj_path: Path):
    """Launches a viewer for a textured 3D .obj surface mesh."""
    if not obj_path.exists():
        print(f"[ERROR] Mesh file not found: {obj_path}")
        return

    size_mb = obj_path.stat().st_size / (1024 * 1024)
    # Discover companion material (.mtl) and texture (.png) in the same directory or mesh/
    parent_dir = obj_path.parent
    mesh_dir = parent_dir / "mesh"
    mtl_files = list(parent_dir.glob("*.mtl")) + (list(mesh_dir.glob("*.mtl")) if mesh_dir.is_dir() else [])
    png_files = [p for p in parent_dir.glob("*.png") if "strip" not in p.name.lower()]
    if mesh_dir.is_dir():
        png_files += [p for p in mesh_dir.glob("*.png") if "strip" not in p.name.lower()]

    print("\n" + "=" * 70)
    print(f" 3D Textured Surface Mesh Visualizer: {obj_path.name}")
    print(f" File Size: {size_mb:.1f} MB | Path: {obj_path.resolve()}")
    if mtl_files:
        print(f" Material:  {mtl_files[0].name}")
    if png_files:
        print(f" Texture:   {png_files[0].name} ({png_files[0].stat().st_size / (1024*1024):.1f} MB)")
    print("=" * 70)
    print(" [1] Launch WebGL 3D Viewer (Online - Recommended for quick inspection)")
    print(" [2] Open in MeshLab (Native Desktop)")
    print(" [3] Open in Blender (Full 3D DCC Suite)")
    print(" [4] Open Containing Directory in Desktop File Manager")
    print(" [b] Back to previous menu")
    print("=" * 70)

    choice = input("Select viewing mode [default: 1]: ").strip().lower()

    if choice in ["", "1", "w", "web"]:
        print("\n -> Opening 3DViewer.net in your browser...")
        print("    1. Browser opened: https://3dviewer.net/")
        print(f"    2. Drag and drop '{obj_path.name}' along with its .mtl and .png into the viewer.")
        print(f"    (Opening directory in your file manager for drag-and-drop...)\n")
        webbrowser.open("https://3dviewer.net/")
        open_file_manager(obj_path)
    elif choice in ["2", "m", "meshlab"]:
        ml_bin = find_system_app(["meshlab", "MeshLab"])
        if ml_bin:
            print(f" -> Launching MeshLab ({ml_bin}) in background...")
            subprocess.Popen(
                [ml_bin, str(obj_path)],
                cwd=str(obj_path.parent),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        else:
            print("[INFO] MeshLab binary not found on PATH.")
            print("Install on Ubuntu: sudo apt install meshlab")
            print("Install on Arch:   sudo pacman -S meshlab")
            open_file_manager(obj_path)
    elif choice in ["3", "b", "blender"]:
        blender_bin = find_system_app(["blender", "Blender"])
        if blender_bin:
            print(f" -> Launching Blender ({blender_bin}) in background...")
            subprocess.Popen(
                [blender_bin, str(obj_path)],
                cwd=str(obj_path.parent),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        else:
            print("[INFO] Blender binary not found on PATH.")
            print("Install on Ubuntu: sudo snap install blender --classic")
            print("Install on Arch:   sudo pacman -S blender")
            open_file_manager(obj_path)
    elif choice == "4":
        open_file_manager(obj_path)


def view_change_masks(mask_dir: Path):
    """Displays OSCD 2D change detection masks in an interactive grid or system image viewer."""
    if not mask_dir.exists():
        print(f"[ERROR] Change mask directory not found: {mask_dir}")
        return

    mask_files = sorted(list(mask_dir.glob("*.png")) + list(mask_dir.glob("*.jpg")))
    if not mask_files:
        print(f"[WARN] No rendered masks found in: {mask_dir}")
        return

    print(f"\n[INFO] Viewing {len(mask_files)} OSCD Change Detection Masks from: {mask_dir}")

    # 1. Try Matplotlib interactive grid
    try:
        import matplotlib.pyplot as plt
        import matplotlib.image as mpimg

        n_show = min(12, len(mask_files))
        cols = 4
        rows = (n_show + cols - 1) // cols

        fig, axes = plt.subplots(rows, cols, figsize=(16, 4 * rows))
        fig.suptitle(f"O-SCD Change Detection Masks ({n_show} of {len(mask_files)} frames)", fontsize=16)
        axes = axes.flatten() if hasattr(axes, "flatten") else [axes]

        for i in range(len(axes)):
            if i < n_show:
                img = mpimg.imread(str(mask_files[i]))
                axes[i].imshow(img, cmap="gray" if img.ndim == 2 else None)
                axes[i].set_title(mask_files[i].stem, fontsize=10)
                axes[i].axis("off")
            else:
                axes[i].axis("off")

        plt.tight_layout()
        print(" -> Displaying Matplotlib change mask grid (close window to return)...")
        plt.show()
        return
    except ImportError:
        pass

    # 2. Check for native Linux image viewers (eog, feh, viewnior, xdg-open)
    img_bin = find_system_app(["eog", "feh", "viewnior", "gwenview", "xdg-open"])
    if img_bin:
        print(f" -> Launching system image viewer ({img_bin}) in background...")
        subprocess.Popen(
            [img_bin, str(mask_files[0])],
            cwd=str(mask_dir),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    else:
        open_file_manager(mask_dir)


def view_strip(strip_path: Path):
    """Displays the publication-quality 4-column keyframe comparison strip."""
    if not strip_path.exists():
        print(f"[ERROR] Keyframe strip file not found: {strip_path}")
        return

    print(f"\n[INFO] Opening Keyframe Strip: {strip_path.name} ({strip_path.stat().st_size / (1024*1024):.1f} MB)")
    try:
        import matplotlib.pyplot as plt
        import matplotlib.image as mpimg

        img = mpimg.imread(str(strip_path))
        fig, ax = plt.subplots(figsize=(16, 10))
        ax.imshow(img)
        ax.set_title("O-SCD 4-Column Synchronized Keyframe Strip", fontsize=14)
        ax.axis("off")
        plt.tight_layout()
        print(" -> Displaying Keyframe Strip via Matplotlib (close window to return)...")
        plt.show()
        return
    except ImportError:
        pass

    img_bin = find_system_app(["eog", "feh", "viewnior", "gwenview", "xdg-open"])
    if img_bin:
        print(f" -> Launching image viewer ({img_bin})...")
        subprocess.Popen(
            [img_bin, str(strip_path)],
            cwd=str(strip_path.parent),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    else:
        open_file_manager(strip_path)


def view_video(video_path: Path):
    """Launches a native media player for reconstructed MP4 heatmaps."""
    if not video_path.exists():
        print(f"[ERROR] Video file not found: {video_path}")
        return

    size_mb = video_path.stat().st_size / (1024 * 1024)
    print(f"\n[INFO] Opening Reconstructed Video Heatmap: {video_path.name} ({size_mb:.1f} MB)")
    player_bin = find_system_app(["vlc", "mpv", "totem", "celluloid", "parole", "xdg-open"])
    if player_bin:
        print(f" -> Launching media player ({player_bin}) in background...")
        subprocess.Popen(
            [player_bin, str(video_path)],
            cwd=str(video_path.parent),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    else:
        open_file_manager(video_path)


def scan_available_models(base_dir: Path) -> Tuple[List[Dict[str, Any]], Path]:
    """
    Discovers all models, scenes, and available output files.
    Prioritizes the structured 'organized' hierarchy if present.
    Returns (models_found, resolved_root).
    """
    resolved_root = base_dir

    # If base_dir points to Model_Outputs root and organized/ exists, focus on organized/
    if (base_dir / "organized").is_dir():
        resolved_root = base_dir / "organized"

    models_found = []

    # 1. First attempt: check for the 5 standard thesis categories
    category_dirs = sorted([d for d in resolved_root.iterdir() if d.is_dir() and d.name[:2].isdigit()])
    if category_dirs:
        for cat_dir in category_dirs:
            cat_name = cat_dir.name
            for model_dir in sorted([m for m in cat_dir.iterdir() if m.is_dir()]):
                model_name = model_dir.name
                for scene_dir in sorted([s for s in model_dir.iterdir() if s.is_dir()]):
                    if scene_dir.name in ["mesh", "checkpoints", "change_masks", "raw"]:
                        continue
                    scene_name = scene_dir.name

                    # 1. Point Cloud (.ply)
                    canonical_ply = scene_dir / f"{model_name}_{scene_name}_point_cloud.ply"
                    if canonical_ply.exists():
                        ply = canonical_ply
                    else:
                        ply_cands = [p for p in scene_dir.glob("*.ply") if "heatmap" not in p.name.lower()]
                        ply = ply_cands[0] if ply_cands else None

                    # Checkpoints
                    ckpt_dir = scene_dir / "checkpoints"
                    checkpoints = sorted(list(ckpt_dir.glob("*.ply"))) if ckpt_dir.is_dir() else []

                    # 2. Textured Surface Mesh (.obj)
                    canonical_obj = scene_dir / f"{model_name}_{scene_name}_refined_mesh.obj"
                    if canonical_obj.exists():
                        obj = canonical_obj
                    else:
                        obj_cands = list(scene_dir.glob("*.obj"))
                        obj = obj_cands[0] if obj_cands else None

                    # 3. Quantitative Metrics (results.json & evaluation.json)
                    res_file = scene_dir / "results.json"
                    res = res_file if res_file.exists() else None
                    eval_file = scene_dir / "evaluation.json"
                    eval_json = eval_file if eval_file.exists() else None

                    # 4. Change Detection Masks
                    mask_dir = scene_dir / "change_masks"
                    masks = mask_dir if (mask_dir.is_dir() and list(mask_dir.glob("*.png"))) else None

                    # 5. Specialized O-SCD Heatmaps & Videos
                    turbo_ply = scene_dir / "O-SCD_3D_Change_Heatmap_Turbo.ply"
                    if not turbo_ply.exists():
                        t_cands = list(scene_dir.glob("*Turbo.ply"))
                        turbo_ply = t_cands[0] if t_cands else None

                    all_changes_ply = scene_dir / "O-SCD_3D_Change_Heatmap_Turbo_All_Changes.ply"
                    if not all_changes_ply.exists():
                        a_cands = list(scene_dir.glob("*All_Changes.ply"))
                        all_changes_ply = a_cands[0] if a_cands else None

                    videos = sorted(list(scene_dir.glob("*.mp4")))
                    strip = scene_dir / "oscd_change_keyframe_strip.png"
                    if not strip.exists():
                        strip = None

                    models_found.append({
                        "category": cat_name,
                        "model": model_name,
                        "scene": scene_name,
                        "path": scene_dir,
                        "ply": ply,
                        "checkpoints": checkpoints,
                        "obj": obj,
                        "results": res,
                        "evaluation": eval_json,
                        "masks": masks,
                        "heatmap_ply": turbo_ply,
                        "heatmap_all_ply": all_changes_ply,
                        "videos": videos,
                        "strip": strip,
                    })

    # 2. Fallback: unconstrained traversal if no organized categories found
    if not models_found:
        valid_scenes = ["Kwaj", "Tokai", "Custom_OSCD_Dataset"]
        for d in resolved_root.rglob("*"):
            if not d.is_dir():
                continue
            if d.name in valid_scenes:
                scene_name = d.name
                parent_name = d.parent.name
                # Skip raw / intermediate build directories
                if parent_name in ["output", "outputs", "refined_mesh", "Dataset", "Submerged3D", "checkpoints", "mesh"]:
                    continue

                ply_files = [p for p in d.glob("*.ply") if "heatmap" not in p.name.lower()]
                obj_files = list(d.glob("*.obj"))
                res_files = list(d.glob("results.json"))

                ply = ply_files[0] if ply_files else None
                obj = obj_files[0] if obj_files else None
                res = res_files[0] if res_files else None
                masks = d / "change_masks" if (d / "change_masks").is_dir() else None

                if ply or obj or res or masks:
                    models_found.append({
                        "category": "General_Outputs",
                        "model": parent_name,
                        "scene": scene_name,
                        "path": d,
                        "ply": ply,
                        "checkpoints": [],
                        "obj": obj,
                        "results": res,
                        "evaluation": None,
                        "masks": masks,
                        "heatmap_ply": None,
                        "heatmap_all_ply": None,
                        "videos": list(d.glob("*.mp4")),
                        "strip": None,
                    })

    return models_found, resolved_root


def show_master_table(base_dir: Path):
    """Displays the master quantitative benchmark table, generating it if needed."""
    # Look for master_benchmark_table.md in base_dir, organized/, or parent
    candidates = [
        base_dir / "master_benchmark_table.md",
        base_dir / "organized" / "master_benchmark_table.md",
        Path(__file__).resolve().parent / "organized" / "master_benchmark_table.md",
        Path(__file__).resolve().parent / "master_benchmark_table.md",
    ]
    table_path = next((c for c in candidates if c.exists()), None)

    if not table_path:
        print("[INFO] Benchmark table not generated yet. Running `collect_metrics.py`...")
        script_dir = Path(__file__).resolve().parent
        collect_py = script_dir / "collect_metrics.py"
        if collect_py.exists():
            subprocess.run([sys.executable, str(collect_py)])
            table_path = next((c for c in candidates if c.exists()), None)

    if table_path and table_path.exists():
        with open(table_path, "r", encoding="utf-8") as f:
            print("\n" + f.read())
    else:
        print("[WARN] Could not generate or locate master_benchmark_table.md.")


def interactive_menu(base_dir: Path):
    """Presents a clean, structured interactive menu in the terminal."""
    script_dir = Path(__file__).resolve().parent

    while True:
        models, active_root = scan_available_models(base_dir)

        print("\n" + "=" * 70)
        print(" UMP 15-Model Evaluation & 3D Visualization Terminal")
        print(f" Workspace Root: {active_root}")
        print("=" * 70)

        current_cat = None
        for idx, m in enumerate(models, 1):
            if m["category"] != current_cat:
                current_cat = m["category"]
                cat_header = current_cat.replace("_", " ")
                print(f"\n--- {cat_header} ---")

            ply_badge = "[PLY]" if m["ply"] else "     "
            obj_badge = "[OBJ]" if m["obj"] else "     "
            res_badge = "[METRICS]" if m["results"] else "         "
            mask_badge = "[MASKS]" if m["masks"] else "       "
            heat_badge = "[HEATMAP 3D/MP4]" if (m.get("heatmap_ply") or m.get("videos")) else ""
            print(f" [{idx:02d}] {m['model']:20s} ({m['scene']:18s}) {ply_badge} {obj_badge} {res_badge} {mask_badge} {heat_badge}")

        print("\n" + "-" * 70)
        print(" [V] Play O-SCD Reconstructed Video Heatmap (.mp4)")
        print(" [H] View O-SCD 3D Turbo Change Heatmap Splats in SuperSplat (.ply)")
        print(" [M] View O-SCD Change Detection Masks Gallery (2D)")
        print(" [S] View O-SCD 4-Column Keyframe Comparison Strip (.png)")
        print(" [T] View Master Quantitative Benchmark Metrics Table")
        print(" [O] Open Organized Workspace in Ubuntu File Manager")
        print(" [Q] Quit")
        print("=" * 70)

        choice = input("Select an option: ").strip().lower()

        if choice in ["q", "exit", "quit"]:
            print("Exiting viewer. Have a great day!")
            break
        elif choice == "v":
            # Search for available video heatmaps
            oscd_models = [m for m in models if "o-scd" in m["model"].lower() or "oscd" in m["model"].lower()]
            videos = oscd_models[0]["videos"] if oscd_models and oscd_models[0]["videos"] else list(active_root.rglob("*.mp4"))

            if not videos:
                print("[INFO] Reconstructed video heatmap not generated yet.")
                print("Running `python Model_Outputs/generate_change_heatmaps.py`...")
                gen_py = script_dir / "generate_change_heatmaps.py"
                if gen_py.exists():
                    subprocess.run([sys.executable, str(gen_py)])
                    videos = list(active_root.rglob("*.mp4"))

            if videos:
                if len(videos) == 1:
                    view_video(videos[0])
                else:
                    print("\nSelect video to play:")
                    for v_idx, v_path in enumerate(videos, 1):
                        print(f"  [{v_idx}] {v_path.name}")
                    v_choice = input(f"Choice [1-{len(videos)}, default 1]: ").strip()
                    sel_v = int(v_choice) - 1 if v_choice.isdigit() and 1 <= int(v_choice) <= len(videos) else 0
                    view_video(videos[sel_v])
            else:
                print("[WARN] No video files could be generated or found.")
        elif choice == "h":
            oscd_models = [m for m in models if "o-scd" in m["model"].lower() or "oscd" in m["model"].lower()]
            heat_ply = oscd_models[0].get("heatmap_ply") if oscd_models else None
            heat_all_ply = oscd_models[0].get("heatmap_all_ply") if oscd_models else None

            if not heat_ply and not heat_all_ply:
                print("[INFO] 3D change heatmaps not generated yet.")
                print("Running `python Model_Outputs/generate_change_heatmaps.py`...")
                gen_py = script_dir / "generate_change_heatmaps.py"
                if gen_py.exists():
                    subprocess.run([sys.executable, str(gen_py)])
                    models, _ = scan_available_models(base_dir)
                    oscd_models = [m for m in models if "o-scd" in m["model"].lower() or "oscd" in m["model"].lower()]
                    heat_ply = oscd_models[0].get("heatmap_ply") if oscd_models else None
                    heat_all_ply = oscd_models[0].get("heatmap_all_ply") if oscd_models else None

            if heat_ply or heat_all_ply:
                print("\nSelect 3D Heatmap Splat to view in SuperSplat:")
                cands = []
                if heat_ply:
                    cands.append(("Standard Turbo Splat (Updated Scene with Highlights)", heat_ply))
                if heat_all_ply:
                    cands.append(("All-Changes Turbo Splat (+ 3D Ghost of Removed Can)", heat_all_ply))

                for c_idx, (c_label, _) in enumerate(cands, 1):
                    print(f"  [{c_idx}] {c_label}")
                h_choice = input(f"Choice [1-{len(cands)}, default 1]: ").strip()
                sel_h = int(h_choice) - 1 if h_choice.isdigit() and 1 <= int(h_choice) <= len(cands) else 0
                view_point_cloud(cands[sel_h][1])
            else:
                print("[WARN] No 3D change heatmap splats available.")
        elif choice == "m":
            oscd_models = [m for m in models if "o-scd" in m["model"].lower() or "oscd" in m["model"].lower()]
            mask_dir = oscd_models[0]["masks"] if oscd_models and oscd_models[0]["masks"] else None
            if not mask_dir:
                cands = [d for d in active_root.rglob("change_masks") if d.is_dir()]
                mask_dir = cands[0] if cands else None

            if mask_dir:
                view_change_masks(mask_dir)
            else:
                print("[WARN] No OSCD change mask directory discovered.")
        elif choice == "s":
            oscd_models = [m for m in models if "o-scd" in m["model"].lower() or "oscd" in m["model"].lower()]
            strip = oscd_models[0].get("strip") if oscd_models else None
            if not strip:
                cands = list(active_root.rglob("*keyframe_strip.png"))
                strip = cands[0] if cands else None
            if strip and strip.exists():
                view_strip(strip)
            else:
                print("[INFO] Keyframe strip not generated yet. Running `generate_change_heatmaps.py`...")
                gen_py = script_dir / "generate_change_heatmaps.py"
                if gen_py.exists():
                    subprocess.run([sys.executable, str(gen_py)])
                    cands = list(active_root.rglob("*keyframe_strip.png"))
                    if cands:
                        view_strip(cands[0])
        elif choice == "t":
            show_master_table(active_root)
        elif choice == "o":
            open_file_manager(active_root)
        elif choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(models):
                selected = models[idx]
                print(f"\n======================================================================")
                print(f" Selected: {selected['model']} ({selected['scene']})")
                print(f" Category: {selected['category']}")
                print(f" Location: {selected['path']}")
                print("======================================================================")
                print("What would you like to view?")
                options = []
                if selected["ply"]:
                    options.append(("p", f"3D Gaussian Splat (.ply) -> {selected['ply'].name}", "ply", selected["ply"]))
                if selected.get("checkpoints"):
                    options.append(("c", f"Intermediate Checkpoints ({len(selected['checkpoints'])} iterations)", "ckpts", selected["checkpoints"]))
                if selected.get("heatmap_ply"):
                    options.append(("h", f"3D Turbo Change Heatmap Splat (.ply)", "ply", selected["heatmap_ply"]))
                if selected.get("heatmap_all_ply"):
                    options.append(("a", f"3D All-Changes + Ghost Heatmap Splat (.ply)", "ply", selected["heatmap_all_ply"]))
                if selected.get("videos"):
                    for v_idx, v_path in enumerate(selected["videos"]):
                        options.append((f"v{v_idx+1}" if len(selected["videos"]) > 1 else "v", f"Video: {v_path.name}", "video", v_path))
                if selected.get("strip"):
                    options.append(("s", f"Keyframe Comparison Strip (.png)", "strip", selected["strip"]))
                if selected["obj"]:
                    options.append(("m", f"3D Textured Surface Mesh (.obj) -> {selected['obj'].name}", "obj", selected["obj"]))
                if selected["masks"]:
                    options.append(("k", f"Change Detection Masks Gallery (2D)", "masks", selected["masks"]))
                if selected["results"]:
                    options.append(("r", f"Quantitative Metrics (results.json)", "json", selected["results"]))
                if selected.get("evaluation"):
                    options.append(("e", f"Extended Evaluation Metrics (evaluation.json)", "json", selected["evaluation"]))

                # Option to generate heatmaps if O-SCD
                if any(m_kw in selected["model"].lower() for m_kw in ["oscd", "o-scd"]):
                    options.append(("g", "Generate / Recompute 3D & Video Heatmaps", "gen", selected["path"]))

                options.append(("d", "Open Model Directory in Desktop File Manager", "folder", selected["path"]))

                for opt_key, opt_desc, _, _ in options:
                    print(f"  [{opt_key}] {opt_desc}")
                print("  [b] Back to main menu")

                sub_choice = input("Choice: ").strip().lower()
                for opt_key, _, action_type, target_path in options:
                    if sub_choice == opt_key:
                        if action_type == "ply":
                            view_point_cloud(target_path)
                        elif action_type == "obj":
                            view_mesh(target_path)
                        elif action_type == "video":
                            view_video(target_path)
                        elif action_type == "strip":
                            view_strip(target_path)
                        elif action_type == "masks":
                            view_change_masks(target_path)
                        elif action_type == "folder":
                            open_file_manager(target_path)
                        elif action_type == "ckpts":
                            print(f"\nCheckpoints for {selected['model']} ({selected['scene']}):")
                            for ck_idx, ck_file in enumerate(target_path, 1):
                                print(f"  [{ck_idx}] {ck_file.name} ({ck_file.stat().st_size / (1024*1024):.1f} MB)")
                            ck_choice = input(f"Select checkpoint to view [1-{len(target_path)}, b to back]: ").strip()
                            if ck_choice.isdigit() and 1 <= int(ck_choice) <= len(target_path):
                                view_point_cloud(target_path[int(ck_choice) - 1])
                        elif action_type == "gen":
                            gen_script = script_dir / "generate_change_heatmaps.py"
                            subprocess.run([sys.executable, str(gen_script)])
                        elif action_type == "json":
                            with open(target_path, "r", encoding="utf-8") as f:
                                print(f"\n--- {target_path} ---\n" + f.read())
                        break
            else:
                print("[WARN] Invalid model number.")


def main():
    parser = argparse.ArgumentParser(description="View 3DGS point clouds, meshes, videos, and change maps on Ubuntu/Linux.")
    parser.add_argument("-d", "--dir", type=str, default=None, help="Working directory to search (default: ./organized, ~/UMP_15_outputs).")
    parser.add_argument("--ply", type=str, default=None, help="Direct path to a .ply file to view.")
    parser.add_argument("--mesh", type=str, default=None, help="Direct path to an .obj mesh to view.")
    parser.add_argument("--masks", type=str, default=None, help="Direct path to a change masks directory to view.")
    parser.add_argument("--video", type=str, default=None, help="Direct path to an .mp4 video to play.")

    args = parser.parse_args()

    # Direct flag invocations
    if args.ply:
        view_point_cloud(Path(args.ply).expanduser().resolve())
        return
    if args.mesh:
        view_mesh(Path(args.mesh).expanduser().resolve())
        return
    if args.masks:
        view_change_masks(Path(args.masks).expanduser().resolve())
        return
    if args.video:
        view_video(Path(args.video).expanduser().resolve())
        return

    # Determine search directory
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent

    candidates = []
    if args.dir:
        candidates.append(Path(args.dir).expanduser().resolve())
    else:
        candidates.extend([
            script_dir / "organized",
            repo_root / "Model_Outputs" / "organized",
            Path.home() / "UMP_15_outputs",
            script_dir / "raw",
            script_dir,
            repo_root,
        ])

    search_dir = None
    for cand in candidates:
        if cand.exists() and cand.is_dir():
            search_dir = cand
            break

    if not search_dir:
        search_dir = script_dir

    interactive_menu(search_dir)


if __name__ == "__main__":
    main()
