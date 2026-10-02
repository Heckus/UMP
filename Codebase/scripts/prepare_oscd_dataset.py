#!/usr/bin/env python3
"""
prepare_oscd_dataset.py
------------------------------------------------------------------------------
Utility for converting input MP4 videos into a normalized dual-scene dataset
for Online Scene Change Detection (O-SCD).

O-SCD operates on dual-scene temporal changes:
  1. Reference Scene (video 1): Initial state (e.g. table with Object A and Object B).
  2. Inference Scene (video 2): Modified state (e.g. Object A kept, Object B removed,
     and Object C added).

This script samples video frames at a calibrated frame rate (default 4 fps, yielding
~120 frames from a 30s video) with optional sharpness optimization, and outputs them
directly into the directory structure expected by `run_pipeline.sh`:

  <output_dir>/
  ├── reference_scene/
  │   └── input/
  │       ├── frame_00001.jpg
  │       ├── frame_00002.jpg
  │       └── ...
  └── inference_scene/
      └── input/
          ├── frame_00001.jpg
          ├── frame_00002.jpg
          └── ...

Once extracted, running:
  ./Codebase/scripts/run_pipeline.sh --model oscd --dataset <output_dir>
will automatically run COLMAP photogrammetric reconstruction, train the 3DGS
reference model, execute online change detection (oscd.py), and update the 3D
Gaussian representation (update.py).
------------------------------------------------------------------------------
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Optional, Tuple

try:
    import cv2
    import numpy as np
    HAS_CV2 = True
except ImportError:
    HAS_CV2 = False
    cv2 = None
    np = None


def find_repo_root() -> Path:
    """Locate the root directory of the UMP repository."""
    current = Path(__file__).resolve().parent
    for parent in [current] + list(current.parents):
        if (parent / "Codebase").is_dir() and (parent / "Dataset").is_dir():
            return parent
        if (parent / ".git").is_dir():
            return parent
    return current.parent.parent


def get_video_properties(video_path: Path) -> dict:
    """Retrieve metadata (FPS, frame count, duration, resolution) for a video file."""
    if not video_path.is_file():
        raise FileNotFoundError(f"Video file not found: {video_path}")

    props = {
        "path": str(video_path),
        "fps": 30.0,
        "total_frames": 0,
        "duration_sec": 0.0,
        "width": 0,
        "height": 0,
    }

    if HAS_CV2:
        cap = cv2.VideoCapture(str(video_path))
        if cap.isOpened():
            fps = cap.get(cv2.CAP_PROP_FPS)
            total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            cap.release()

            if fps > 0:
                props["fps"] = fps
            props["total_frames"] = total
            props["width"] = width
            props["height"] = height
            props["duration_sec"] = total / props["fps"] if props["fps"] > 0 else 0.0
            return props

    # Fallback to ffprobe if available
    ffprobe_bin = shutil.which("ffprobe")
    if ffprobe_bin:
        cmd = [
            ffprobe_bin,
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=width,height,r_frame_rate,nb_frames,duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            str(video_path),
        ]
        try:
            output = subprocess.check_output(cmd, universal_newlines=True).strip().splitlines()
            if len(output) >= 2:
                props["width"] = int(output[0])
                props["height"] = int(output[1])
            if len(output) >= 3 and "/" in output[2]:
                num, den = output[2].split("/")
                props["fps"] = float(num) / float(den) if float(den) > 0 else 30.0
        except Exception:
            pass

    return props


def compute_laplacian_sharpness(img) -> float:
    """Compute the variance of the Laplacian as a proxy for image sharpness."""
    if not HAS_CV2 or img is None:
        return 0.0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


def resize_frame(frame, max_dim: int):
    """Resize image maintaining aspect ratio if larger than max_dim."""
    if not HAS_CV2 or frame is None or max_dim <= 0:
        return frame
    h, w = frame.shape[:2]
    if max(h, w) <= max_dim:
        return frame
    scale = max_dim / float(max(h, w))
    new_w = int(round(w * scale))
    new_h = int(round(h * scale))
    return cv2.resize(frame, (new_w, new_h), interpolation=cv2.INTER_AREA)


def extract_frames_opencv(
    video_path: Path,
    output_dir: Path,
    target_fps: float = 4.0,
    max_frames: Optional[int] = None,
    max_dim: int = 1920,
    select_sharpest: bool = False,
    quality: int = 95,
) -> int:
    """
    Extract frames from a video file using OpenCV.
    Ensures uniform sampling matching target_fps with optional window sharpness selection.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise RuntimeError(f"Could not open video file: {video_path}")

    native_fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if native_fps <= 0:
        native_fps = 30.0

    # Calculate frame sampling step
    step = max(1.0, native_fps / target_fps)
    extracted_count = 0
    next_sample_frame = 0.0

    print(f"  [Video] {video_path.name}")
    print(f"          Native FPS: {native_fps:.2f} | Total Frames: {total_frames}")
    print(f"          Target FPS: {target_fps:.2f} | Sampling Step: ~{step:.2f} frames")

    window_radius = 1 if select_sharpest else 0

    while True:
        curr_idx = int(round(next_sample_frame))
        if curr_idx >= total_frames and total_frames > 0:
            break

        best_frame = None
        best_score = -1.0

        if select_sharpest and window_radius > 0:
            # Check frames in [curr_idx - window_radius, curr_idx + window_radius]
            start_cand = max(0, curr_idx - window_radius)
            end_cand = min(total_frames - 1, curr_idx + window_radius)
            for cand_idx in range(start_cand, end_cand + 1):
                cap.set(cv2.CAP_PROP_POS_FRAMES, cand_idx)
                ret, frame = cap.read()
                if ret and frame is not None:
                    score = compute_laplacian_sharpness(frame)
                    if score > best_score:
                        best_score = score
                        best_frame = frame
        else:
            cap.set(cv2.CAP_PROP_POS_FRAMES, curr_idx)
            ret, frame = cap.read()
            if ret and frame is not None:
                best_frame = frame

        if best_frame is None:
            # Reached end of stream or error reading
            if curr_idx >= total_frames - 1:
                break
            next_sample_frame += step
            continue

        # Resize if necessary
        processed_frame = resize_frame(best_frame, max_dim)

        extracted_count += 1
        out_filename = output_dir / f"frame_{extracted_count:05d}.jpg"
        cv2.imwrite(
            str(out_filename),
            processed_frame,
            [int(cv2.IMWRITE_JPEG_QUALITY), quality],
        )

        if max_frames and extracted_count >= max_frames:
            print(f"  [Limit] Reached maximum requested frame limit ({max_frames}).")
            break

        next_sample_frame += step

    cap.release()
    return extracted_count


def extract_frames_ffmpeg(
    video_path: Path,
    output_dir: Path,
    target_fps: float = 4.0,
    max_frames: Optional[int] = None,
    max_dim: int = 1920,
    quality: int = 95,
) -> int:
    """Fallback extraction method using system ffmpeg binary."""
    ffmpeg_bin = shutil.which("ffmpeg")
    if not ffmpeg_bin:
        raise RuntimeError("Neither OpenCV (cv2) nor ffmpeg is available for frame extraction.")

    output_dir.mkdir(parents=True, exist_ok=True)
    scale_filter = f"scale='min({max_dim},iw)':'min({max_dim},ih)':force_original_aspect_ratio=decrease"
    fps_filter = f"fps={target_fps}"
    vf_string = f"{fps_filter},{scale_filter}"

    out_pattern = str(output_dir / "frame_%05d.jpg")
    cmd = [
        ffmpeg_bin,
        "-y",
        "-i", str(video_path),
        "-vf", vf_string,
        "-qscale:v", str(max(1, int((100 - quality) / 3))),
    ]
    if max_frames:
        cmd.extend(["-vframes", str(max_frames)])
    cmd.append(out_pattern)

    subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    frames = list(output_dir.glob("frame_*.jpg"))
    return len(frames)


def process_scene_video(
    video_path: Path,
    scene_dir: Path,
    target_fps: float = 4.0,
    max_frames: Optional[int] = None,
    max_dim: int = 1920,
    select_sharpest: bool = False,
    quality: int = 95,
) -> int:
    """
    Extracts frames from video and writes them into scene_dir/input/.
    Cleans previous frames if directory already exists.
    """
    input_dir = scene_dir / "input"
    if input_dir.is_dir():
        existing = list(input_dir.glob("frame_*.jpg"))
        if existing:
            print(f"  [Notice] Found {len(existing)} existing frames in {input_dir}. Clearing for fresh extraction.")
            shutil.rmtree(input_dir)
    input_dir.mkdir(parents=True, exist_ok=True)

    if HAS_CV2:
        num_extracted = extract_frames_opencv(
            video_path=video_path,
            output_dir=input_dir,
            target_fps=target_fps,
            max_frames=max_frames,
            max_dim=max_dim,
            select_sharpest=select_sharpest,
            quality=quality,
        )
    else:
        print("  [Warning] OpenCV not detected. Using ffmpeg fallback.")
        num_extracted = extract_frames_ffmpeg(
            video_path=video_path,
            output_dir=input_dir,
            target_fps=target_fps,
            max_frames=max_frames,
            max_dim=max_dim,
            quality=quality,
        )

    print(f"  [Success] Extracted {num_extracted} frames -> {input_dir}")
    return num_extracted


def main():
    repo_root = find_repo_root()
    default_output_dir = repo_root / "Dataset" / "Custom_OSCD_Dataset"

    parser = argparse.ArgumentParser(
        description="Convert dual MP4 videos into a normalized O-SCD dataset for 3D Scene Change Detection.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Standard dual-video conversion for table change detection:
  python Codebase/scripts/prepare_oscd_dataset.py \\
      --video-ref /path/to/table_initial_2_objects.mp4 \\
      --video-inf /path/to/table_modified_1_removed_1_added.mp4

  # Convert with custom sampling rate (e.g. 5 fps) and sharpest frame selection:
  python Codebase/scripts/prepare_oscd_dataset.py \\
      --video-ref table_ref.mp4 \\
      --video-inf table_inf.mp4 \\
      --fps 5.0 --select-sharpest

  # Process only the reference video into a specific dataset folder:
  python Codebase/scripts/prepare_oscd_dataset.py \\
      --video table_ref.mp4 --scene reference_scene --output-dir Dataset/MyTableDataset
        """,
    )

    group_dual = parser.add_argument_group("Dual-Video Mode (Recommended)")
    group_dual.add_argument(
        "--video-ref", "--video1", "-r",
        type=Path,
        help="Path to Reference Video (Video 1: Initial scene state, e.g. table with 2 objects).",
    )
    group_dual.add_argument(
        "--video-inf", "--video2", "-i",
        type=Path,
        help="Path to Inference Video (Video 2: Modified scene state, e.g. 1 object removed, 1 added).",
    )

    group_single = parser.add_argument_group("Single-Video Mode")
    group_single.add_argument(
        "--video", "-v",
        type=Path,
        help="Path to single video file.",
    )
    group_single.add_argument(
        "--scene", "-s",
        choices=["reference_scene", "inference_scene"],
        help="Target scene name when processing a single video.",
    )

    group_params = parser.add_argument_group("Extraction Parameters")
    group_params.add_argument(
        "--output-dir", "-o",
        type=Path,
        default=default_output_dir,
        help=f"Target dataset root directory (default: {default_output_dir}).",
    )
    group_params.add_argument(
        "--fps",
        type=float,
        default=4.0,
        help="Target extraction frame rate (frames per second). Default: 4.0 (~120 frames for 30s video).",
    )
    group_params.add_argument(
        "--max-frames",
        type=int,
        default=180,
        help="Maximum number of frames to extract per scene (default: 180). Set to 0 for unlimited.",
    )
    group_params.add_argument(
        "--max-dim",
        type=int,
        default=1920,
        help="Maximum image dimension (width or height). Scales 4K videos down to 1080p (default: 1920).",
    )
    group_params.add_argument(
        "--select-sharpest",
        action="store_true",
        help="Examine neighbor frames in a local window and pick the sharpest frame (highest Laplacian variance).",
    )
    group_params.add_argument(
        "--quality",
        type=int,
        default=95,
        help="JPEG quality level from 1 to 100 (default: 95).",
    )
    group_params.add_argument(
        "--dry-run",
        action="store_true",
        help="Inspect video metadata and display extraction plan without writing files.",
    )

    args = parser.parse_args()

    max_frames_val = args.max_frames if args.max_frames > 0 else None

    # Validate argument combination
    tasks: List[Tuple[Path, str]] = []
    if args.video_ref or args.video_inf:
        if args.video_ref:
            if not args.video_ref.is_file():
                parser.error(f"Reference video file does not exist: {args.video_ref}")
            tasks.append((args.video_ref.resolve(), "reference_scene"))
        if args.video_inf:
            if not args.video_inf.is_file():
                parser.error(f"Inference video file does not exist: {args.video_inf}")
            tasks.append((args.video_inf.resolve(), "inference_scene"))
    elif args.video:
        if not args.scene:
            parser.error("--scene (reference_scene or inference_scene) is required when using --video.")
        if not args.video.is_file():
            parser.error(f"Video file does not exist: {args.video}")
        tasks.append((args.video.resolve(), args.scene))
    else:
        parser.print_help()
        print("\n[ERROR] Must provide either --video-ref / --video-inf, or --video with --scene.")
        sys.exit(1)

    output_dir = args.output_dir.resolve()
    print("======================================================================")
    print(" O-SCD Video Dataset Extraction & Preparation Suite")
    print("======================================================================")
    print(f" Target Dataset Root : {output_dir}")
    print(f" Sampling Rate       : {args.fps:.2f} FPS")
    print(f" Max Dimension       : {args.max_dim} px")
    print(f" JPEG Quality        : {args.quality}")
    print(f" Sharpness Selection : {'Enabled' if args.select_sharpest else 'Disabled'}")
    if args.dry_run:
        print(" Mode                : DRY RUN (Plan only)")
    print("----------------------------------------------------------------------")

    for vpath, scene_name in tasks:
        props = get_video_properties(vpath)
        est_frames = int(round(props["duration_sec"] * args.fps)) if props["duration_sec"] > 0 else 0
        if max_frames_val and est_frames > max_frames_val:
            est_frames = max_frames_val

        print(f"\n[Plan] Scene: '{scene_name}'")
        print(f"  Source Video: {vpath}")
        print(f"  Resolution  : {props['width']}x{props['height']}")
        print(f"  Duration    : {props['duration_sec']:.1f}s ({props['total_frames']} native frames @ {props['fps']:.1f} fps)")
        print(f"  Expected Output: ~{est_frames} frames -> {output_dir / scene_name / 'input'}")

    if args.dry_run:
        print("\n[DRY RUN] Plan complete. Re-run without --dry-run to generate dataset.")
        return

    # Execute extractions
    print("\n----------------------------------------------------------------------")
    print(" Executing Frame Extractions...")
    print("----------------------------------------------------------------------")

    summary = {}
    for vpath, scene_name in tasks:
        print(f"\nProcessing scene: {scene_name}...")
        scene_dir = output_dir / scene_name
        n_frames = process_scene_video(
            video_path=vpath,
            scene_dir=scene_dir,
            target_fps=args.fps,
            max_frames=max_frames_val,
            max_dim=args.max_dim,
            select_sharpest=args.select_sharpest,
            quality=args.quality,
        )
        summary[scene_name] = n_frames

    # Check overall dataset readiness
    ref_ready = (output_dir / "reference_scene" / "input").is_dir() and len(list((output_dir / "reference_scene" / "input").glob("*.jpg"))) > 0
    inf_ready = (output_dir / "inference_scene" / "input").is_dir() and len(list((output_dir / "inference_scene" / "input").glob("*.jpg"))) > 0

    print("\n======================================================================")
    print(" Extraction Summary")
    print("======================================================================")
    for sc, count in summary.items():
        print(f"  {sc:20s}: {count} frames extracted")
    print("----------------------------------------------------------------------")

    if ref_ready and inf_ready:
        print(" [READY] Both 'reference_scene' and 'inference_scene' are fully populated!")
        print(f" Dataset Location: {output_dir}\n")
        print(" Next step: Run the end-to-end OSCD pipeline using:")
        print(f"   ./Codebase/scripts/run_pipeline.sh --model oscd --dataset {output_dir}")
        print(" Or submit via HPC PBS cluster queue:")
        print(f"   qsub -v ARGS=\"--model oscd --dataset {output_dir}\" HPC/scripts/run_pipeline.pbs")
    else:
        print(" [PARTIAL] The dataset is partially prepared:")
        print(f"   reference_scene : {'[OK]' if ref_ready else '[MISSING - requires extraction]'}")
        print(f"   inference_scene : {'[OK]' if inf_ready else '[MISSING - requires extraction]'}")
        print(f" Please supply the missing video to complete the dual-scene structure.")
    print("======================================================================\n")


if __name__ == "__main__":
    main()
