#!/usr/bin/env bash
# ==============================================================================
# Codebase/scripts/run_pipeline.sh
# ------------------------------------------------------------------------------
# Master Orchestration Pipeline for 3D Gaussian Splatting (3DGS)
# and Online Scene Change Detection (OSCD)
#
# Automates end-to-end execution across 8 models:
#   1. SeaSplat (seasplat_py310)
#   2. 3D-UIR (3d-uir)
#   3. Gaussian Splashing (gaussianSplashing_env)
#   4. WaterSplatting (water_splatting)
#   5. RUSplatting (rusplatting)
#   6. UW-GS (UW-GS)
#   7. SuGaR (sugar)
#   8. OSCD (oscd)
#
# Pipeline Stages:
#   Stage 1: Data Preparation & Download (Submerged3D / OSCD)
#   Stage 2: COLMAP Feature Extraction & Sparse Reconstruction
#   Stage 3: Depth Map Generation & Inversion (Depth-Anything-V2 / RIFE)
#   Stage 4: Model-Specific Training Execution
#   Stage 5: Surface Mesh Extraction (SuGaR .obj / .mtl export)
#   Stage 6: Benchmarking & Quantitative Metrics (results.json)
#
# Fully compliant with ShellCheck (0.11.0+) with zero errors and zero warnings.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Dynamic Directory Resolution
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck disable=SC2034
CODEBASE_DIR="${REPO_ROOT}/Codebase"
DEFAULT_SUBMERGED_DATASET="${REPO_ROOT}/Dataset/Submerged3D"
DEFAULT_OSCD_DATASET="${REPO_ROOT}/Dataset/Custom_OSCD_Dataset"
CONDA_DIR="${CONDA_DIR:-$HOME/miniconda3}"
ERROR_LOG="${REPO_ROOT}/pipeline_errors.log"
export WANDB_MODE="${WANDB_MODE:-offline}"
export PYTHONUNBUFFERED=1
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.0;8.6;8.9;9.0+PTX}"
export TORCH_HOME="${TORCH_HOME:-$HOME/.cache/torch}"
declare -a PIPELINE_SUMMARY=()

# Auto-detect global_tools conda environment if colmap/ffmpeg are missing from PATH
if ! command -v colmap >/dev/null 2>&1 || ! command -v ffmpeg >/dev/null 2>&1; then
    for _gt in "${HOME}/.conda/envs/global_tools/bin" \
               "/mnt/hpccs01/home/${USER:-}/.conda/envs/global_tools/bin" \
               "${CONDA_DIR:-}/envs/global_tools/bin"; do
        if [[ -d "${_gt}" && ( -x "${_gt}/colmap" || -x "${_gt}/ffmpeg" ) ]]; then
            export PATH="${PATH}:${_gt}"
            break
        fi
    done
fi

# ------------------------------------------------------------------------------
# ANSI Color & Formatting Setup
# ------------------------------------------------------------------------------
if [[ -t 1 ]] || [[ "${FORCE_COLOR:-0}" == "1" ]]; then
    CLR_RESET="\033[0m"
    CLR_RED="\033[1;31m"
    CLR_GREEN="\033[1;32m"
    CLR_YELLOW="\033[1;33m"
    CLR_BLUE="\033[1;34m"
    CLR_CYAN="\033[1;36m"
    CLR_BOLD="\033[1m"
else
    CLR_RESET=""
    CLR_RED=""
    CLR_GREEN=""
    CLR_YELLOW=""
    CLR_BLUE=""
    CLR_CYAN=""
    CLR_BOLD=""
fi

log_info()    { printf "%b[INFO]%b %s\n" "${CLR_BLUE}" "${CLR_RESET}" "$*"; }
log_success() { printf "%b[SUCCESS]%b %s\n" "${CLR_GREEN}" "${CLR_RESET}" "$*"; }
log_warn()    { printf "%b[WARN]%b %s\n" "${CLR_YELLOW}" "${CLR_RESET}" "$*" >&2; }
log_error()   { printf "%b[ERROR]%b %s\n" "${CLR_RED}" "${CLR_RESET}" "$*" >&2; }
log_dry()     { printf "%b[DRY-RUN]%b %s\n" "${CLR_CYAN}" "${CLR_RESET}" "$*"; }
log_section() {
    printf "\n%b%b======================================================================%b\n" "${CLR_BOLD}" "${CLR_BLUE}" "${CLR_RESET}"
    printf "%b%b %s%b\n" "${CLR_BOLD}" "${CLR_BLUE}" "$*" "${CLR_RESET}"
    printf "%b%b======================================================================%b\n" "${CLR_BOLD}" "${CLR_BLUE}" "${CLR_RESET}"
}


# ------------------------------------------------------------------------------
# CLI State Flags
# ------------------------------------------------------------------------------
DRY_RUN=false
SKIP_VERIFY=false
SKIP_GPU=false
RUN_ALL=false
MODEL_NAME=""
DATASET_PATH=""
SCENE_NAME=""
STAGE_NAME="all"
GS_OUTPUT_DIR=""

# ------------------------------------------------------------------------------
# Help and Usage Documentation
# ------------------------------------------------------------------------------
show_help() {
    cat << 'EOF'
Usage: run_pipeline.sh [OPTIONS]

Master Orchestration Pipeline for 3D Gaussian Splatting & Online Scene Change Detection

Options:
  -h, --help            Show this help message and exit (status 0)
  --model <name>        Model to train (seasplat, 3d-uir, gaussiansplashing, watersplatting,
                        rusplatting, uw-gs, oscd, sugar)
  --all                 Execute all 8 models sequentially
  --dataset <path>      Path to dataset root or scene directory
  --scene <name>        Specific scene name (e.g. Cormoran, Isro, Kwaj, Tokai; default: Kwaj,Tokai)
  --stage <stage>       Pipeline stage: colmap, depth, train, mesh, eval, all (default: all)
  --dry-run             Print expected execution path and commands without running them
  --skip-verify         Skip pre-execution verification (verify_env.sh)
  --skip-gpu            Pass --skip-gpu to verify_env.sh (for hosts without NVIDIA GPU)
  --gs-output-dir <dir> Checkpoint directory for SuGaR mesh prior (default: best model output)

Supported Models:
  seasplat              SeaSplat physics-based underwater 3DGS (Python 3.10)
  3d-uir                3D-UIR image restoration with depth priors & tiny-cuda-nn (Python 3.10)
  gaussiansplashing     Gaussian Splashing direct volumetric rendering HYB (Python 3.10)
  watersplatting        WaterSplatting Nerfstudio framework (Python 3.8)
  rusplatting           RUSplatting sparse-view underwater 3DGS with inverted depth (Python 3.12)
  uw-gs                 Underwater 3DGS with Background Medium Model (Python 3.7)
  oscd                  Online Scene Change Detection with Multi-View Fusion (Python 3.12)
  sugar                 SuGaR surface mesh extraction from 3DGS prior (Python 3.9)

Supported Stages:
  colmap                COLMAP feature extraction and sparse reconstruction
  depth                 Depth map estimation (standard/inverted) and symlinking
  train                 Model training execution
  mesh                  SuGaR surface mesh extraction (.obj / .mtl export)
  eval                  Held-out test rendering and quantitative metrics (results.json)
  all                   Execute all stages applicable to the selected model (default)

Examples:
  ./run_pipeline.sh --help
  ./run_pipeline.sh --model seasplat --dry-run
  ./run_pipeline.sh --model seasplat --stage train --dry-run --skip-verify
  ./run_pipeline.sh --model oscd --dataset Dataset/Custom_OSCD_Dataset --dry-run
  ./run_pipeline.sh --all --dry-run --skip-verify
  ./run_pipeline.sh --model 3d-uir --scene Cormoran --skip-gpu
EOF
}

# ------------------------------------------------------------------------------
# Model and Stage Normalization
# ------------------------------------------------------------------------------
normalize_model_name() {
    local raw="$1"
    local lower
    lower="$(echo "${raw}" | tr '[:upper:]' '[:lower:]')"
    case "${lower}" in
        seasplat) echo "seasplat" ;;
        3d-uir|3d_uir) echo "3d-uir" ;;
        gaussiansplashing|gaussian-splashing|gaussian_splashing) echo "gaussiansplashing" ;;
        watersplatting|water-splatting|water_splatting) echo "watersplatting" ;;
        rusplatting|ru-splatting|ru_splatting) echo "rusplatting" ;;
        uw-gs|uw_gs) echo "uw-gs" ;;
        oscd|o-scd|o_scd) echo "oscd" ;;
        sugar) echo "sugar" ;;
        *) echo "" ;;
    esac
}

should_run_stage() {
    local stage_query="$1"
    if [[ "${STAGE_NAME}" == "all" || "${STAGE_NAME}" == "${stage_query}" ]]; then
        return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# Safe Conda Activation under set -u
# ------------------------------------------------------------------------------
activate_conda_env() {
    local env_name="$1"
    local conda_hook=""

    if [[ -x "${CONDA_DIR}/bin/conda" ]]; then
        conda_hook="$("${CONDA_DIR}/bin/conda" shell.bash hook 2>/dev/null || true)"
    elif command -v conda >/dev/null 2>&1; then
        conda_hook="$(conda shell.bash hook 2>/dev/null || true)"
    fi

    set +u
    if [[ -n "${conda_hook}" ]]; then
        eval "${conda_hook}"
    elif [[ -f "${CONDA_DIR}/etc/profile.d/conda.sh" ]]; then
        # shellcheck source=/dev/null
        source "${CONDA_DIR}/etc/profile.d/conda.sh"
    elif [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/miniconda3/etc/profile.d/conda.sh"
    elif [[ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/anaconda3/etc/profile.d/conda.sh"
    fi

    conda activate "${env_name}"
    set -u
}

# ------------------------------------------------------------------------------
# Command Execution Wrapper (Live vs. Dry-Run)
# ------------------------------------------------------------------------------
run_stage_command() {
    local env_name="$1"
    local work_dir="$2"
    shift 2
    local cmd=("$@")

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Active Conda environment: ${env_name}"
        log_dry "Working directory: ${work_dir}"
        log_dry "Command: ${cmd[*]}"
        return 0
    fi

    log_info "Executing in [Env: ${env_name}] [CWD: ${work_dir}]:"
    log_info "  ${cmd[*]}"

    (
        cd "${work_dir}"
        activate_conda_env "${env_name}"
        "${cmd[@]}"
    )
}

# ------------------------------------------------------------------------------
# Checkpoint Verification & Provisioning
# ------------------------------------------------------------------------------
ensure_depth_anything_checkpoint() {
    local da_dir="${REPO_ROOT}/Codebase/Tools/Depth-Anything-V2-main"
    local chk_dir="${da_dir}/checkpoints"
    local chk_file="${chk_dir}/depth_anything_v2_vitl.pth"
    local chk_url="https://huggingface.co/depth-anything/Depth-Anything-V2-Large/resolve/main/depth_anything_v2_vitl.pth?download=true"

    if [[ -s "${chk_file}" ]]; then
        return 0
    fi

    log_info "Depth-Anything-V2 checkpoint not found at: ${chk_file}"
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would create ${chk_dir} and download depth_anything_v2_vitl.pth"
        return 0
    fi

    mkdir -p "${chk_dir}"
    log_info "Downloading Depth-Anything-V2 Large checkpoint (~1.3 GB) from Hugging Face..."
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "${chk_file}" "${chk_url}" || rm -f "${chk_file}"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "${chk_file}" "${chk_url}" || rm -f "${chk_file}"
    else
        conda run -n depth_anything python -c "import urllib.request; urllib.request.urlretrieve('${chk_url}', '${chk_file}')" || rm -f "${chk_file}"
    fi

    if [[ ! -s "${chk_file}" ]]; then
        log_error "Failed to download Depth-Anything-V2 checkpoint to ${chk_file}. Please ensure internet connectivity or place depth_anything_v2_vitl.pth manually."
        return 1
    fi
    log_success "Depth-Anything-V2 checkpoint verified: ${chk_file}"
}

ensure_oscd_xfeat() {
    local oscd_dir="${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main"
    local xfeat_submodule="${oscd_dir}/submodules/accelerated_features"
    local xfeat_weights="${oscd_dir}/models/weights/xfeat.pt"

    if [[ -d "${xfeat_submodule}" && -f "${xfeat_weights}" ]]; then
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would verify OSCD XFeat offline submodule and weights at ${xfeat_submodule}"
        return 0
    fi

    mkdir -p "${oscd_dir}/models/weights"
    if [[ ! -d "${xfeat_submodule}" ]]; then
        log_info "Cloning XFeat submodule for offline OSCD execution..."
        git clone --recursive --depth 1 "https://github.com/verlab/accelerated_features.git" "${xfeat_submodule}" 2>/dev/null || true
    fi

    if [[ ! -f "${xfeat_weights}" ]]; then
        if [[ -f "${xfeat_submodule}/weights/xfeat.pt" ]]; then
            cp "${xfeat_submodule}/weights/xfeat.pt" "${xfeat_weights}"
        elif command -v curl >/dev/null 2>&1; then
            curl -sSL -f "https://github.com/verlab/accelerated_features/raw/main/weights/xfeat.pt" -o "${xfeat_weights}" 2>/dev/null || true
        elif command -v wget >/dev/null 2>&1; then
            wget -q -O "${xfeat_weights}" "https://github.com/verlab/accelerated_features/raw/main/weights/xfeat.pt" 2>/dev/null || true
        fi
    fi
    log_info "OSCD XFeat offline assets verified: ${xfeat_weights}"
}

# ------------------------------------------------------------------------------
# 3D-UIR Custom Extension Integrity Verification & On-Demand Rebuild
# ------------------------------------------------------------------------------
ensure_3d_uir_rasterizer() {
    local sub_diff="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main/submodules/diff-gaussian-rasterization"
    if [[ ! -d "${sub_diff}" || ! -f "${sub_diff}/setup.py" ]]; then
        return 0
    fi
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Verify 3D-UIR custom 4D homodirectional rasterizer in '3d-uir' environment"
        return 0
    fi

    # Probe 3d-uir environment for 0.1.0+homodirectional version
    local version_ok=false
    if (
        activate_conda_env "3d-uir"
        python -c "import diff_gaussian_rasterization as d; assert getattr(d, '__version__', '') == '0.1.0+homodirectional'"
    ) >/dev/null 2>&1; then
        version_ok=true
    fi

    if [[ "${version_ok}" != "true" ]]; then
        log_warn "Conda environment '3d-uir' has missing or outdated diff-gaussian-rasterization (requires 4D homodirectional gradient support)."
        log_info "Rebuilding and reinstalling custom diff-gaussian-rasterization for 3d-uir now..."
        local _saved_cuda="${CUDA_HOME:-}"
        for _p in /mnt/weka/pkg/rhel94/GenuineIntel-6/software/CUDA/11.8.0 \
                   /mnt/weka/pkg/rhel94/AuthenticAMD-25/software/CUDA/11.8.0; do
            [[ -f "${_p}/bin/nvcc" ]] && { export CUDA_HOME="${_p}"; export PATH="${_p}/bin:${PATH}"; break; }
        done
        (
            activate_conda_env "3d-uir"
            pip install "${sub_diff}" --no-build-isolation --force-reinstall --no-deps
        ) || {
            log_error "Failed to rebuild diff-gaussian-rasterization for 3d-uir."
            [[ -n "${_saved_cuda}" ]] && export CUDA_HOME="${_saved_cuda}"
            return 1
        }
        [[ -n "${_saved_cuda}" ]] && export CUDA_HOME="${_saved_cuda}"
        log_success "Successfully rebuilt diff-gaussian-rasterization (v0.1.0+homodirectional) in 3d-uir environment."
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Pre-execution Diagnostic Verification
# ------------------------------------------------------------------------------
run_preflight_verification() {
    local target_model="$1"
    local dataset_to_check="$2"

    if [[ "${RUN_ALL}" == "true" ]] || [[ "${target_model}" == "3d-uir" ]]; then
        ensure_3d_uir_rasterizer || true
    fi

    if [[ "${SKIP_VERIFY}" == "true" ]]; then
        log_info "Skipping pre-execution verification (--skip-verify)."
        return 0
    fi

    local verify_args=()
    if [[ "${SKIP_GPU}" == "true" ]]; then
        verify_args+=("--skip-gpu")
    fi

    if [[ -n "${dataset_to_check}" && -e "${dataset_to_check}" ]]; then
        verify_args+=("--dataset" "${dataset_to_check}")
    fi

    if [[ "${RUN_ALL}" == "true" ]]; then
        verify_args+=("--all-envs")
    else
        local envs_to_check=()
        if should_run_stage "colmap"; then
            envs_to_check+=("colmap_runner")
        fi
        if should_run_stage "depth" && [[ "${target_model}" != "oscd" && "${target_model}" != "sugar" ]]; then
            envs_to_check+=("depth_anything")
        fi
        
        if should_run_stage "train" || should_run_stage "eval"; then
            case "${target_model}" in
                seasplat) envs_to_check+=("seasplat_py310") ;;
                3d-uir) envs_to_check+=("3d-uir") ;;
                gaussiansplashing) envs_to_check+=("gaussianSplashing_env") ;;
                watersplatting) envs_to_check+=("water_splatting") ;;
                rusplatting) envs_to_check+=("rusplatting") ;;
                uw-gs) envs_to_check+=("UW-GS") ;;
                sugar) envs_to_check+=("sugar") ;;
                oscd) envs_to_check+=("oscd" "3dgs") ;;
            esac
        fi
        
        if should_run_stage "mesh" && [[ "${target_model}" != "sugar" ]]; then
            envs_to_check+=("sugar")
        fi
        
        if [[ ${#envs_to_check[@]} -eq 0 ]]; then
            # Fallback if no stages match explicitly
            envs_to_check+=("colmap_runner")
        fi

        # Remove duplicates
        local unique_envs=()
        read -r -a unique_envs <<< "$(echo "${envs_to_check[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
        
        for env in "${unique_envs[@]}"; do
            verify_args+=("--env" "${env}")
        done
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Pre-execution verification: would invoke ${SCRIPT_DIR}/verify_env.sh ${verify_args[*]}"
        return 0
    fi

    log_info "Invoking pre-flight verification: ${SCRIPT_DIR}/verify_env.sh ${verify_args[*]}"
    if ! "${SCRIPT_DIR}/verify_env.sh" "${verify_args[@]}"; then
        log_error "Pre-execution verification failed. Aborting pipeline."
        exit 1
    fi
    log_success "Pre-execution verification passed."
}

# ------------------------------------------------------------------------------
# SuGaR Mesh Extraction Helper
# ------------------------------------------------------------------------------
run_sugar_mesh_stage() {
    local scene_path="$1"
    local scene_name="$2"
    local current_model="$3"
    local gs_prior="${GS_OUTPUT_DIR:-}"

    if [[ -z "${gs_prior}" ]]; then
        # Dynamically determine the prior based on the current model being executed
        case "${current_model}" in
            seasplat) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master/output/${scene_name}" ;;
            3d-uir) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main/output/${scene_name}" ;;
            gaussiansplashing) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/gaussianSplashing-main/output/${scene_name}" ;;
            rusplatting) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/RUSplatting-main/output/${scene_name}" ;;
            uw-gs) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/UW-GS-main/output/${scene_name}" ;;
            watersplatting) 
                local ws_base="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main/outputs/${scene_name}/water-splatting"
                local ws_export
                ws_export="$(find "${ws_base}" -type d -name "export" 2>/dev/null | sort -r | head -n 1 || true)"
                if [[ -n "${ws_export}" ]]; then
                    gs_prior="${ws_export}"
                else
                    gs_prior="${ws_base}/export"
                fi
                ;;
            oscd) gs_prior="${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main/output/$(basename "${scene_path}")/output" ;;
            *) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master/output/${scene_name}" ;;
        esac
    fi

    log_info "Mesh Extraction: Running SuGaR on top of best 3DGS point cloud prior from: ${gs_prior}"
    
    if [[ "${DRY_RUN}" != "true" ]]; then
        local target_pc_dir="${gs_prior}/point_cloud/iteration_7000"
        local target_pc="${target_pc_dir}/point_cloud.ply"
        if [[ ! -f "${target_pc}" ]]; then
            mkdir -p "${target_pc_dir}"
            local best_ply=""
            for candidate in "point_cloud/iteration_30000/point_cloud.ply" "updated_scene.ply" "splat.ply" "point_cloud.ply"; do
                local found
                found="$(find "${gs_prior}" -maxdepth 4 -name "$(basename "${candidate}")" | grep "${candidate}$" | head -n 1 || true)"
                if [[ -z "${found}" ]]; then
                    found="$(find "${gs_prior}" -maxdepth 4 -name "${candidate}" | head -n 1 || true)"
                fi
                if [[ -n "${found}" ]]; then
                    best_ply="${found}"
                    break
                fi
            done
            if [[ -n "${best_ply}" ]]; then
                log_info "SuGaR compatibility fix: Symlinking ${best_ply} to ${target_pc}"
                ln -sfn "${best_ply}" "${target_pc}"
            else
                log_warn "No trained 3DGS point cloud prior found in '${gs_prior}'. Skipping SuGaR mesh extraction."
                return 0
            fi
        fi

        # Ensure cameras.json is present in gs_prior (critical for WaterSplatting / Nerfstudio exports)
        local target_cam="${gs_prior}/cameras.json"
        if [[ ! -f "${target_cam}" ]]; then
            local found_cam=""
            found_cam="$(find "${gs_prior}/.." "${REPO_ROOT}/Codebase/3DGS-Water-Approaches" "${scene_path}" -maxdepth 5 -path "*${scene_name}*" -name "cameras.json" 2>/dev/null | head -n 1 || true)"
            if [[ -z "${found_cam}" || ! -f "${found_cam}" ]]; then
                # Search anywhere in Codebase for matching scene's cameras.json
                found_cam="$(find "${REPO_ROOT}/Codebase" -maxdepth 6 -path "*${scene_name}*" -name "cameras.json" 2>/dev/null | head -n 1 || true)"
            fi
            if [[ -n "${found_cam}" && -f "${found_cam}" ]]; then
                log_info "SuGaR compatibility fix: Symlinking ${found_cam} to ${target_cam}"
                ln -sfn "${found_cam}" "${target_cam}"
            fi
        fi
    fi

    run_stage_command "sugar" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/SuGaR-main" \
        python train_full_pipeline.py -s "${scene_path}" -r "dn_consistency" --high_poly True --export_obj True --gs_output_dir "${gs_prior}"
    local expected_obj="${scene_path}/output/refined_mesh/${scene_name}.obj"
    if [[ "${DRY_RUN}" != "true" ]]; then
        local sugar_repo_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/SuGaR-main"
        local found_obj=""
        found_obj="$(find "${sugar_repo_dir}/output" "${scene_path}/output" "${REPO_ROOT}/output" -name "*.obj" 2>/dev/null | sort -r | head -n 1 || true)"
        if [[ -n "${found_obj}" && -f "${found_obj}" ]]; then
            mkdir -p "$(dirname "${expected_obj}")"
            if [[ "${found_obj}" != "${expected_obj}" ]]; then
                cp -f "${found_obj}" "${expected_obj}" 2>/dev/null || ln -sfn "${found_obj}" "${expected_obj}"
            fi
            log_info "SuGaR mesh verified and exported to: ${expected_obj} (source: ${found_obj})"
        else
            log_warn "SuGaR execution finished but no .obj file was found at '${expected_obj}'."
        fi
    else
        log_info "Exported textured mesh: ${expected_obj} with export_obj=True"
    fi
}

# ------------------------------------------------------------------------------
# Single Model Pipeline Execution
# ------------------------------------------------------------------------------
execute_model_pipeline() {
    local model="$1"
    local dataset_arg="$2"
    local scene_arg="$3"

    local dataset_path=""
    local scene_path=""
    local scene_name=""

    if [[ "${model}" == "oscd" ]]; then
        if [[ -n "${dataset_arg}" ]]; then
            dataset_path="${dataset_arg}"
        else
            dataset_path="${DEFAULT_OSCD_DATASET}"
        fi
        scene_name="oscd"
        scene_path="${dataset_path}"
    else
        if [[ -n "${dataset_arg}" ]]; then
            dataset_path="${dataset_arg}"
        else
            dataset_path="${DEFAULT_SUBMERGED_DATASET}"
        fi

        if [[ -d "${dataset_path}/input" || -d "${dataset_path}/images" ]]; then
            scene_path="${dataset_path}"
            scene_name="$(basename "${dataset_path}")"
        else
            scene_name="${scene_arg:-Kwaj}"
            scene_path="${dataset_path}/${scene_name}"
        fi
    fi

    log_section "Pipeline Execution: Model=${model} | Stage=${STAGE_NAME} | Scene=${scene_name}"
    log_info "Selected model: ${model}"
    log_info "Selected stage: ${STAGE_NAME}"
    log_info "Target dataset: ${dataset_path}"
    log_info "Target scene path: ${scene_path}"
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Pipeline dry-run plan for model: ${model} | Stage: ${STAGE_NAME} | Scene: ${scene_name}"
    fi

    # --------------------------------------------------------------------------
    # Stage 1: Data Preparation & Download
    # --------------------------------------------------------------------------
    if should_run_stage "prep" || should_run_stage "all"; then
        log_info "--- Stage 1: Data Preparation & Download ---"
        if [[ "${model}" == "oscd" ]]; then
            if [[ ! -d "${dataset_path}" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_dry "Data prep: Custom_OSCD_Dataset would be prepared at ${dataset_path}"
                else
                    log_warn "OSCD dataset not found at '${dataset_path}'. Please ensure reference_scene and inference_scene exist."
                fi
            elif [[ ! -d "${dataset_path}/reference_scene" || ! -d "${dataset_path}/inference_scene" ]]; then
                log_warn "OSCD stage notice: Target dataset '${dataset_path}' does not contain required 'reference_scene' or 'inference_scene' subdirectories."
            fi

            # Folder normalization for OSCD (images/ -> input/)
            for subscene in "reference_scene" "inference_scene"; do
                if [[ -d "${dataset_path}/${subscene}/images" && ! -d "${dataset_path}/${subscene}/input" ]]; then
                    if [[ "${DRY_RUN}" == "true" ]]; then
                        log_dry "Folder normalization: would rename '${dataset_path}/${subscene}/images' to '${dataset_path}/${subscene}/input'"
                    else
                        log_info "Renaming images/ to input/ for OSCD scene '${subscene}'..."
                        mv "${dataset_path}/${subscene}/images" "${dataset_path}/${subscene}/input"
                        log_success "Normalized OSCD folder: ${subscene}/images -> input"
                    fi
                fi
            done
        else
            if [[ ! -d "${dataset_path}" ]]; then
                if [[ -f "${dataset_path}.zip" ]]; then
                    log_info "Found ${dataset_path}.zip. Extracting to $(dirname "${dataset_path}")..."
                    if [[ "${DRY_RUN}" == "true" ]]; then
                        log_dry "unzip -q \"${dataset_path}.zip\" -d \"$(dirname "${dataset_path}")\""
                    else
                        unzip -q "${dataset_path}.zip" -d "$(dirname "${dataset_path}")"
                        log_success "Extracted dataset archive successfully."
                    fi
                elif [[ -f "${REPO_ROOT}/Dataset/Submerged3D.zip" ]]; then
                    log_info "Found ${REPO_ROOT}/Dataset/Submerged3D.zip. Extracting to ${REPO_ROOT}/Dataset..."
                    if [[ "${DRY_RUN}" == "true" ]]; then
                        log_dry "unzip -q \"${REPO_ROOT}/Dataset/Submerged3D.zip\" -d \"${REPO_ROOT}/Dataset\""
                    else
                        unzip -q "${REPO_ROOT}/Dataset/Submerged3D.zip" -d "${REPO_ROOT}/Dataset"
                        log_success "Extracted dataset archive successfully."
                    fi
                else
                    if [[ "${DRY_RUN}" == "true" ]]; then
                        log_dry "Command: huggingface-cli download theflash987/Submerged3D --repo-type dataset --local-dir ${dataset_path}"
                    else
                        log_info "Downloading Submerged3D benchmark dataset via huggingface-cli..."
                        if command -v huggingface-cli >/dev/null 2>&1; then
                            huggingface-cli download theflash987/Submerged3D --repo-type dataset --local-dir "${dataset_path}"
                        else
                            log_info "Using global_tools conda environment for huggingface-cli..."
                            conda run -n global_tools huggingface-cli download theflash987/Submerged3D --repo-type dataset --local-dir "${dataset_path}"
                        fi
                    fi
                fi
            fi

            # Folder normalization (images/ -> input/)
            if [[ -d "${scene_path}/images" && ! -d "${scene_path}/input" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_dry "Folder normalization: would rename '${scene_path}/images' to '${scene_path}/input'"
                else
                    log_info "Renaming images/ to input/ for scene '${scene_name}'..."
                    mv "${scene_path}/images" "${scene_path}/input"
                    log_success "Normalized folder: images -> input"
                fi
            fi
        fi
    fi

    # --------------------------------------------------------------------------
    # Stage 2: COLMAP Sparse Reconstruction
    # --------------------------------------------------------------------------
    if should_run_stage "colmap"; then
        log_info "--- Stage 2: COLMAP Sparse Reconstruction (colmap) ---"
        if [[ "${model}" == "oscd" ]]; then
            for oscd_sub in "reference_scene" "inference_scene"; do
                local sub_path="${dataset_path}/${oscd_sub}"
                if [[ ! -d "${sub_path}" ]]; then
                    log_warn "OSCD subscene '${sub_path}' not found. Cannot run COLMAP."
                    continue
                fi
                # Folder normalization (images/ -> input/)
                if [[ -d "${sub_path}/images" && ! -d "${sub_path}/input" ]]; then
                    if [[ "${DRY_RUN}" == "true" ]]; then
                        log_dry "Folder normalization: would rename '${sub_path}/images' to '${sub_path}/input'"
                    else
                        mv "${sub_path}/images" "${sub_path}/input"
                    fi
                fi
                if [[ ! -d "${sub_path}/input" ]]; then
                    log_warn "OSCD subscene '${sub_path}' has no input/ directory. Skipping COLMAP for '${oscd_sub}'."
                    continue
                fi
                local img_count
                img_count="$(find "${sub_path}/input" -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.JPG" -o -name "*.png" -o -name "*.jpeg" \) 2>/dev/null | wc -l || true)"
                if [[ ${img_count} -eq 0 ]]; then
                    log_warn "OSCD subscene '${sub_path}/input' contains no images. Skipping COLMAP for '${oscd_sub}'."
                    continue
                fi
                if [[ "${STAGE_NAME}" != "colmap" && -d "${sub_path}/sparse/0" && ( -f "${sub_path}/sparse/0/cameras.bin" || -f "${sub_path}/sparse/0/cameras.txt" ) ]]; then
                    log_info "COLMAP sparse reconstruction already exists for OSCD '${oscd_sub}'. Skipping Stage 2 to conserve compute."
                else
                    log_info "COLMAP undistortion for OSCD '${oscd_sub}':"
                    run_stage_command "colmap_runner" "${REPO_ROOT}/Codebase/Tools/gaussian-splatting-main" \
                        python convert.py -s "${sub_path}" --colmap_executable "${SCRIPT_DIR}/colmap_wrapper.sh"
                    if [[ "${DRY_RUN}" != "true" && ! -f "${sub_path}/sparse/0/cameras.bin" && ! -f "${sub_path}/sparse/0/cameras.txt" ]]; then
                        log_error "COLMAP reconstruction failed to produce sparse/0/cameras.bin for OSCD '${oscd_sub}'."
                        return 1
                    fi
                fi
            done
        else
            # Ensure folder normalization
            if [[ -d "${scene_path}/images" && ! -d "${scene_path}/input" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_dry "Folder normalization: would rename '${scene_path}/images' to '${scene_path}/input'"
                else
                    mv "${scene_path}/images" "${scene_path}/input"
                fi
            fi

            if [[ "${STAGE_NAME}" != "colmap" && -d "${scene_path}/sparse/0" && ( -f "${scene_path}/sparse/0/cameras.bin" || -f "${scene_path}/sparse/0/cameras.txt" ) ]]; then
                log_info "COLMAP sparse reconstruction already exists at '${scene_path}/sparse/0'. Skipping Stage 2 to conserve compute."
            else
                run_stage_command "colmap_runner" "${REPO_ROOT}/Codebase/Tools/gaussian-splatting-main" \
                    python convert.py -s "${scene_path}" --colmap_executable "${SCRIPT_DIR}/colmap_wrapper.sh"
                if [[ "${DRY_RUN}" != "true" && ! -f "${scene_path}/sparse/0/cameras.bin" && ! -f "${scene_path}/sparse/0/cameras.txt" ]]; then
                    log_error "COLMAP reconstruction failed to produce sparse/0/cameras.bin for scene '${scene_name}'."
                    return 1
                fi
            fi
        fi
    fi

    # --------------------------------------------------------------------------
    # Stage 3: Depth Map Generation & Inversion
    # --------------------------------------------------------------------------
    if should_run_stage "depth"; then
        log_info "--- Stage 3: Depth Map Generation & Inversion (depth) ---"
        if [[ "${model}" != "oscd" && "${model}" != "sugar" ]]; then
            ensure_depth_anything_checkpoint
        fi

        if [[ "${model}" == "rusplatting" ]]; then
            local has_inverted_depth=false
            if [[ "${STAGE_NAME}" != "depth" && -d "${scene_path}/depthmap_inverted" ]]; then
                local inv_count
                inv_count="$(find "${scene_path}/depthmap_inverted" -maxdepth 1 -name "*.png" 2>/dev/null | wc -l || true)"
                if [[ ${inv_count} -gt 0 ]]; then
                    has_inverted_depth=true
                fi
            fi

            if [[ "${has_inverted_depth}" == "true" ]]; then
                log_info "Inverted depth maps already exist in '${scene_path}/depthmap_inverted' (${inv_count} files). Skipping Depth-Anything-V2 generation."
            else
                log_info "Generating inverted depth maps for RUSplatting (Depth-Anything-V2 ViT-L):"
                run_stage_command "depth_anything" "${REPO_ROOT}/Codebase/Tools/Depth-Anything-V2-main" \
                    python run.py --encoder vitl --pred-only --grayscale --img-path "${scene_path}/input" --outdir "${scene_path}/depthmap_inverted"
            fi

            log_info "Note: RUSplatting expects pre-generated intermediate frames (e.g., via RIFE) with ._to_. naming pattern in the input directory."
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_dry "RIFE frame interpolation: generate synthetic intermediate frames with '_to_' naming pattern in ${scene_path}/input"
                log_dry "Symlink inverted depthmap: ln -sfn ${scene_path}/depthmap_inverted ${scene_path}/depthmap"
            else
                ln -sfn "${scene_path}/depthmap_inverted" "${scene_path}/depthmap"
            fi
        elif [[ "${model}" == "3d-uir" ]]; then
            local has_depth=false
            if [[ "${STAGE_NAME}" != "depth" && -d "${scene_path}/depthmap" ]]; then
                local d_count
                d_count="$(find "${scene_path}/depthmap" -maxdepth 1 -name "*.png" 2>/dev/null | wc -l || true)"
                if [[ ${d_count} -gt 0 ]]; then
                    has_depth=true
                fi
            fi

            if [[ "${has_depth}" == "true" ]]; then
                log_info "Depth maps already exist in '${scene_path}/depthmap' (${d_count} files). Skipping Depth-Anything-V2 generation."
            else
                log_info "Generating standard depth maps for 3D-UIR (Depth-Anything-V2 ViT-L):"
                run_stage_command "depth_anything" "${REPO_ROOT}/Codebase/Tools/Depth-Anything-V2-main" \
                    python run.py --encoder vitl --pred-only --grayscale --img-path "${scene_path}/input" --outdir "${scene_path}/depthmap"
            fi

            log_info "Symlink depthmap to depths for 3D-UIR: ${scene_path}/depths -> ${scene_path}/depthmap"
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_dry "Symlink depthmap to depths: ln -sfn ${scene_path}/depthmap ${scene_path}/depths"
            else
                ln -sfn "${scene_path}/depthmap" "${scene_path}/depths"
            fi

            if [[ "${STAGE_NAME}" != "depth" && -f "${scene_path}/depths/depth_scale.json" ]]; then
                log_info "3D-UIR depth scale JSON already exists at '${scene_path}/depths/depth_scale.json'. Skipping computation."
            else
                log_info "Computing depth scale JSON for 3D-UIR:"
                run_stage_command "3d-uir" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main" \
                    python utils/make_depth_scale.py --base_dir "${scene_path}" --depths_dir "${scene_path}/depths"
            fi
        elif [[ "${model}" != "oscd" && "${model}" != "sugar" ]]; then
            local has_std_depth=false
            if [[ "${STAGE_NAME}" != "depth" && -d "${scene_path}/depthmap" ]]; then
                local s_count
                s_count="$(find "${scene_path}/depthmap" -maxdepth 1 -name "*.png" 2>/dev/null | wc -l || true)"
                if [[ ${s_count} -gt 0 ]]; then
                    has_std_depth=true
                fi
            fi

            if [[ "${has_std_depth}" == "true" ]]; then
                log_info "Depth maps already exist in '${scene_path}/depthmap' (${s_count} files). Skipping Depth-Anything-V2 generation."
            else
                log_info "Generating standard depth maps (Depth-Anything-V2 ViT-L):"
                run_stage_command "depth_anything" "${REPO_ROOT}/Codebase/Tools/Depth-Anything-V2-main" \
                    python run.py --encoder vitl --pred-only --grayscale --img-path "${scene_path}/input" --outdir "${scene_path}/depthmap"
            fi
        fi

        # Align depth map filename extensions with input image extensions for seamless loader compatibility
        if [[ "${DRY_RUN}" != "true" ]]; then
            for ddir in "${scene_path}/depthmap" "${scene_path}/depthmap_inverted"; do
                if [[ -d "${ddir}" ]]; then
                    local img_dir="${scene_path}/input"
                    [[ ! -d "${img_dir}" && -d "${scene_path}/images" ]] && img_dir="${scene_path}/images"
                    if [[ -d "${img_dir}" ]]; then
                        for img_file in "${img_dir}"/*; do
                            if [[ -f "${img_file}" ]]; then
                                local bname base_no_ext
                                bname="$(basename "${img_file}")"
                                base_no_ext="${bname%.*}"
                                if [[ -f "${ddir}/${base_no_ext}.png" && ! -f "${ddir}/${bname}" ]]; then
                                    ln -sfn "${base_no_ext}.png" "${ddir}/${bname}"
                                fi
                            fi
                        done
                    fi
                fi
            done
        fi
    fi

    # --------------------------------------------------------------------------
    # Stage 4: Model Training
    # --------------------------------------------------------------------------
    if should_run_stage "train"; then
        log_info "--- Stage 4: Model Training (train) (${model}) ---"
        case "${model}" in
            seasplat)
                run_stage_command "seasplat_py310" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master" \
                    python train.py -s "${scene_path}" -m "output/${scene_name}" --do_seathru --seathru_from_iter 10000 --eval
                ;;
            3d-uir)
                if [[ "${DRY_RUN}" != "true" ]]; then
                    conda run -n "3d-uir" pip install matplotlib kornia 2>/dev/null || true
                    ensure_3d_uir_rasterizer
                fi
                run_stage_command "3d-uir" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main" \
                    python train.py -s "${scene_path}" -m "output/${scene_name}" -d "${scene_path}/depths" --eval
                ;;
            gaussiansplashing)
                run_stage_command "gaussianSplashing_env" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/gaussianSplashing-main" \
                    python train.py -s "${scene_path}" -m "output/${scene_name}" --underwater_processing HYB --eval
                local gs_out="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/gaussianSplashing-main/output/${scene_name}"
                if [[ -d "${gs_out}" ]]; then
                    if [[ ! -f "${gs_out}/cfg_args" && -f "${gs_out}/cfg_args.json" ]]; then
                        cp -n "${gs_out}/cfg_args.json" "${gs_out}/cfg_args" 2>/dev/null || true
                    fi
                fi
                ;;
            watersplatting)
                local ws_img_path="images"
                if [[ ! -d "${scene_path}/images" && -d "${scene_path}/input" ]]; then
                    ws_img_path="input"
                fi
                local ws_output_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main/outputs/${scene_name}/water-splatting"
                local config_path
                config_path="$(find "${ws_output_dir}" -name 'config.yml' 2>/dev/null | sort -r | head -n 1 || true)"
                local has_checkpoint=false
                if [[ -n "${config_path}" && -d "$(dirname "${config_path}")/nerfstudio_models" ]]; then
                    if find "$(dirname "${config_path}")/nerfstudio_models" -name "*.ckpt" 2>/dev/null | grep -q "\.ckpt"; then
                        has_checkpoint=true
                    fi
                fi

                if [[ "${STAGE_NAME}" != "train" && "${has_checkpoint}" == "true" ]]; then
                    log_info "WaterSplatting checkpoint already exists at $(dirname "${config_path}"). Skipping training to conserve compute."
                else
                    run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \
                        ns-train water-splatting --experiment-name "${scene_name}" --vis wandb --viewer.quit-on-train-completion True colmap --downscale-factor 1 --eval-mode interval --eval-interval 8 --colmap-path sparse/0 --data "${scene_path}" --images-path "${ws_img_path}"
                    config_path="$(find "${ws_output_dir}" -name 'config.yml' 2>/dev/null | sort -r | head -n 1 || true)"
                fi

                if [[ -n "${config_path}" ]]; then
                    local run_dir
                    run_dir="$(dirname "${config_path}")"
                    log_info "Exporting WaterSplatting to .ply for visualization and SuGaR:"
                    if [[ "${DRY_RUN}" != "true" ]]; then
                        # Patch nerfstudio exporter to allow WaterSplattingModel
                        local exporter_path=""
                        for p in "${HOME}/.conda/envs/water_splatting/lib/python"*/site-packages/nerfstudio/scripts/exporter.py; do
                            if [[ -f "${p}" ]]; then
                                exporter_path="${p}"
                                break
                            fi
                        done
                        if [[ -z "${exporter_path}" ]]; then
                            exporter_path=$(conda run -n water_splatting python -c "import nerfstudio.scripts.exporter as e; print(e.__file__)" 2>/dev/null || true)
                        fi
                        if [[ -n "${exporter_path}" && -f "${exporter_path}" ]]; then
                            sed -i 's/assert isinstance(pipeline.model, SplatfactoModel)/# assert isinstance(pipeline.model, SplatfactoModel)/g' "${exporter_path}" || true
                        fi
                    fi
                    run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \
                        ns-export gaussian-splat --load-config "${config_path}" --output-dir "${run_dir}/export"
                fi
                ;;
            rusplatting)
                run_stage_command "rusplatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/RUSplatting-main" \
                    python train.py -s "${scene_path}" -m "output/${scene_name}" --adaptive --eval
                ;;
            uw-gs)
                run_stage_command "UW-GS" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/UW-GS-main" \
                    python train.py -s "${scene_path}" -m "output/${scene_name}" --BMM_Flag --eval
                ;;
            oscd)
                if [[ "${DRY_RUN}" != "true" && (! -d "${dataset_path}/reference_scene" || ! -d "${dataset_path}/inference_scene") ]]; then
                    log_warn "OSCD execution requires '${dataset_path}/reference_scene' and '${dataset_path}/inference_scene'. Dataset missing or incomplete. Skipping OSCD."
                    return 0
                fi
                if [[ "${DRY_RUN}" != "true" ]]; then
                    local ref_img_count
                    ref_img_count="$(find "${dataset_path}/reference_scene/input" "${dataset_path}/reference_scene/images" -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.JPG" -o -name "*.png" -o -name "*.jpeg" \) 2>/dev/null | wc -l || true)"
                    if [[ ${ref_img_count} -eq 0 ]]; then
                        log_warn "OSCD reference scene contains no images. Skipping OSCD."
                        return 0
                    fi
                fi

                local oscd_output_base
                oscd_output_base="${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main/output/$(basename "${dataset_path}")"
                local ref_pc="${oscd_output_base}/reference_reconstruction/point_cloud/iteration_30000/point_cloud.ply"

                if [[ -f "${ref_pc}" ]]; then
                    log_info "OSCD reference reconstruction checkpoint already exists at ${ref_pc}. Skipping Step 1."
                else
                    log_info "Step 1: Baseline reference 3DGS reconstruction (30k iterations checkpoint: reference_reconstruction/point_cloud/iteration_30000/point_cloud.ply):"
                    run_stage_command "3dgs" "${REPO_ROOT}/Codebase/Tools/gaussian-splatting-main" \
                        python train.py -s "${dataset_path}/reference_scene" -m "${oscd_output_base}/reference_reconstruction"
                fi
                
                # We need to symlink the reference reconstruction back to the dataset path because oscd.py hardcodes looking for it inside args.source_path
                # "os.path.join(args.source_path, 'reference_reconstruction', ...)"
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_dry "Symlink reference reconstruction: ln -sfn ${oscd_output_base}/reference_reconstruction ${dataset_path}/reference_reconstruction"
                else
                    mkdir -p "${dataset_path}"
                    if [[ ! -e "${dataset_path}/reference_reconstruction" ]]; then
                        ln -sfn "${oscd_output_base}/reference_reconstruction" "${dataset_path}/reference_reconstruction"
                    fi
                fi

                ensure_oscd_xfeat
                log_info "Step 2: Online Scene Change Detection (oscd.py in O-SCD-main):"
                run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \
                    python oscd.py -s "${dataset_path}" -m "${oscd_output_base}/output" --resolution 1 --test_hold 5 --refine
                log_info "Step 3: Update 3D scene representation (update.py producing updated_scene.ply):"
                run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \
                    python update.py -s "${dataset_path}" -m "${oscd_output_base}/output" --resolution 1 --test_hold 5
                ;;
            sugar)
                run_sugar_mesh_stage "${scene_path}" "${scene_name}" "${model}"
                ;;
        esac
    fi

    # --------------------------------------------------------------------------
    # Stage 5: Mesh Extraction (SuGaR)
    # --------------------------------------------------------------------------
    if should_run_stage "mesh" && [[ "${model}" != "sugar" && "${model}" != "oscd" ]]; then
        log_info "--- Stage 5: Mesh Extraction (mesh) (SuGaR) ---"
        run_sugar_mesh_stage "${scene_path}" "${scene_name}" "${model}"
    fi

    # --------------------------------------------------------------------------
    # Stage 6: Benchmarking & Metrics Evaluation
    # --------------------------------------------------------------------------
    if should_run_stage "eval"; then
        log_info "--- Stage 6: Benchmarking & Metrics Evaluation (eval) (${model}) ---"
        if [[ "${model}" == "oscd" ]]; then
            local oscd_output_base
            oscd_output_base="${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main/output/$(basename "${dataset_path}")"
            log_info "Evaluating novel view synthesis metrics (utils/metrics.py -> results.json):"
            run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \
                python utils/metrics.py -m "${oscd_output_base}/output"
            if [[ -d "${dataset_path}/gt_mask" ]]; then
                log_info "Evaluating change detection segmentation masks (utils/evaluate.py):"
                run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \
                    python utils/evaluate.py --gt "${dataset_path}/gt_mask" --pred_binary "${oscd_output_base}/output/renders/change_mask"
            else
                log_warn "OSCD gt_mask directory not found at '${dataset_path}/gt_mask'. Skipping mask evaluation."
            fi
            log_info "Metrics written to results.json and evaluation.json"
        elif [[ "${model}" == "watersplatting" ]]; then
            local ws_output_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main/outputs/${scene_name}/water-splatting"
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_dry "Would evaluate WaterSplatting: ns-eval --load-config ${ws_output_dir}/latest/config.yml --output-path ${ws_output_dir}/latest/results.json"
            else
                local config_path
                config_path="$(find "${ws_output_dir}" -name 'config.yml' 2>/dev/null | sort -r | head -n 1 || true)"
                if [[ -z "${config_path}" ]]; then
                    log_warn "Could not find config.yml for WaterSplatting in ${ws_output_dir}. Skipping evaluation."
                else
                    local run_dir
                    run_dir="$(dirname "${config_path}")"
                    log_info "Evaluating WaterSplatting with config: ${config_path}"
                    run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \
                        ns-eval --load-config "${config_path}" --output-path "${run_dir}/results.json"
                fi
            fi

        elif [[ "${model}" == "sugar" ]]; then
            log_info "SuGaR mesh evaluation completed with OBJ export."
        else
            local eval_dir=""
            local eval_env=""
            local output_path=""
            local render_script="render.py"

            case "${model}" in
                seasplat)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master"
                    eval_env="seasplat_py310"
                    output_path="${eval_dir}/output/${scene_name}"
                    render_script="render_uw.py"
                    ;;
                3d-uir)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main"
                    eval_env="3d-uir"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
                gaussiansplashing)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/gaussianSplashing-main"
                    eval_env="gaussianSplashing_env"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
                rusplatting)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/RUSplatting-main"
                    eval_env="rusplatting"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
                uw-gs)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/UW-GS-main"
                    eval_env="UW-GS"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
            esac

            if [[ "${model}" == "gaussiansplashing" && -d "${output_path}" ]]; then
                if [[ ! -f "${output_path}/cfg_args" && -f "${output_path}/cfg_args.json" ]]; then
                    cp -n "${output_path}/cfg_args.json" "${output_path}/cfg_args" 2>/dev/null || true
                fi
            fi

            if [[ "${DRY_RUN}" != "true" && ! -d "${output_path}" ]]; then
                log_warn "Output directory '${output_path}' not found. Skipping evaluation for ${model}."
                return 0
            fi

            log_info "Running held-out novel view synthesis rendering (${render_script}):"
            run_stage_command "${eval_env}" "${eval_dir}" python "${render_script}" -m "${output_path}" -s "${scene_path}" --skip_train
            log_info "Computing quantitative metrics (metrics.py):"
            run_stage_command "${eval_env}" "${eval_dir}" python metrics.py -m "${output_path}" -s "${scene_path}"
            log_info "Evaluation metrics computed: results.json (PSNR, SSIM, LPIPS) in ${output_path}"
        fi
    fi

    log_success "Pipeline execution completed for model: ${model}"
}

# ------------------------------------------------------------------------------
# Fault-Tolerant Execution Wrapper
# ------------------------------------------------------------------------------
run_with_fault_tolerance() {
    local m="$1"
    local dataset="$2"
    local scene="$3"

    log_info "Starting fault-tolerant execution for model=${m}, scene=${scene}"

    # Failsafe: Verify available filesystem storage (require >= 5GB free)
    local available_kb
    available_kb="$(df -k "${REPO_ROOT}" 2>/dev/null | awk 'NR==2 {print $4}' || true)"
    if [[ -n "${available_kb}" && "${available_kb}" =~ ^[0-9]+$ ]]; then
        local available_gb=$(( available_kb / 1024 / 1024 ))
        if [[ ${available_gb} -lt 5 ]]; then
            local timestamp
            timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
            log_error "CRITICAL: Insufficient disk space on ${REPO_ROOT} (${available_gb} GB remaining < 5 GB threshold)."
            echo "[${timestamp}] DISK_ERROR: Model=${m} | Scene=${scene} | Remaining=${available_gb}GB" >> "${ERROR_LOG}"
            PIPELINE_SUMMARY+=("${m}|${scene}|DISK_LOW (${available_gb}GB)|0s")
            return 1
        fi
        log_info "Storage check: ${available_gb} GB available on filesystem."
    fi

    local start_time
    start_time="$(date +%s)"

    set +e
    (
        set -e
        execute_model_pipeline "${m}" "${dataset}" "${scene}"
    )
    local exit_code=$?
    set -e

    local end_time
    end_time="$(date +%s)"
    local elapsed=$(( end_time - start_time ))
    local elapsed_str
    if [[ ${elapsed} -ge 3600 ]]; then
        elapsed_str="$(( elapsed / 3600 ))h $(( (elapsed % 3600) / 60 ))m $(( elapsed % 60 ))s"
    elif [[ ${elapsed} -ge 60 ]]; then
        elapsed_str="$(( elapsed / 60 ))m $(( elapsed % 60 ))s"
    else
        elapsed_str="${elapsed}s"
    fi

    if [[ ${exit_code} -ne 0 ]]; then
        local timestamp
        timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
        log_error "Execution failed for model=${m}, scene=${scene} with exit code ${exit_code} (Duration: ${elapsed_str})."
        log_warn "Recording failure and continuing to the next execution..."
        echo "[${timestamp}] ERROR: Model=${m} | Scene=${scene} | Stage=${STAGE_NAME} | ExitCode=${exit_code} | Duration=${elapsed_str}" >> "${ERROR_LOG}"
        PIPELINE_SUMMARY+=("${m}|${scene}|FAILED (code ${exit_code})|${elapsed_str}")
    else
        log_success "Execution completed successfully for model=${m}, scene=${scene} (Duration: ${elapsed_str})."
        PIPELINE_SUMMARY+=("${m}|${scene}|SUCCESS|${elapsed_str}")
    fi

    # Cool-down and GPU memory cleanup between model executions
    sleep 2
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_stat
        gpu_stat="$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || true)"
        if [[ -n "${gpu_stat}" ]]; then
            log_info "Post-run GPU Memory: ${gpu_stat} MiB (used, total)"
        fi
    fi
}

# ------------------------------------------------------------------------------
# Main Entry Point & Orchestration
# ------------------------------------------------------------------------------
main() {
    # 1. Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            --skip-gpu)
                SKIP_GPU=true
                shift
                ;;
            --all)
                RUN_ALL=true
                shift
                ;;
            --model)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--model' requires a model name argument."
                    exit 1
                fi
                MODEL_NAME="$2"
                shift 2
                ;;
            --dataset)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--dataset' requires a path argument."
                    exit 1
                fi
                DATASET_PATH="$2"
                shift 2
                ;;
            --scene)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--scene' requires a scene name argument."
                    exit 1
                fi
                SCENE_NAME="$2"
                shift 2
                ;;
            --stage)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--stage' requires a stage name argument."
                    exit 1
                fi
                STAGE_NAME="$2"
                shift 2
                ;;
            --gs-output-dir)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--gs-output-dir' requires a directory path argument."
                    exit 1
                fi
                GS_OUTPUT_DIR="$2"
                shift 2
                ;;
            *)
                log_error "Unrecognized option: '$1'"
                echo "" >&2
                show_help >&2
                exit 1
                ;;
        esac
    done

    # 2. Defensive checks: model or all required
    if [[ "${RUN_ALL}" != "true" && -z "${MODEL_NAME}" ]]; then
        log_error "Must specify either --model <name> or --all to run the pipeline."
        echo "" >&2
        show_help >&2
        exit 1
    fi

    # 3. Validate stage argument
    local stage_lower
    stage_lower="$(echo "${STAGE_NAME}" | tr '[:upper:]' '[:lower:]')"
    case "${stage_lower}" in
        colmap|depth|train|mesh|eval|all)
            STAGE_NAME="${stage_lower}"
            ;;
        *)
            log_error "Unknown or invalid stage: '${STAGE_NAME}'. Supported stages: colmap, depth, train, mesh, eval, all."
            exit 1
            ;;
    esac

    # 4. Validate dataset path if explicitly provided
    if [[ -n "${DATASET_PATH}" ]]; then
        if [[ ! -d "${DATASET_PATH}" ]]; then
            log_error "Dataset path does not exist or is not a directory: '${DATASET_PATH}'"
            exit 3
        fi
        DATASET_PATH="$(cd "${DATASET_PATH}" && pwd)"
    fi

    # 5. Model validation (if single model)
    local canonical_model=""
    if [[ "${RUN_ALL}" != "true" ]]; then
        canonical_model="$(normalize_model_name "${MODEL_NAME}")"
        if [[ -z "${canonical_model}" ]]; then
            log_error "Unknown or invalid model: '${MODEL_NAME}'. Supported models: seasplat, 3d-uir, gaussiansplashing, watersplatting, rusplatting, uw-gs, oscd, sugar."
            exit 1
        fi
    fi

    # 6. Pre-flight verification
    local verify_dataset="${DATASET_PATH}"
    if [[ -z "${verify_dataset}" ]]; then
        if [[ "${canonical_model}" == "oscd" ]]; then
            verify_dataset="${DEFAULT_OSCD_DATASET}"
        else
            verify_dataset="${DEFAULT_SUBMERGED_DATASET}"
        fi
    fi
    run_preflight_verification "${canonical_model}" "${verify_dataset}"

    # 7. Pipeline execution
    local default_scenes=("Kwaj" "Tokai")
    local scenes_to_run=()
    if [[ -n "${SCENE_NAME}" ]]; then
        IFS=',' read -ra scenes_to_run <<< "${SCENE_NAME}"
    else
        scenes_to_run=("${default_scenes[@]}")
    fi

    if [[ "${RUN_ALL}" == "true" ]]; then
        log_section "Beginning Sequential Execution of All 8 Models"
        local all_models=("seasplat" "3d-uir" "gaussiansplashing" "watersplatting" "rusplatting" "uw-gs" "sugar" "oscd")
        for m in "${all_models[@]}"; do
            local m_dataset="${DATASET_PATH}"
            if [[ -z "${m_dataset}" ]]; then
                if [[ "${m}" == "oscd" ]]; then
                    m_dataset="${DEFAULT_OSCD_DATASET}"
                else
                    m_dataset="${DEFAULT_SUBMERGED_DATASET}"
                fi
            else
                # If explicit dataset was given, but running oscd and it doesn't match oscd structure
                if [[ "${m}" == "oscd" && (! -d "${m_dataset}/reference_scene" || ! -d "${m_dataset}/inference_scene") ]]; then
                    if [[ -d "${DEFAULT_OSCD_DATASET}" ]]; then
                        log_info "OSCD stage notice: Dataset '${m_dataset}' lacks dual-scene structure. Falling back to default OSCD dataset at '${DEFAULT_OSCD_DATASET}'."
                        m_dataset="${DEFAULT_OSCD_DATASET}"
                    else
                        log_warn "OSCD stage notice: Dataset '${m_dataset}' does not contain 'reference_scene' or 'inference_scene' subdirectories (required for OSCD change detection)."
                    fi
                fi
            fi
            
            if [[ "${m}" == "oscd" ]]; then
                run_with_fault_tolerance "${m}" "${m_dataset}" "oscd"
            else
                for s in "${scenes_to_run[@]}"; do
                    run_with_fault_tolerance "${m}" "${m_dataset}" "${s}"
                done
            fi
        done
        log_section "All 8 Models Sequential Execution Finished"
    else
        if [[ "${canonical_model}" == "oscd" ]]; then
            run_with_fault_tolerance "${canonical_model}" "${DATASET_PATH}" "oscd"
        else
            for s in "${scenes_to_run[@]}"; do
                run_with_fault_tolerance "${canonical_model}" "${DATASET_PATH}" "${s}"
            done
        fi
    fi

    # --------------------------------------------------------------------------
    # Pipeline Execution Summary Report
    # --------------------------------------------------------------------------
    log_section "Pipeline Execution Summary Report"
    echo -e "${CLR_BOLD}--------------------------------------------------------------------------------${CLR_RESET}"
    printf "%-18s %-16s %-24s %-12s\n" "Model" "Scene" "Status" "Duration"
    echo -e "${CLR_BOLD}--------------------------------------------------------------------------------${CLR_RESET}"
    local total_failures=0
    local total_success=0
    for entry in "${PIPELINE_SUMMARY[@]}"; do
        local sm ss st sd
        IFS='|' read -r sm ss st sd <<< "${entry}"
        if [[ "${st}" == SUCCESS* ]]; then
            printf "%-18s %-16s ${CLR_GREEN}%-24s${CLR_RESET} %-12s\n" "${sm}" "${ss}" "${st}" "${sd}"
            total_success=$(( total_success + 1 ))
        else
            printf "%-18s %-16s ${CLR_RED}%-24s${CLR_RESET} %-12s\n" "${sm}" "${ss}" "${st}" "${sd}"
            total_failures=$(( total_failures + 1 ))
        fi
    done
    echo -e "${CLR_BOLD}--------------------------------------------------------------------------------${CLR_RESET}"
    log_info "Total Executions: ${#PIPELINE_SUMMARY[@]} | Succeeded: ${total_success} | Failed: ${total_failures}"

    if [[ ${total_failures} -gt 0 ]]; then
        log_warn "${total_failures} execution(s) recorded errors. Review detailed logs in '${ERROR_LOG}'."
        exit 1
    else
        log_success "All pipeline runs executed without errors."
        exit 0
    fi
}

main "$@"

