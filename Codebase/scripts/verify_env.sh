#!/usr/bin/env bash
# ==============================================================================
# Codebase/scripts/verify_env.sh
# ------------------------------------------------------------------------------
# Pre-execution Test Suite & Pre-flight Diagnostics
#
# Validates system prerequisites before training 3D Gaussian Splatting (3DGS)
# and Online Scene Change Detection (OSCD) models:
#   1. GPU Availability (NVIDIA driver, device presence, CUDA capability)
#   2. Isolated Conda Environments (colmap_runner, depth_anything, seasplat_py310,
#      3d-uir, gaussianSplashing_env, water_splatting, rusplatting, UW-GS,
#      sugar, oscd, 3dgs)
#   3. Dataset Structure & Image Counts (Submerged3D and OSCD layout)
#   4. Required System Binaries (colmap, ffmpeg, git, python3)
#
# Exit Codes:
#   0: All requested checks passed successfully
#   1: GPU check failed (missing nvidia-smi, driver, or device)
#   2: Conda environment missing or damaged
#   3: Dataset path or format invalid / empty
#   4: Required command or system dependency missing
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Color and Logging Utilities
# ------------------------------------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    CLR_RESET=$'\033[0m'
    CLR_RED=$'\033[1;31m'
    CLR_GREEN=$'\033[1;32m'
    CLR_YELLOW=$'\033[1;33m'
    CLR_BLUE=$'\033[1;34m'
    CLR_BOLD=$'\033[1m'
else
    CLR_RESET=""
    CLR_RED=""
    CLR_GREEN=""
    CLR_YELLOW=""
    CLR_BLUE=""
    CLR_BOLD=""
fi

QUIET=false

log_info() {
    if [[ "${QUIET}" != "true" ]]; then
        echo "${CLR_BLUE}[INFO]${CLR_RESET} $*"
    fi
}

log_success() {
    if [[ "${QUIET}" != "true" ]]; then
        echo "${CLR_GREEN}[SUCCESS]${CLR_RESET} $*"
    fi
}

log_warn() {
    if [[ "${QUIET}" != "true" ]]; then
        echo "${CLR_YELLOW}[WARN]${CLR_RESET} $*" >&2
    fi
}

log_error() {
    echo "${CLR_RED}[ERROR]${CLR_RESET} $*" >&2
}

# ------------------------------------------------------------------------------
# Path and Configuration Initialization
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CODEBASE_DIR="${REPO_ROOT}/Codebase"
DEFAULT_DATASET_DIR="${CODEBASE_DIR}/Dataset/Submerged3D"

# Master list of all 11 isolated Conda environments
REQUIRED_CONDA_ENVS=(
    "colmap_runner"
    "depth_anything"
    "seasplat_py310"
    "3d-uir"
    "gaussianSplashing_env"
    "water_splatting"
    "rusplatting"
    "UW-GS"
    "sugar"
    "oscd"
    "3dgs"
)

# ------------------------------------------------------------------------------
# CLI Help and Usage Documentation
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
${CLR_BOLD}Usage:${CLR_RESET} verify_env.sh [OPTIONS]

Pre-flight verification suite for 3D Gaussian Splatting & OSCD pipelines.
Performs pre-execution diagnostics across GPU, Conda, datasets, and tools.

${CLR_BOLD}Options:${CLR_RESET}
  -h, --help            Show this help message and exit (status 0)
  -q, --quiet           Suppress informational messages, output only errors
  --skip-gpu            Skip NVIDIA GPU and driver verification
  --check-gpu           Explicitly enforce GPU verification (default)
  --env <name>          Verify a specific Conda environment (e.g. seasplat_py310, oscd)
  --all-envs            Verify all 11 required Conda environments
  --dataset <path>      Validate dataset directory layout (Submerged3D or OSCD format)

${CLR_BOLD}Exit Codes:${CLR_RESET}
  0  All requested checks passed successfully
  1  GPU check failed (no NVIDIA GPU, driver missing, or nvidia-smi error)
  2  Conda environment missing or damaged
  3  Dataset path or format invalid or empty
  4  Missing required system tool (colmap, ffmpeg, git, python3)

${CLR_BOLD}Examples:${CLR_RESET}
  verify_env.sh                                # Run all standard checks
  verify_env.sh --skip-gpu                     # Run checks without requiring an NVIDIA GPU
  verify_env.sh --env oscd                     # Verify only the 'oscd' Conda environment
  verify_env.sh --dataset Codebase/Dataset/Submerged3D/Cormoran
EOF
}

# ------------------------------------------------------------------------------
# Check 1: GPU Availability & Compute Capability
# ------------------------------------------------------------------------------
check_gpu_availability() {
    log_info "Verifying NVIDIA GPU availability and driver status..."

    if ! command -v nvidia-smi >/dev/null 2>&1; then
        log_error "NVIDIA system management interface ('nvidia-smi') was not found in PATH."
        log_error "An NVIDIA GPU (e.g. RTX 5070 Ti) and proprietary NVIDIA drivers are required for 3DGS training."
        log_error "Action required: Run './Codebase/scripts/setup_env.sh --drivers' (or 'sudo ubuntu-drivers autoinstall') and reboot."
        log_error "If running in CI or on a host without GPU, pass '--skip-gpu'."
        return 1
    fi

    # Query device listing to ensure driver is communicating with hardware
    local gpu_list
    if ! gpu_list="$(nvidia-smi -L 2>&1)"; then
        log_error "'nvidia-smi' failed to communicate with NVIDIA kernel driver:"
        log_error "${gpu_list}"
        log_error "Action required: Verify driver installation with 'setup_env.sh --drivers' and reboot."
        return 1
    fi

    # Extract GPU model, driver version, and CUDA version
    local gpu_name driver_ver cuda_ver
    gpu_name="$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | head -n 1 || echo "")"
    if [[ -z "${gpu_name}" ]]; then
        gpu_name="$(echo "${gpu_list}" | head -n 1)"
    fi

    driver_ver="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n 1 || echo "unknown")"
    cuda_ver="$(nvidia-smi 2>/dev/null | grep -o 'CUDA Version: [0-9.]*' | awk '{print $3}' || echo "unknown")"

    log_success "NVIDIA GPU verified: ${gpu_name} (Driver: ${driver_ver}, CUDA Version: ${cuda_ver})"
    return 0
}

# ------------------------------------------------------------------------------
# Check 2: Conda Installation & Environment Verification
# ------------------------------------------------------------------------------
resolve_conda_binary() {
    if [[ -n "${CONDA_EXE:-}" && -x "${CONDA_EXE}" ]]; then
        echo "${CONDA_EXE}"
    elif command -v conda >/dev/null 2>&1; then
        command -v conda
    elif [[ -x "${HOME}/miniconda3/bin/conda" ]]; then
        echo "${HOME}/miniconda3/bin/conda"
    elif [[ -x "${HOME}/anaconda3/bin/conda" ]]; then
        echo "${HOME}/anaconda3/bin/conda"
    elif [[ -x "${HOME}/.conda/bin/conda" ]]; then
        echo "${HOME}/.conda/bin/conda"
    elif [[ -x "/opt/conda/bin/conda" ]]; then
        echo "/opt/conda/bin/conda"
    elif [[ -x "/opt/miniconda3/bin/conda" ]]; then
        echo "/opt/miniconda3/bin/conda"
    else
        return 1
    fi
}

get_installed_conda_envs() {
    local conda_bin="$1"
    local raw_envs=""
    raw_envs="$("${conda_bin}" env list 2>/dev/null || true)"

    # Parse first column, skipping comments and blank lines
    echo "${raw_envs}" | awk '{print $1}' | grep -v '^#' | grep -v '^$' || true
}

check_single_conda_env() {
    local target_env="$1"
    local conda_bin
    conda_bin="$(resolve_conda_binary)" || {
        log_error "Conda installation not found. Neither 'conda' in PATH nor '~/miniconda3' was detected."
        log_error "Action required: Run './Codebase/scripts/setup_env.sh --conda' to install Miniconda3."
        return 2
    }

    log_info "Checking Conda environment: '${target_env}'..."

    local installed_envs
    installed_envs="$(get_installed_conda_envs "${conda_bin}")"

    if echo "${installed_envs}" | grep -Fxq "${target_env}"; then
        log_success "Conda environment '${target_env}' is present and verified."
        return 0
    fi

    # Fallback check: test if env directory exists in conda base envs
    local conda_base
    conda_base="$("${conda_bin}" info --base 2>/dev/null || dirname "$(dirname "${conda_bin}")")"
    if [[ -d "${conda_base}/envs/${target_env}" ]]; then
        log_success "Conda environment '${target_env}' directory exists at: ${conda_base}/envs/${target_env}"
        return 0
    fi

    log_error "Required Conda environment '${target_env}' is missing."
    log_error "Action required: Run './Codebase/scripts/setup_env.sh --env ${target_env}' to provision this environment."
    return 2
}

check_all_conda_envs() {
    local conda_bin
    conda_bin="$(resolve_conda_binary)" || {
        log_error "Conda installation not found. Neither 'conda' in PATH nor '~/miniconda3' was detected."
        log_error "Action required: Run './Codebase/scripts/setup_env.sh' to install Miniconda and all environments."
        return 2
    }

    log_info "Verifying all ${#REQUIRED_CONDA_ENVS[@]} required Conda environments..."

    local installed_envs
    installed_envs="$(get_installed_conda_envs "${conda_bin}")"

    local conda_base
    conda_base="$("${conda_bin}" info --base 2>/dev/null || dirname "$(dirname "${conda_bin}")")"

    local missing_envs=()

    for env_name in "${REQUIRED_CONDA_ENVS[@]}"; do
        if echo "${installed_envs}" | grep -Fxq "${env_name}"; then
            continue
        fi
        if [[ -d "${conda_base}/envs/${env_name}" ]]; then
            continue
        fi
        missing_envs+=("${env_name}")
    done

    if [[ ${#missing_envs[@]} -gt 0 ]]; then
        log_error "The following ${#missing_envs[@]} required Conda environment(s) are missing:"
        for missing in "${missing_envs[@]}"; do
            echo "  ${CLR_RED}✗${CLR_RESET} ${missing}" >&2
        done
        log_error "Action required: Run './Codebase/scripts/setup_env.sh' to provision missing environments, or './Codebase/scripts/setup_env.sh --env <name>' for an individual environment."
        return 2
    fi

    log_success "All environments verified: All ${#REQUIRED_CONDA_ENVS[@]} required Conda environments are installed (OK)."
    for env_name in "${REQUIRED_CONDA_ENVS[@]}"; do
        if [[ "${QUIET}" != "true" ]]; then
            echo "  ${CLR_GREEN}✓${CLR_RESET} ${env_name}"
        fi
    done
    return 0
}

# ------------------------------------------------------------------------------
# Check 3: Dataset Structure & Image File Diagnostics
# ------------------------------------------------------------------------------
count_images_in_dir() {
    local target_dir="$1"
    if [[ ! -d "${target_dir}" ]]; then
        echo 0
        return
    fi
    find "${target_dir}" -maxdepth 1 -type f \( \
        -name "*.jpg" -o -name "*.JPG" -o \
        -name "*.jpeg" -o -name "*.JPEG" -o \
        -name "*.png" -o -name "*.PNG" \
    \) 2>/dev/null | wc -l
}

validate_scene_dir() {
    local scene_dir="$1"
    local scene_label
    scene_label="$(basename "${scene_dir}")"

    local img_dir=""
    if [[ -d "${scene_dir}/input" ]]; then
        img_dir="${scene_dir}/input"
    elif [[ -d "${scene_dir}/images" ]]; then
        img_dir="${scene_dir}/images"
    else
        log_error "Scene '${scene_label}' at '${scene_dir}' lacks required 'input/' or 'images/' directory."
        return 3
    fi

    local img_count
    img_count="$(count_images_in_dir "${img_dir}")"
    if [[ "${img_count}" -eq 0 ]]; then
        log_error "Scene '${scene_label}' directory '${img_dir}' contains zero image files (.jpg, .jpeg, .png)."
        return 3
    fi

    log_success "Dataset valid: Scene '${scene_label}' valid: ${img_count} image(s) in $(basename "${img_dir}")/"
    return 0
}

validate_dataset_path() {
    local target_path="$1"
    log_info "Validating dataset structure at: ${target_path}"

    if [[ ! -e "${target_path}" ]]; then
        log_error "Dataset path does not exist: '${target_path}'"
        return 3
    fi

    if [[ ! -d "${target_path}" ]]; then
        log_error "Dataset path is not a directory: '${target_path}'"
        return 3
    fi

    # Case A: OSCD Dataset Format (contains reference_scene and/or inference_scene)
    if [[ -d "${target_path}/reference_scene" || -d "${target_path}/inference_scene" ]]; then
        log_info "Detected OSCD dataset layout at: ${target_path}"
        local oscd_valid=true

        if [[ ! -d "${target_path}/reference_scene" ]]; then
            log_error "OSCD dataset missing required 'reference_scene' subdirectory at: ${target_path}/reference_scene"
            oscd_valid=false
        else
            validate_scene_dir "${target_path}/reference_scene" || oscd_valid=false
        fi

        if [[ ! -d "${target_path}/inference_scene" ]]; then
            log_error "OSCD dataset missing required 'inference_scene' subdirectory at: ${target_path}/inference_scene"
            oscd_valid=false
        else
            validate_scene_dir "${target_path}/inference_scene" || oscd_valid=false
        fi

        if [[ "${oscd_valid}" != "true" ]]; then
            return 3
        fi
        log_success "Dataset valid: OSCD dataset structure verified successfully: ${target_path}"
        return 0
    fi

    # Case B: Single Scene Directory (contains input/ or images/)
    if [[ -d "${target_path}/input" || -d "${target_path}/images" ]]; then
        validate_scene_dir "${target_path}" || return 3
        return 0
    fi

    # Case C: Benchmark Root Directory (e.g. Submerged3D with multiple scenes)
    local subdirs=()
    while IFS= read -r dir_entry; do
        if [[ -n "${dir_entry}" ]]; then
            subdirs+=("${dir_entry}")
        fi
    done < <(find "${target_path}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)

    if [[ ${#subdirs[@]} -eq 0 ]]; then
        log_error "Dataset directory '${target_path}' is empty and contains no scene subdirectories or images."
        return 3
    fi

    local scenes_found=0
    local scene_failures=0
    for subdir in "${subdirs[@]}"; do
        if [[ -d "${subdir}/input" || -d "${subdir}/images" ]]; then
            scenes_found=$((scenes_found + 1))
            if ! validate_scene_dir "${subdir}"; then
                scene_failures=$((scene_failures + 1))
            fi
        fi
    done

    if [[ ${scenes_found} -eq 0 ]]; then
        log_error "Dataset directory '${target_path}' does not contain valid scene structures (expected 'input/' or 'images/' with pictures)."
        return 3
    fi

    if [[ ${scene_failures} -gt 0 ]]; then
        log_error "${scene_failures} of ${scenes_found} scenes failed validation in '${target_path}'."
        return 3
    fi

    log_success "Dataset valid: ${scenes_found} valid scene(s) under '${target_path}' (Submerged3D format)."
    return 0
}

# ------------------------------------------------------------------------------
# Check 4: Required Tools and System Binaries
# ------------------------------------------------------------------------------
check_required_tools() {
    local tools=("colmap" "ffmpeg" "git" "python3")
    log_info "Verifying required command-line tools: ${tools[*]}..."

    local missing_tools=()
    for tool in "${tools[@]}"; do
        if command -v "${tool}" >/dev/null 2>&1; then
            local tool_path
            tool_path="$(command -v "${tool}")"
            log_success "Found system tool: ${tool} (${tool_path})"
        else
            log_error "Required system tool missing: '${tool}'"
            missing_tools+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing ${#missing_tools[@]} required system tool(s): ${missing_tools[*]}"
        log_error "Action required: Run './Codebase/scripts/setup_env.sh --system-deps' (or 'sudo apt-get install -y ${missing_tools[*]}')."
        return 4
    fi

    log_success "All required system tools are available."
    return 0
}

# ------------------------------------------------------------------------------
# Main Entry Point & CLI Parser
# ------------------------------------------------------------------------------
main() {
    local opt_skip_gpu=false
    local opt_check_gpu=false
    local opt_target_env=""
    local opt_all_envs=false
    local opt_target_dataset=""

    # Argument parsing
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --skip-gpu)
                opt_skip_gpu=true
                shift
                ;;
            --check-gpu)
                opt_check_gpu=true
                shift
                ;;
            --env)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--env' requires a non-empty environment name argument."
                    exit 1
                fi
                opt_target_env="$2"
                shift 2
                ;;
            --all-envs)
                opt_all_envs=true
                shift
                ;;
            --dataset)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--dataset' requires a valid directory path argument."
                    exit 1
                fi
                opt_target_dataset="$2"
                shift 2
                ;;
            *)
                log_error "Unrecognized command-line argument: '$1'"
                echo "" >&2
                show_help >&2
                exit 1
                ;;
        esac
    done

    # Determine execution mode: targeted check vs. full pre-flight suite
    local has_targeted_check=false
    if [[ -n "${opt_target_env}" || -n "${opt_target_dataset}" || "${opt_all_envs}" == "true" ]]; then
        has_targeted_check=true
    fi

    # 1. GPU Check Execution
    # Run GPU check if:
    #   - opt_check_gpu is explicitly set
    #   - OR (no targeted checks were requested AND opt_skip_gpu is false)
    if [[ "${opt_check_gpu}" == "true" ]]; then
        check_gpu_availability || exit 1
    elif [[ "${has_targeted_check}" != "true" && "${opt_skip_gpu}" != "true" ]]; then
        check_gpu_availability || exit 1
    elif [[ "${opt_skip_gpu}" == "true" ]]; then
        log_info "GPU check skipped (--skip-gpu specified)."
    fi

    # 2. Conda Environment Check Execution
    if [[ -n "${opt_target_env}" ]]; then
        check_single_conda_env "${opt_target_env}" || exit 2
    elif [[ "${opt_all_envs}" == "true" || "${has_targeted_check}" != "true" ]]; then
        check_all_conda_envs || exit 2
    fi

    # 3. Dataset Check Execution
    if [[ -n "${opt_target_dataset}" ]]; then
        validate_dataset_path "${opt_target_dataset}" || exit 3
    elif [[ "${has_targeted_check}" != "true" ]]; then
        if [[ -d "${DEFAULT_DATASET_DIR}" ]]; then
            validate_dataset_path "${DEFAULT_DATASET_DIR}" || exit 3
        else
            log_warn "Default benchmark dataset not found at '${DEFAULT_DATASET_DIR}'. Skipping default dataset check."
        fi
    fi

    # 4. Required Tools & Binaries Check Execution
    if [[ "${has_targeted_check}" != "true" ]]; then
        check_required_tools || exit 4
    fi

    log_success "All requested pre-flight verification checks passed successfully."
    exit 0
}

main "$@"
