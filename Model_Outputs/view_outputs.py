#!/usr/bin/env python3
"""
view_outputs.py
===============
Interactive terminal and CLI viewer for the UMP 15-model outputs on Ubuntu Desktop.
Supports viewing:
  1. 3D Gaussian Splatting Point Clouds (.ply) via CloudCompare / SuperSplat / Open3D
  2. Textured Surface Meshes (.obj) via MeshLab / Blender / Open3D
  3. OSCD 2D Change Detection Masks (.png) via Matplotlib / Eye of GNOME (eog) / feh
"""

import os
import sys
import glob
import shutil
import argparse
import subprocess
import webbrowser
from pathlib import Path
from typing import List, Optional, Tuple, Dict


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
            start_new_session=True
        )
    except Exception as e:
        print(f"[WARN] Could not launch file manager: {e}")


def view_point_cloud(ply_path: Path):
    """Launches a viewer for a 3D Gaussian Splatting .ply point cloud."""
    if not ply_path.exists():
        print(f"[ERROR] Point cloud file not found: {ply_path}")
        return

    print(f"\n======================================================================")
    print(f" 3D Gaussian Splatting Visualizer: {ply_path.name}")
    print(f" File Size: {ply_path.stat().st_size / (1024*1024):.1f} MB | Path: {ply_path.resolve()}")
    print("======================================================================")
    print(" * Note: 3DGS models contain millions of volumetric ellipsoids and spherical")
    print("   harmonics. General point cloud tools (CloudCompare/MeshLab) only display")
    print("   the raw (x,y,z) coordinate dots with scalar fields.")
    print("   To render the photorealistic 3D continuous scene, use SuperSplat WebGL.")
    print("----------------------------------------------------------------------")
    print(" [1] Launch SuperSplat WebGL Renderer (Photorealistic 3DGS - Recommended)")
    print(" [2] Open in CloudCompare (Raw Point Cloud & Geometry Inspection)")
    print(" [3] Open in MeshLab (Raw Point Cloud)")
    print(" [b] Back to main menu")
    print("======================================================================")

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
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
        else:
            print("[WARN] CloudCompare binary not found.")
    elif choice in ["3", "m", "meshlab"]:
        ml_bin = find_system_app(["meshlab", "MeshLab"])
        if ml_bin:
            print(f" -> Launching MeshLab ({ml_bin}) in background...")
            subprocess.Popen(
                [ml_bin, str(ply_path)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
        else:
            print("[WARN] MeshLab binary not found.")


def view_mesh(obj_path: Path):
    """Launches a viewer for a textured 3D .obj surface mesh."""
    if not obj_path.exists():
        print(f"[ERROR] Mesh file not found: {obj_path}")
        return

    # If the mesh has a self-contained companion folder (mesh/), prefer the mesh inside
    # it so MeshLab / Blender natively find relative material and texture assets
    target_to_open = obj_path
    mesh_sub = obj_path.parent / "mesh"
    if mesh_sub.is_dir():
        sub_objs = list(mesh_sub.glob("*.obj"))
        if sub_objs:
            target_to_open = sub_objs[0]

    print(f"\n[INFO] Opening Textured Surface Mesh: {target_to_open} ({target_to_open.stat().st_size / (1024*1024):.1f} MB)")

    # 1. Check for MeshLab
    ml_bin = find_system_app(["meshlab", "MeshLab"])
    if ml_bin:
        print(f" -> Launching MeshLab ({ml_bin}) in background...")
        subprocess.Popen(
            [ml_bin, str(target_to_open)],
            cwd=str(target_to_open.parent),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        return

    # 2. Check for Blender
    blender_bin = find_system_app(["blender", "Blender"])
    if blender_bin:
        print(f" -> Launching Blender ({blender_bin}) in background...")
        subprocess.Popen(
            [blender_bin, str(target_to_open)],
            cwd=str(target_to_open.parent),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        return

    # 3. Check for Open3D in Python
    try:
        import open3d as o3d
        print(" -> Launching Open3D mesh visualizer...")
        mesh = o3d.io.read_triangle_mesh(str(obj_path))
        mesh.compute_vertex_normals()
        o3d.visualization.draw_geometries([mesh], window_name=f"SuGaR Mesh - {obj_path.name}")
        return
    except ImportError:
        pass

    # 4. Fallback to desktop default or file manager
    xdg_bin = find_system_app(["xdg-open"])
    if xdg_bin:
        print(" -> Opening with system default viewer...")
        subprocess.Popen(
            [xdg_bin, str(obj_path)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
    else:
        open_file_manager(obj_path)


def view_change_masks(mask_dir: Path):
    """Displays OSCD 2D change detection masks in a grid or using the system image viewer."""
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
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
    else:
        open_file_manager(mask_dir)


def view_video(video_path: Path):
    """Launches a native media player for reconstructed MP4 heatmaps."""
    if not video_path.exists():
        print(f"[ERROR] Video file not found: {video_path}")
        return

    print(f"\n[INFO] Opening Reconstructed Video Heatmap: {video_path.name} ({video_path.stat().st_size / (1024*1024):.1f} MB)")
    player_bin = find_system_app(["vlc", "mpv", "totem", "celluloid", "parole", "xdg-open"])
    if player_bin:
        print(f" -> Launching media player ({player_bin}) in background...")
        subprocess.Popen(
            [player_bin, str(video_path)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
    else:
        open_file_manager(video_path)


def scan_available_models(base_dir: Path) -> List[Dict]:
    """Discovers all models, scenes, and available output files in the directory."""
    models_found = []

    # Map candidate folders
    subdirs = [d for d in base_dir.rglob("*") if d.is_dir()]
    scene_names = ["Kwaj", "Tokai", "Custom_OSCD_Dataset", "oscd"]

    for d in subdirs:
        if d.name in scene_names:
            scene = d.name
            parent_model = d.parent.name
            ply_files = [p for p in d.glob("*.ply") if "heatmap" not in p.name.lower()]
            if not ply_files:
                ply_files = list(d.glob("*.ply"))
            obj_files = list(d.glob("*.obj"))
            res_files = list(d.glob("results.json")) + list(d.glob("**/results.json"))
            mask_dirs = [m for m in d.rglob("change_masks") if m.is_dir()] or [m for m in d.rglob("change_mask") if m.is_dir()]

            # Discover specialized heatmaps
            heatmap_plys = list(d.glob("*Change_Heatmap_Hybrid.ply")) or list(d.glob("*Change_Heatmap*.ply"))
            videos = list(d.glob("*heatmap_overlay.mp4")) or list(d.glob("*3panel.mp4"))
            strips = list(d.glob("*keyframe_strip.png"))

            # Filter valid
            ply = ply_files[0] if ply_files else None
            obj = obj_files[0] if obj_files else None
            res = res_files[0] if res_files else None
            masks = mask_dirs[0] if mask_dirs else None
            heatmap_ply = heatmap_plys[0] if heatmap_plys else None
            video = videos[0] if videos else None
            strip = strips[0] if strips else None

            if ply or obj or res or masks or heatmap_ply or video:
                # Deduplicate by model + scene
                if not any(m["model"] == parent_model and m["scene"] == scene for m in models_found):
                    models_found.append({
                        "model": parent_model,
                        "scene": scene,
                        "path": d,
                        "ply": ply,
                        "obj": obj,
                        "results": res,
                        "masks": masks,
                        "heatmap_ply": heatmap_ply,
                        "video": video,
                        "strip": strip,
                    })

    # Sort logically
    return sorted(models_found, key=lambda x: (x["model"], x["scene"]))


def interactive_menu(base_dir: Path):
    """Presents a clean interactive menu in the Ubuntu terminal."""
    while True:
        models = scan_available_models(base_dir)

        print("\n======================================================================")
        print(" UMP 15-Model Evaluation & 3D Visualization Terminal")
        print(f" Search Root: {base_dir}")
        print("======================================================================")

        for idx, m in enumerate(models, 1):
            ply_badge = "[PLY]" if m["ply"] else "     "
            obj_badge = "[OBJ]" if m["obj"] else "     "
            res_badge = "[METRICS]" if m["results"] else "         "
            mask_badge = "[MASKS]" if m["masks"] else "       "
            heat_badge = "[HEATMAP 3D/MP4]" if (m.get("heatmap_ply") or m.get("video")) else ""
            print(f" [{idx:02d}] {m['model']:22s} ({m['scene']:18s}) {ply_badge} {obj_badge} {res_badge} {mask_badge} {heat_badge}")

        print("----------------------------------------------------------------------")
        print(" [V] Play O-SCD Reconstructed Video Heat Map (.mp4)")
        print(" [H] View O-SCD 3D Change Heat Map Splat in SuperSplat (.ply)")
        print(" [M] View OSCD Change Detection Masks Gallery (2D)")
        print(" [T] View Master Benchmark Metrics Table")
        print(" [O] Open Working Directory in Ubuntu File Manager")
        print(" [Q] Quit")
        print("======================================================================")

        choice = input("Select an option: ").strip().lower()

        if choice == "q":
            print("Exiting viewer. Have a great day!")
            break
        elif choice == "v":
            videos = list(base_dir.rglob("*heatmap_overlay.mp4")) or list(base_dir.rglob("*.mp4"))
            if videos:
                view_video(videos[0])
            else:
                print("[INFO] Reconstructed video heatmap not generated yet.")
                print("Running `python Model_Outputs/generate_change_heatmaps.py`...")
                subprocess.run([sys.executable, str(Path(__file__).parent / "generate_change_heatmaps.py")])
        elif choice == "h":
            heatmaps = list(base_dir.rglob("*Change_Heatmap_Hybrid.ply")) or list(base_dir.rglob("*Change_Heatmap*.ply"))
            if heatmaps:
                view_point_cloud(heatmaps[0])
            else:
                print("[INFO] 3D change heatmap splat not generated yet.")
                print("Running `python Model_Outputs/generate_change_heatmaps.py`...")
                subprocess.run([sys.executable, str(Path(__file__).parent / "generate_change_heatmaps.py")])
        elif choice == "m":
            oscd_masks = list(base_dir.rglob("change_masks")) or list(base_dir.rglob("change_mask"))
            if oscd_masks:
                view_change_masks(oscd_masks[0])
            else:
                print("[WARN] No OSCD change mask directory discovered.")
        elif choice == "t":
            table_path = base_dir / "master_benchmark_table.md"
            if table_path.exists():
                with open(table_path, "r", encoding="utf-8") as f:
                    print("\n" + f.read())
            else:
                print(f"[WARN] Table not found at {table_path}. Run `python collect_metrics.py` first.")
        elif choice == "o":
            open_file_manager(base_dir)
        elif choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(models):
                selected = models[idx]
                print(f"\nSelected: {selected['model']} ({selected['scene']})")
                print("What would you like to view?")
                options = []
                if selected["ply"]:
                    options.append(("p", "3D Gaussian Splat (.ply)", selected["ply"]))
                if selected["heatmap_ply"]:
                    options.append(("h", "3D Change Heat Map Splat in SuperSplat (.ply)", selected["heatmap_ply"]))
                if selected["video"]:
                    options.append(("v", "Reconstructed Video Heat Map (.mp4)", selected["video"]))
                if selected["strip"]:
                    options.append(("s", "Keyframe Comparison Strip (.png)", selected["strip"]))
                if selected["obj"]:
                    options.append(("m", "3D Textured Mesh (.obj)", selected["obj"]))
                if selected["masks"]:
                    options.append(("k", "Change Detection Masks (.png)", selected["masks"]))
                if selected["results"]:
                    options.append(("r", "Metrics (results.json)", selected["results"]))

                # Option to generate heatmaps if O-SCD
                if any(m_kw in selected["model"].lower() for m_kw in ["oscd", "o-scd"]):
                    options.append(("g", "Generate / Recompute 3D & Video Heat Maps", selected["path"]))

                for opt_key, opt_desc, _ in options:
                    print(f"  [{opt_key}] {opt_desc}")
                print("  [b] Back to main menu")

                sub_choice = input("Choice: ").strip().lower()
                for opt_key, _, target_path in options:
                    if sub_choice == opt_key:
                        if opt_key == "p":
                            view_point_cloud(target_path)
                        elif opt_key == "h":
                            view_point_cloud(target_path)
                        elif opt_key == "v":
                            view_video(target_path)
                        elif opt_key == "s":
                            open_file_manager(target_path)
                        elif opt_key == "m":
                            view_mesh(target_path)
                        elif opt_key == "k":
                            view_change_masks(target_path)
                        elif opt_key == "g":
                            gen_script = Path(__file__).parent / "generate_change_heatmaps.py"
                            subprocess.run([sys.executable, str(gen_script)])
                        elif opt_key == "r":
                            with open(target_path, "r", encoding="utf-8") as f:
                                print(f"\n--- {target_path} ---\n" + f.read())
                        break
            else:
                print("[WARN] Invalid model number.")


def main():
    parser = argparse.ArgumentParser(description="View 3DGS point clouds, meshes, and change maps on Ubuntu.")
    parser.add_argument("-d", "--dir", type=str, default=None, help="Working directory to search (default: ./organized, ~/UMP_15_outputs).")
    parser.add_argument("--ply", type=str, default=None, help="Direct path to a .ply file to view.")
    parser.add_argument("--mesh", type=str, default=None, help="Direct path to an .obj mesh to view.")
    parser.add_argument("--masks", type=str, default=None, help="Direct path to a change masks directory to view.")

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

    # Determine search directory
    script_dir = Path(__file__).resolve().parent
    candidates = []
    if args.dir:
        candidates.append(Path(args.dir).expanduser().resolve())
    else:
        candidates.extend([
            script_dir / "organized",
            Path.home() / "UMP_15_outputs",
            script_dir / "raw",
            script_dir,
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
