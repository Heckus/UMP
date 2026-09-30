#!/usr/bin/env bash
# ==============================================================================
# colmap_wrapper.sh - Dynamic Linker & Runtime Wrapper for Conda COLMAP
#
# Ensures that colmap is executed with its conda environment libraries
# (e.g. libOpenImageIO, libceres, libfreeimage, Qt) properly resolved via
# LD_LIBRARY_PATH, preventing 'shared libraries: libOpenImageIO.so' failures
# when called from other Conda environments or non-interactive subshells.
# ==============================================================================

set -eo pipefail

COLMAP_BIN=""
GT_LIB=""

# 1. Search known global_tools locations
for _cand in "${HOME}/.conda/envs/global_tools" \
             "/mnt/hpccs01/home/${USER:-}/.conda/envs/global_tools"; do
    if [[ -x "${_cand}/bin/colmap" ]]; then
        COLMAP_BIN="${_cand}/bin/colmap"
        GT_LIB="${_cand}/lib"
        break
    fi
done

# 2. Fallback to command -v colmap
if [[ -z "${COLMAP_BIN}" ]]; then
    COLMAP_BIN="$(command -v colmap 2>/dev/null || echo "")"
    if [[ -n "${COLMAP_BIN}" ]]; then
        GT_LIB="$(dirname "$(dirname "${COLMAP_BIN}")")/lib"
    fi
fi

if [[ -z "${COLMAP_BIN}" || ! -x "${COLMAP_BIN}" ]]; then
    echo "[ERROR] colmap binary not found. Please ensure global_tools is provisioned." >&2
    exit 127
fi

# Prepend global_tools/lib to LD_LIBRARY_PATH for the lifetime of this colmap call
if [[ -n "${GT_LIB}" && -d "${GT_LIB}" ]]; then
    export LD_LIBRARY_PATH="${GT_LIB}:${LD_LIBRARY_PATH:-}"
fi

exec "${COLMAP_BIN}" "$@"
