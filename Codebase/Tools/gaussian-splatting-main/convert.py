#
# Copyright (C) 2023, Inria
# GRAPHDECO research group, https://team.inria.fr/graphdeco
# All rights reserved.
#
# This software is free for non-commercial, research and evaluation use
# under the terms of the LICENSE.md file.
#
# For inquiries contact  george.drettakis@inria.fr
#

import os
import sys
import logging
from argparse import ArgumentParser
import shutil

# This Python script is based on the shell converter script provided in the MipNerF 360 repository.
parser = ArgumentParser("Colmap converter")
parser.add_argument("--no_gpu", action='store_true')
parser.add_argument("--skip_matching", action='store_true')
parser.add_argument("--source_path", "-s", required=True, type=str)
parser.add_argument("--camera", default="OPENCV", type=str)
parser.add_argument("--colmap_executable", default="", type=str)
parser.add_argument("--resize", action="store_true")
parser.add_argument("--magick_executable", default="", type=str)
args = parser.parse_args()
colmap_command = '"{}"'.format(args.colmap_executable) if len(args.colmap_executable) > 0 else "colmap"
magick_command = '"{}"'.format(args.magick_executable) if len(args.magick_executable) > 0 else "magick"
use_gpu = 1 if not args.no_gpu else 0

if not args.skip_matching:
    os.makedirs(args.source_path + "/distorted/sparse", exist_ok=True)

    ## Detect modern COLMAP (3.13+ / 4.x) argument names vs legacy
    feat_help = ""
    try:
        feat_help = os.popen(f"{colmap_command} feature_extractor -h 2>&1").read()
    except Exception:
        pass
    extract_gpu_flag = "--FeatureExtraction.use_gpu" if "FeatureExtraction.use_gpu" in feat_help else "--SiftExtraction.use_gpu"
    matching_gpu_flag = "--FeatureMatching.use_gpu" if "FeatureMatching.use_gpu" in feat_help else "--SiftMatching.use_gpu"

    ## Feature extraction
    feat_extracton_cmd = colmap_command + " feature_extractor "\
        "--database_path " + args.source_path + "/distorted/database.db \
        --image_path " + args.source_path + "/input \
        --ImageReader.single_camera 1 \
        --ImageReader.camera_model " + args.camera + " \
        " + extract_gpu_flag + " " + str(use_gpu)
    exit_code = os.system(feat_extracton_cmd)
    if exit_code != 0:
        logging.error(f"Feature extraction failed with code {exit_code}. Exiting.")
        sys.exit(1)

    ## Feature matching
    feat_matching_cmd = colmap_command + " exhaustive_matcher \
        --database_path " + args.source_path + "/distorted/database.db \
        " + matching_gpu_flag + " " + str(use_gpu)
    exit_code = os.system(feat_matching_cmd)
    if exit_code != 0:
        logging.error(f"Feature matching failed with code {exit_code}. Exiting.")
        sys.exit(1)

    ### Bundle adjustment
    # The default Mapper tolerance is unnecessarily large,
    # decreasing it speeds up bundle adjustment steps.
    mapper_cmd = (colmap_command + " mapper \
        --database_path " + args.source_path + "/distorted/database.db \
        --image_path "  + args.source_path + "/input \
        --output_path "  + args.source_path + "/distorted/sparse \
        --Mapper.ba_global_function_tolerance=0.000001")
    exit_code = os.system(mapper_cmd)
    if exit_code != 0:
        logging.error(f"Mapper failed with code {exit_code}. Exiting.")
        sys.exit(1)

### Image undistortion
## We need to undistort our images into ideal pinhole intrinsics.
## Select the sub-model in distorted/sparse/* with the most registered images (largest images.bin / images.txt)
sparse_root = os.path.join(args.source_path, "distorted", "sparse")
best_submodel = os.path.join(sparse_root, "0")
if os.path.isdir(sparse_root):
    candidates = []
    for sub in sorted(os.listdir(sparse_root)):
        sub_dir = os.path.join(sparse_root, sub)
        if not os.path.isdir(sub_dir):
            continue
        img_bin = os.path.join(sub_dir, "images.bin")
        img_txt = os.path.join(sub_dir, "images.txt")
        if os.path.isfile(img_bin):
            candidates.append((os.path.getsize(img_bin), sub_dir))
        elif os.path.isfile(img_txt):
            candidates.append((os.path.getsize(img_txt), sub_dir))
    if candidates:
        candidates.sort(key=lambda x: x[0], reverse=True)
        best_submodel = candidates[0][1]
        if len(candidates) > 1:
            print(f"[INFO] Multiple COLMAP sub-models found in {sparse_root}; selected {best_submodel} ({candidates[0][0]} bytes)")

def _python_undistort_fallback(source_path, submodel_dir):
    """
    Pure-Python fallback for `colmap image_undistorter` when a valid sparse
    reconstruction already exists in `submodel_dir` (e.g. distorted/sparse/1)
    and the C++ colmap binary fails due to cluster shared library issues.
    Converts camera intrinsics to PINHOLE (model_id=1) in sparse/0/cameras.bin,
    copies images.bin and points3D.bin to sparse/0/, and populates images/.
    """
    import struct
    from scene.colmap_loader import read_intrinsics_binary, read_extrinsics_binary

    cam_bin_in = os.path.join(submodel_dir, "cameras.bin")
    img_bin_in = os.path.join(submodel_dir, "images.bin")
    pts_bin_in = os.path.join(submodel_dir, "points3D.bin")
    if not (os.path.isfile(cam_bin_in) and os.path.isfile(img_bin_in) and os.path.isfile(pts_bin_in)):
        return False

    print(f"[INFO] Running pure-Python image_undistorter fallback from {submodel_dir}...")
    cameras = read_intrinsics_binary(cam_bin_in)
    images = read_extrinsics_binary(img_bin_in)

    sparse_zero_dir = os.path.join(source_path, "sparse", "0")
    images_out_dir = os.path.join(source_path, "images")
    input_dir = os.path.join(source_path, "input")
    os.makedirs(sparse_zero_dir, exist_ok=True)
    os.makedirs(images_out_dir, exist_ok=True)

    # 1. Write PINHOLE (model_id=1) cameras.bin
    cam_bin_out = os.path.join(sparse_zero_dir, "cameras.bin")
    single_radial_models = {
        "SIMPLE_PINHOLE",
        "SIMPLE_RADIAL",
        "RADIAL",
        "SIMPLE_RADIAL_FISHEYE",
        "RADIAL_FISHEYE",
    }
    with open(cam_bin_out, "wb") as fid:
        fid.write(struct.pack("<Q", len(cameras)))
        for cam_id, cam in cameras.items():
            if cam.model in single_radial_models or len(cam.params) < 4:
                fx = float(cam.params[0])
                fy = float(cam.params[0])
                cx = float(cam.params[1])
                cy = float(cam.params[2])
            else:
                fx = float(cam.params[0])
                fy = float(cam.params[1])
                cx = float(cam.params[2])
                cy = float(cam.params[3])
            # model_id = 1 is PINHOLE (4 params: fx, fy, cx, cy)
            fid.write(
                struct.pack(
                    "<iiQQdddd",
                    int(cam.id),
                    1,
                    int(cam.width),
                    int(cam.height),
                    fx,
                    fy,
                    cx,
                    cy,
                )
            )

    # 2. Copy images.bin and points3D.bin into sparse/0/
    shutil.copy2(img_bin_in, os.path.join(sparse_zero_dir, "images.bin"))
    shutil.copy2(pts_bin_in, os.path.join(sparse_zero_dir, "points3D.bin"))

    # 3. Undistort (if cv2 is available) or copy each registered image into images/
    has_cv2 = False
    try:
        import cv2
        import numpy as np
        has_cv2 = True
    except Exception:
        has_cv2 = False

    undist_maps = {}
    if has_cv2:
        for cam_id, cam in cameras.items():
            if cam.model == "OPENCV" and len(cam.params) >= 8:
                fx, fy, cx, cy, k1, k2, p1, p2 = [float(x) for x in cam.params[:8]]
                if abs(k1) > 1e-7 or abs(k2) > 1e-7 or abs(p1) > 1e-7 or abs(p2) > 1e-7:
                    K = np.array([[fx, 0.0, cx], [0.0, fy, cy], [0.0, 0.0, 1.0]], dtype=np.float64)
                    dist = np.array([k1, k2, p1, p2], dtype=np.float64)
                    map1, map2 = cv2.initUndistortRectifyMap(
                        K, dist, None, K, (int(cam.width), int(cam.height)), cv2.CV_32FC1
                    )
                    undist_maps[cam_id] = (map1, map2)

    copied_count = 0
    for img in images.values():
        src_img = os.path.join(input_dir, img.name)
        dst_img = os.path.join(images_out_dir, img.name)
        if not os.path.isfile(src_img):
            continue
        os.makedirs(os.path.dirname(dst_img), exist_ok=True)
        if has_cv2 and img.camera_id in undist_maps:
            raw = cv2.imread(src_img, cv2.IMREAD_COLOR)
            if raw is not None:
                map1, map2 = undist_maps[img.camera_id]
                undist = cv2.remap(raw, map1, map2, interpolation=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
                cv2.imwrite(dst_img, undist)
                copied_count += 1
                continue
        shutil.copy2(src_img, dst_img)
        copied_count += 1

    print(
        f"[INFO] Pure-Python image_undistorter fallback succeeded: "
        f"{copied_count}/{len(images)} images prepared in {images_out_dir} and PINHOLE model written to {sparse_zero_dir}."
    )
    return copied_count > 0


img_undist_cmd = (colmap_command + " image_undistorter \
    --image_path " + args.source_path + "/input \
    --input_path " + best_submodel + " \
    --output_path " + args.source_path + "\
    --output_type COLMAP")
exit_code = os.system(img_undist_cmd)
if exit_code != 0:
    logging.warning(f"colmap image_undistorter exited with code {exit_code}. Attempting pure-Python undistortion fallback...")
    try:
        if not _python_undistort_fallback(args.source_path, best_submodel):
            logging.error(f"Mapper failed with code {exit_code}. Exiting.")
            sys.exit(1)
    except Exception as exc:
        logging.error(f"Pure-Python undistortion fallback failed ({exc}); original code {exit_code}. Exiting.")
        sys.exit(1)
else:
    files = os.listdir(args.source_path + "/sparse")
    os.makedirs(args.source_path + "/sparse/0", exist_ok=True)
    # Copy each file from the source directory to the destination directory
    for file in files:
        if file == '0':
            continue
        source_file = os.path.join(args.source_path, "sparse", file)
        destination_file = os.path.join(args.source_path, "sparse", "0", file)
        shutil.move(source_file, destination_file)

if(args.resize):
    print("Copying and resizing...")

    # Resize images.
    os.makedirs(args.source_path + "/images_2", exist_ok=True)
    os.makedirs(args.source_path + "/images_4", exist_ok=True)
    os.makedirs(args.source_path + "/images_8", exist_ok=True)
    # Get the list of files in the source directory
    files = os.listdir(args.source_path + "/images")
    # Copy each file from the source directory to the destination directory
    for file in files:
        source_file = os.path.join(args.source_path, "images", file)

        destination_file = os.path.join(args.source_path, "images_2", file)
        shutil.copy2(source_file, destination_file)
        exit_code = os.system(magick_command + " mogrify -resize 50% " + destination_file)
        if exit_code != 0:
            logging.error(f"50% resize failed with code {exit_code}. Exiting.")
            exit(exit_code)

        destination_file = os.path.join(args.source_path, "images_4", file)
        shutil.copy2(source_file, destination_file)
        exit_code = os.system(magick_command + " mogrify -resize 25% " + destination_file)
        if exit_code != 0:
            logging.error(f"25% resize failed with code {exit_code}. Exiting.")
            exit(exit_code)

        destination_file = os.path.join(args.source_path, "images_8", file)
        shutil.copy2(source_file, destination_file)
        exit_code = os.system(magick_command + " mogrify -resize 12.5% " + destination_file)
        if exit_code != 0:
            logging.error(f"12.5% resize failed with code {exit_code}. Exiting.")
            exit(exit_code)

print("Done.")
