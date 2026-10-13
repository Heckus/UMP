#!/usr/bin/env bash
# ==============================================================================
# package_outputs.sh: Package All 15 Model Outputs on QUT Aqua for Local Extraction
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ARCHIVE_NAME="ump_15_outputs.tar.gz"
DEST_ARCHIVE="${REPO_ROOT}/${ARCHIVE_NAME}"
MANIFEST="$(mktemp "${REPO_ROOT}/manifest_XXXXXX.txt")"

echo "======================================================================"
echo " Packaging UMP 15-Model Evaluation Artifacts for Local Extraction"
echo " Working Directory: ${REPO_ROOT}"
echo " Destination:       ${DEST_ARCHIVE}"
echo "======================================================================"

cd "${REPO_ROOT}"

echo "[1/3] Scanning filesystem for verified evaluation artifacts..."

# 1. Textured Surface Meshes (.obj, .mtl, texture maps)
find Dataset/Submerged3D -path "*/output/refined_mesh/*" 2>/dev/null >> "${MANIFEST}" || true
find Dataset/Custom_OSCD_Dataset -path "*/output/refined_mesh/*" 2>/dev/null >> "${MANIFEST}" || true
find Codebase/3DGS-Water-Approaches/Additional/SuGaR-main/output -type f \( -name "*.obj" -o -name "*.mtl" -o -name "*.png" \) 2>/dev/null >> "${MANIFEST}" || true

# 2. Benchmark Metrics & Evaluations (results.json, evaluation.json)
find Codebase -type f \( -name "results.json" -o -name "evaluation.json" \) 2>/dev/null >> "${MANIFEST}" || true

# 3. 3D Gaussian Splatting Point Clouds (.ply)
find Codebase -type f \( -name "point_cloud.ply" -o -name "updated_scene.ply" -o -name "splat.ply" \) \
    ! -path "*/submodules/*" ! -path "*/.cache/*" ! -path "*/checkpoint*" 2>/dev/null >> "${MANIFEST}" || true

# 4. Change Detection Rendered Masks
find Codebase/3DGS-Change-Detection/O-SCD-main/output -path "*/renders/change_mask/*.png" 2>/dev/null >> "${MANIFEST}" || true

# 5. Pipeline Execution Logs
find . -maxdepth 1 -type f \( -name "run_pipeline*.log" -o -name "pipeline_errors.log" \) 2>/dev/null >> "${MANIFEST}" || true

# Clean up, filter, and sort manifest
if [[ -f "${MANIFEST}" ]]; then
    # Filter out empty lines, cameras.bin, points3D.bin, depthmap, and duplicates
    grep -v -E "cameras\.bin|points3D\.bin|depthmap|\.cache|__pycache__|^$" "${MANIFEST}" | sort -u > "${MANIFEST}.filtered" || true
    mv -f "${MANIFEST}.filtered" "${MANIFEST}"
fi

FILE_COUNT="$(wc -l < "${MANIFEST}" 2>/dev/null || echo 0)"
echo "  Found ${FILE_COUNT} evaluation artifact files across all 15 models."

if [[ "${FILE_COUNT}" -eq 0 ]]; then
    echo "[ERROR] No evaluation artifact files found to archive!" >&2
    rm -f "${MANIFEST}"
    exit 1
fi

echo "[2/3] Archiving discovered artifacts into ${ARCHIVE_NAME}..."
tar -czvf "${DEST_ARCHIVE}" -T "${MANIFEST}"
rm -f "${MANIFEST}"

ARCHIVE_SIZE="$(du -h "${DEST_ARCHIVE}" | awk '{print $1}')"
echo "  Package Size: ${ARCHIVE_SIZE}"
sha256sum "${DEST_ARCHIVE}" > "${DEST_ARCHIVE}.sha256"
echo "  Checksum generated: ${DEST_ARCHIVE}.sha256"

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
