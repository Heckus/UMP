#!/usr/bin/env bash
# ==============================================================================
# package_outputs.sh: Package All 15 Model Outputs on QUT Aqua for Local Extraction
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ARCHIVE_NAME="ump_15_outputs.tar.gz"
DEST_ARCHIVE="${REPO_ROOT}/${ARCHIVE_NAME}"

echo "======================================================================"
echo " Packaging UMP 15-Model Evaluation Artifacts for Local Extraction"
echo " Working Directory: ${REPO_ROOT}"
echo " Destination:       ${DEST_ARCHIVE}"
echo "======================================================================"

cd "${REPO_ROOT}"

# Collect all output paths
echo "[1/3] Scanning for benchmark results, meshes, point clouds, and logs..."

# Build tar archive with wildcard patterns for the 15 models
tar -czvf "${DEST_ARCHIVE}" \
    --wildcards \
    --exclude="*cameras.bin" \
    --exclude="*points3D.bin" \
    --exclude="*depthmap*" \
    --exclude="*.cache*" \
    --exclude="*__pycache__*" \
    "Dataset/Submerged3D/*/output/refined_mesh/*" \
    "Dataset/Custom_OSCD_Dataset/output/refined_mesh/*" \
    "Dataset/Custom_OSCD_Dataset/inference_scene/output/refined_mesh/*" \
    "Codebase/*/output/*/point_cloud/iteration_30000/point_cloud.ply" \
    "Codebase/*/*/output/*/point_cloud/iteration_30000/point_cloud.ply" \
    "Codebase/*/*/*/output/*/point_cloud/iteration_30000/point_cloud.ply" \
    "Codebase/3DGS-Water-Approaches/Image/water-splatting-main/outputs/*/*/*/splat.ply" \
    "Codebase/3DGS-Change-Detection/O-SCD-main/output/Custom_OSCD_Dataset/output/updated_scene.ply" \
    "Codebase/3DGS-Change-Detection/O-SCD-main/output/Custom_OSCD_Dataset/output/renders/change_mask/*.png" \
    "Codebase/**/results.json" \
    "Codebase/**/evaluation.json" \
    "run_pipeline_live*.log" \
    "run_pipeline_complete.log" \
    "pipeline_errors.log" || true

echo "[2/3] Verifying package size and SHA256 checksum..."
if [[ -f "${DEST_ARCHIVE}" ]]; then
    ARCHIVE_SIZE="$(du -h "${DEST_ARCHIVE}" | awk '{print $1}')"
    echo "  Package Size: ${ARCHIVE_SIZE}"
    sha256sum "${DEST_ARCHIVE}" > "${DEST_ARCHIVE}.sha256"
    echo "  Checksum generated: ${DEST_ARCHIVE}.sha256"
else
    echo "[ERROR] Archive creation failed!" >&2
    exit 1
fi

echo "======================================================================"
echo " [3/3] Package Complete! How to Download to Local Computer:"
echo "======================================================================"
echo "From your local Ubuntu Desktop terminal (connected to QUT VPN), run:"
echo ""
echo "  rsync -avzP ${USER}@eresdtn01.qut.edu.au:${DEST_ARCHIVE} ~/Downloads/"
echo ""
echo "Or using scp:"
echo "  scp ${USER}@eresdtn01.qut.edu.au:${DEST_ARCHIVE} ~/Downloads/"
echo ""
echo "Extract locally:"
echo "  mkdir -p ~/UMP_15_outputs && tar -xzvf ~/Downloads/${ARCHIVE_NAME} -C ~/UMP_15_outputs/"
echo "======================================================================"
