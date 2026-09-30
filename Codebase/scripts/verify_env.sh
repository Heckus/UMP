#!/usr/bin/env bash
# ==============================================================================
# Codebase/scripts/verify_env.sh
# ------------------------------------------------------------------------------
# Pre-execution Test Suite & Pre-flight Diagnostics
#
# Validates system prerequisites before training 3D Gaussian Splatting (3DGS)
# and Online Scene Change Detection (OSCD) models:
#   1. GPU Availability (NVIDIA driver, device presence, VRAM, CUDA capability)
#   2. Isolated Conda Environments (colmap_runner, depth_anything, seasplat_py310,
#      3d-uir, gaussianSplashing_env, water_splatting, rusplatting, UW-GS,
#      sugar, oscd, 3dgs)
#   3. Deep Functional In-Environment Probes (PyTorch, CUDA acceleration, C++ extensions)
#   4. System Hardware & Storage Resources (CPU cores, RAM, workdir/home/tmp disk space)
#   5. Required System Binaries (colmap, ffmpeg, git, python3)
#   6. Git Submodules Integrity (diff-gaussian-rasterization, simple-knn, fused-ssim, glm, etc.)
#   7. Dataset Structure & Image Counts (Submerged3D and OSCD layout)
#
# Exit Codes:
#   0: All requested checks passed successfully
#   1: GPU check failed (missing nvidia-smi, driver, or device)
#   2: Conda environment missing or damaged (failed deep functional probe)
#   3: Dataset path or format invalid / empty
#   4: Required command, system dependency, or submodule missing
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
    CLR_CYAN=$'\033[1;36m'
    CLR_BOLD=$'\033[1m'
else
    CLR_RESET=""
    CLR_RED=""
    CLR_GREEN=""
    CLR_YELLOW=""
    CLR_BLUE=""
    CLR_CYAN=""
    CLR_BOLD=""
fi

QUIET=false
DEEP_CHECK=false
SYSTEM_CHECK=false
CHECK_TOOLS=false
CHECK_SUBMODULES=false

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

log_section() {
    if [[ "${QUIET}" != "true" ]]; then
        echo ""
        echo "${CLR_BOLD}${CLR_CYAN}======================================================================${CLR_RESET}"
        echo "${CLR_BOLD}${CLR_CYAN} $*${CLR_RESET}"
        echo "${CLR_BOLD}${CLR_CYAN}======================================================================${CLR_RESET}"
    fi
}

# ------------------------------------------------------------------------------
# Path and Configuration Initialization
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CODEBASE_DIR="${REPO_ROOT}/Codebase"
DEFAULT_DATASET_DIR="${REPO_ROOT}/Dataset/Submerged3D"

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
  --deep                Execute in-environment Python/PyTorch/CUDA probes and C++ extension checks
  --system              Display system hardware, RAM, and disk storage diagnostics
  --check-tools         Verify presence and versions of system binaries (colmap, ffmpeg, git, python3)
  --check-submodules    Verify presence and non-emptiness of required git submodules
  --dataset <path>      Validate dataset directory layout (Submerged3D or OSCD format)

${CLR_BOLD}Exit Codes:${CLR_RESET}
  0  All requested checks passed successfully
  1  GPU check failed (no NVIDIA GPU, driver missing, or nvidia-smi error)
  2  Conda environment missing or damaged (failed deep functional probe)
  3  Dataset path or format invalid or empty
  4  Missing required system tool or uninitialized submodule

${CLR_BOLD}Examples:${CLR_RESET}
  verify_env.sh                                # Standard pre-flight check
  verify_env.sh --skip-gpu                     # Run checks without requiring an NVIDIA GPU
  verify_env.sh --env oscd                     # Verify only the 'oscd' Conda environment
  verify_env.sh --all-envs --deep              # Deep functional validation of all 11 environments
  verify_env.sh --system --check-submodules    # System diagnostics and submodule check
EOF
}

# ------------------------------------------------------------------------------
# Check: System Hardware & Storage Resources
# ------------------------------------------------------------------------------
check_system_resources() {
    log_section "System Hardware & Storage Diagnostics"

    local hostname_str cpu_count mem_info
    hostname_str="$(hostname 2>/dev/null || echo "localhost")"
    cpu_count="$(nproc 2>/dev/null || echo "unknown")"
    mem_info="$(free -h 2>/dev/null | awk '/^Mem:/ {print $2 " total, " $7 " available"}' || echo "unknown")"

    echo "  ${CLR_BOLD}Host:${CLR_RESET}           ${hostname_str}"
    if [[ -n "${PBS_JOBID:-}" ]]; then
        echo "  ${CLR_BOLD}PBS Job ID:${CLR_RESET}     ${PBS_JOBID} (Queue: ${PBS_QUEUE:-unknown})"
    fi
    echo "  ${CLR_BOLD}CPU Cores:${CLR_RESET}      ${cpu_count}"
    echo "  ${CLR_BOLD}System RAM:${CLR_RESET}     ${mem_info}"

    # Disk space check
    log_info "Verifying Storage Space across critical paths..."
    local paths_to_check=("." "${HOME}" "/tmp")
    for p in "${paths_to_check[@]}"; do
        if [[ -d "${p}" ]]; then
            local df_out avail_gb
            df_out="$(df -h "${p}" 2>/dev/null | awk 'NR==2 {print $4 " available (" $5 " used on " $6 ")"}')"
            avail_gb="$(df -BG "${p}" 2>/dev/null | awk 'NR==2 {gsub(/G/,"",$4); print $4}')"
            if [[ -n "${avail_gb}" && "${avail_gb}" =~ ^[0-9]+$ && "${avail_gb}" -lt 15 ]]; then
                log_warn "Low disk space on '${p}': only ${df_out}!"
            else
                echo "  ${CLR_GREEN}✓${CLR_RESET} Storage [${p}]: ${df_out}"
            fi
        fi
    done
    return 0
}

# ------------------------------------------------------------------------------
# Check 1: GPU Availability & Compute Capability
# ------------------------------------------------------------------------------
check_gpu_availability() {
    log_info "Verifying NVIDIA GPU availability and driver status..."

    if ! command -v nvidia-smi >/dev/null 2>&1; then
        log_error "NVIDIA system management interface ('nvidia-smi') was not found in PATH."
        log_error "An NVIDIA GPU (e.g. RTX 5070 Ti, H100) and proprietary NVIDIA drivers are required for 3DGS training."
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

    # Extract GPU model, driver version, CUDA version, VRAM, and compute capability
    local gpu_name driver_ver cuda_ver vram_info="" compute_cap=""
    gpu_name="$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | head -n 1 || echo "")"
    if [[ -z "${gpu_name}" ]]; then
        gpu_name="$(echo "${gpu_list}" | head -n 1)"
    fi

    driver_ver="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n 1 || echo "unknown")"
    cuda_ver="$(nvidia-smi 2>/dev/null | grep -o 'CUDA Version: [0-9.]*' | awk '{print $3}' || echo "unknown")"
    vram_info="$(nvidia-smi --query-gpu=memory.total,memory.free --format=csv,noheader 2>/dev/null | head -n 1 || echo "")"
    compute_cap="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -n 1 || echo "")"

    local extra_str=""
    if [[ -n "${vram_info}" ]]; then
        extra_str=" | VRAM: ${vram_info}"
    fi
    if [[ -n "${compute_cap}" ]]; then
        extra_str="${extra_str} | Compute Cap: ${compute_cap}"
    fi

    log_success "NVIDIA GPU verified: ${gpu_name} (Driver: ${driver_ver}, CUDA Version: ${cuda_ver}${extra_str})"

    # Check CUDA compiler (nvcc) if available
    if command -v nvcc >/dev/null 2>&1; then
        local nvcc_rel
        nvcc_rel="$(nvcc --version 2>/dev/null | grep -o 'release [0-9.]*' || echo "")"
        log_info "CUDA Compiler (nvcc): ${nvcc_rel} (CUDA_HOME=${CUDA_HOME:-not set})"
    fi

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

resolve_env_python() {
    local conda_bin="$1"
    local env_name="$2"
    local conda_base
    conda_base="$("${conda_bin}" info --base 2>/dev/null || dirname "$(dirname "${conda_bin}")")"

    if [[ -x "${HOME}/.conda/envs/${env_name}/bin/python" ]]; then
        echo "${HOME}/.conda/envs/${env_name}/bin/python"
    elif [[ -x "${conda_base}/envs/${env_name}/bin/python" ]]; then
        echo "${conda_base}/envs/${env_name}/bin/python"
    elif [[ -n "${USER:-}" && -x "/mnt/hpccs01/home/${USER}/.conda/envs/${env_name}/bin/python" ]]; then
        echo "/mnt/hpccs01/home/${USER}/.conda/envs/${env_name}/bin/python"
    else
        echo ""
    fi
}

get_env_required_extensions() {
    local env_name="$1"
    case "${env_name}" in
        colmap_runner)
            echo "sqlite3 tqdm"
            ;;
        depth_anything)
            echo "torch torchvision cv2 PIL"
            ;;
        seasplat_py310)
            echo "torch plyfile diff_gaussian_rasterization"
            ;;
        3d-uir)
            echo "torch diff_gaussian_rasterization simple_knn cv2"
            ;;
        gaussianSplashing_env)
            echo "torch plyfile diff_gaussian_rasterization"
            ;;
        water_splatting)
            echo "torch nerfstudio water_splatting"
            ;;
        rusplatting)
            echo "torch diff_gaussian_rasterization simple_knn lpips"
            ;;
        UW-GS)
            echo "torch diff_gaussian_rasterization simple_knn"
            ;;
        sugar)
            echo "torch pytorch3d diff_gaussian_rasterization open3d"
            ;;
        oscd)
            echo "torch cupy diff_gaussian_rasterization_fastgs viser"
            ;;
        3dgs)
            echo "torch diff_gaussian_rasterization simple_knn fused_ssim"
            ;;
        *)
            echo "torch"
            ;;
    esac
}

run_deep_env_check() {
    local conda_bin="$1"
    local env_name="$2"
    local skip_gpu="${3:-false}"
    local env_py
    env_py="$(resolve_env_python "${conda_bin}" "${env_name}")"

    local req_exts
    req_exts="$(get_env_required_extensions "${env_name}")"

    # Embedded python diagnostic probe
    local probe_script='
import sys

env_name = sys.argv[1]
req_exts = sys.argv[2].split()
skip_gpu = (sys.argv[3] == "true")
is_colmap = (env_name == "colmap_runner")

py_ver = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
torch_ver = "N/A"
cuda_str = "N/A"

missing_exts = []
for ext in req_exts:
    try:
        __import__(ext)
    except Exception as e:
        missing_exts.append(f"{ext} ({e})")

if missing_exts:
    ext_list = ", ".join(missing_exts)
    print(f"FAIL|Python {py_ver}|Missing extensions: {ext_list}")
    sys.exit(1)

if not is_colmap:
    import torch
    torch_ver = torch.__version__
    if not skip_gpu:
        if not torch.cuda.is_available():
            print(f"FAIL|Python {py_ver}, Torch {torch_ver}|CUDA is NOT available in PyTorch")
            sys.exit(2)
        try:
            gpu_name = torch.cuda.get_device_name(0)
            t = torch.zeros(1, device="cuda")
            cuda_str = f"CUDA OK ({gpu_name})"
        except Exception as e:
            print(f"FAIL|Python {py_ver}, Torch {torch_ver}|CUDA tensor allocation failed: {e}")
            sys.exit(3)
    else:
        cuda_str = "CUDA skipped (--skip-gpu)"
else:
    cuda_str = "CPU only (colmap)"

print(f"OK|Python {py_ver}|Torch {torch_ver}|{cuda_str}|Extensions: OK")
'

    local probe_output probe_rc=0
    if [[ -n "${env_py}" && -x "${env_py}" ]]; then
        probe_output="$("${env_py}" -c "${probe_script}" "${env_name}" "${req_exts}" "${skip_gpu}" 2>&1)" || probe_rc=$?
    else
        probe_output="$("${conda_bin}" run -n "${env_name}" python -c "${probe_script}" "${env_name}" "${req_exts}" "${skip_gpu}" 2>&1)" || probe_rc=$?
    fi

    local status_line
    status_line="$(echo "${probe_output}" | grep -E '^(OK|FAIL)\|' | tail -n 1)"

    if [[ ${probe_rc} -eq 0 && "${status_line}" == OK* ]]; then
        IFS='|' read -r _status _py _torch _cuda _ext <<< "${status_line}"
        echo "  ${CLR_GREEN}✓${CLR_RESET} ${CLR_BOLD}${env_name}${CLR_RESET}: ${_py} | ${_torch} | ${_cuda} | ${_ext}"
        return 0
    else
        echo "  ${CLR_RED}✗${CLR_RESET} ${CLR_BOLD}${env_name}${CLR_RESET}: Deep functional probe FAILED" >&2
        echo "    ${CLR_RED}${probe_output}${CLR_RESET}" >&2
        return 2
    fi
}

check_single_conda_env() {
    local target_env="$1"
    local skip_gpu="${2:-false}"
    local conda_bin
    conda_bin="$(resolve_conda_binary)" || {
        log_error "Conda installation not found. Neither 'conda' in PATH nor '~/miniconda3' was detected."
        log_error "Action required: Run './Codebase/scripts/setup_env.sh --conda' to install Miniconda3."
        return 2
    }

    log_info "Checking Conda environment: '${target_env}'..."

    local installed_envs
    installed_envs="$(get_installed_conda_envs "${conda_bin}")"

    local env_found=false
    if echo "${installed_envs}" | grep -Fxq "${target_env}"; then
        env_found=true
    fi

    # Fallback checks: test if env directory exists
    local conda_base
    conda_base="$("${conda_bin}" info --base 2>/dev/null || dirname "$(dirname "${conda_bin}")")"
    if [[ "${env_found}" != "true" ]]; then
        if [[ -d "${HOME}/.conda/envs/${target_env}" || -d "${conda_base}/envs/${target_env}" ]]; then
            env_found=true
        fi
    fi

    if [[ "${env_found}" != "true" ]]; then
        log_error "Required Conda environment '${target_env}' is missing."
        log_error "Action required: Run './Codebase/scripts/setup_env.sh --env ${target_env}' to provision this environment."
        return 2
    fi

    if [[ "${DEEP_CHECK}" == "true" ]]; then
        run_deep_env_check "${conda_bin}" "${target_env}" "${skip_gpu}" || return 2
    else
        log_success "Conda environment '${target_env}' is present and verified."
    fi

    return 0
}

check_all_conda_envs() {
    local skip_gpu="${1:-false}"
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
        if [[ -d "${HOME}/.conda/envs/${env_name}" || -d "${conda_base}/envs/${env_name}" ]]; then
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

    # If --deep was requested, perform in-environment functional probes
    if [[ "${DEEP_CHECK}" == "true" ]]; then
        log_info "Executing deep functional probes (PyTorch, CUDA, C++ extensions)..."
        local failed_deep=0
        for env_name in "${REQUIRED_CONDA_ENVS[@]}"; do
            if ! run_deep_env_check "${conda_bin}" "${env_name}" "${skip_gpu}"; then
                failed_deep=$((failed_deep + 1))
            fi
        done

        if [[ ${failed_deep} -gt 0 ]]; then
            log_error "${failed_deep} of ${#REQUIRED_CONDA_ENVS[@]} environment(s) failed deep functional verification."
            return 2
        fi
        log_success "All ${#REQUIRED_CONDA_ENVS[@]} environments passed deep functional verification."
    fi

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
            local tool_path tool_ver=""
            tool_path="$(command -v "${tool}")"
            case "${tool}" in
                colmap)
                    tool_ver="$(colmap -h 2>&1 | head -n 1 | grep -o 'COLMAP [0-9.]*' || echo "")"
                    ;;
                ffmpeg)
                    tool_ver="$(ffmpeg -version 2>&1 | head -n 1 | grep -o 'ffmpeg version [^ ]*' || echo "")"
                    ;;
                git)
                    tool_ver="$(git --version 2>&1 | head -n 1 || echo "")"
                    ;;
                python3)
                    tool_ver="$(python3 --version 2>&1 | head -n 1 || echo "")"
                    ;;
            esac
            log_success "Found system tool: ${tool} (${tool_path}${tool_ver:+ - ${tool_ver}})"
        else
            log_error "Required system tool missing: '${tool}'"
            missing_tools+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing ${#missing_tools[@]} required system tool(s): ${missing_tools[*]}"
        log_error "Action required: Run './Codebase/scripts/setup_env.sh --system-deps' (or ensure global_tools environment is provisioned and in PATH)."
        return 4
    fi

    log_success "All required system tools are available."

    # Checkpoint check for Depth-Anything-V2 ViT-L
    local chk_vitl="${REPO_ROOT}/Codebase/Tools/Depth-Anything-V2-main/checkpoints/depth_anything_v2_vitl.pth"
    if [[ -s "${chk_vitl}" ]]; then
        local ckpt_sz
        ckpt_sz="$(du -h "${chk_vitl}" 2>/dev/null | cut -f1 || echo "present")"
        log_success "Depth-Anything-V2 Large checkpoint: ${chk_vitl} (${ckpt_sz})"
        RECORD_REPORT "Depth-Anything-V2 Weights" "PASSED" "${ckpt_sz}"
    else
        log_warn "Depth-Anything-V2 Large checkpoint not found at ${chk_vitl} (run_pipeline.sh will auto-download)"
        RECORD_REPORT "Depth-Anything-V2 Weights" "NOTICE" "Missing (auto-download on run)"
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Check 5: Git Submodules Integrity
# ------------------------------------------------------------------------------
check_submodules_integrity() {
    log_info "Verifying git submodules integrity across all models..."

    local submodules=(
        "Codebase/Tools/gaussian-splatting-main/submodules/diff-gaussian-rasterization"
        "Codebase/Tools/gaussian-splatting-main/submodules/simple-knn"
        "Codebase/Tools/gaussian-splatting-main/submodules/fused-ssim"
        "Codebase/3DGS-Water-Approaches/Image/water-splatting-main/water_splatting/cuda/csrc/third_party/glm"
        "Codebase/3DGS-Water-Approaches/Additional/RUSplatting-main/submodules/diff-gaussian-rasterization"
        "Codebase/3DGS-Water-Approaches/Additional/RUSplatting-main/submodules/simple-knn"
        "Codebase/3DGS-Water-Approaches/Additional/UW-GS-main/submodules/diff-gaussian-rasterization"
        "Codebase/3DGS-Water-Approaches/Additional/UW-GS-main/submodules/simple-knn"
        "Codebase/3DGS-Water-Approaches/Additional/SuGaR-main/gaussian_splatting/submodules/diff-gaussian-rasterization"
        "Codebase/3DGS-Water-Approaches/Additional/SuGaR-main/gaussian_splatting/submodules/simple-knn"
        "Codebase/3DGS-Change-Detection/O-SCD-main/submodules/diff-gaussian-rasterization_fastgs"
        "Codebase/3DGS-Change-Detection/O-SCD-main/submodules/fused-ssim"
    )

    local missing=0
    for sub in "${submodules[@]}"; do
        local full_path="${REPO_ROOT}/${sub}"
        if [[ -d "${full_path}" ]] && [[ $(find "${full_path}" -maxdepth 2 -type f 2>/dev/null | head -n 1) ]]; then
            if [[ "${QUIET}" != "true" ]]; then
                echo "  ${CLR_GREEN}✓${CLR_RESET} Submodule: $(basename "$(dirname "${sub}")")/$(basename "${sub}")"
            fi
        else
            log_error "Submodule missing or uninitialized: ${sub}"
            missing=$((missing + 1))
        fi
    done

    if [[ ${missing} -gt 0 ]]; then
        log_error "${missing} submodule(s) missing or empty. Action: run 'git submodule update --init --recursive'"
        return 4
    fi

    log_success "All ${#submodules[@]} git submodules are verified and populated."
    return 0
}

# ------------------------------------------------------------------------------
# Report Card Summary
# ------------------------------------------------------------------------------
print_report_card() {
    if [[ "${QUIET}" == "true" ]]; then
        return
    fi
    echo ""
    echo "${CLR_BOLD}${CLR_GREEN}======================================================================${CLR_RESET}"
    echo "${CLR_BOLD}${CLR_GREEN} Pre-Flight Diagnostics Summary: ALL REQUESTED CHECKS PASSED${CLR_RESET}"
    echo "${CLR_BOLD}${CLR_GREEN}======================================================================${CLR_RESET}"
    echo "  ${CLR_BOLD}System Status:${CLR_RESET}   Ready for pipeline execution"
    echo "  ${CLR_BOLD}Timestamp:${CLR_RESET}       $(date)"
    echo "${CLR_BOLD}${CLR_GREEN}======================================================================${CLR_RESET}"
    echo ""
}

# ------------------------------------------------------------------------------
# Main Entry Point & CLI Parser
# ------------------------------------------------------------------------------
main() {
    local opt_skip_gpu=false
    local opt_check_gpu=false
    local opt_target_envs=()
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
                opt_target_envs+=("$2")
                shift 2
                ;;
            --all-envs)
                opt_all_envs=true
                shift
                ;;
            --deep)
                DEEP_CHECK=true
                shift
                ;;
            --system)
                SYSTEM_CHECK=true
                shift
                ;;
            --check-tools)
                CHECK_TOOLS=true
                shift
                ;;
            --check-submodules)
                CHECK_SUBMODULES=true
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
    if [[ ${#opt_target_envs[@]} -gt 0 || -n "${opt_target_dataset}" || "${opt_all_envs}" == "true" || "${SYSTEM_CHECK}" == "true" || "${CHECK_TOOLS}" == "true" || "${CHECK_SUBMODULES}" == "true" ]]; then
        has_targeted_check=true
    fi

    # 1. System Resources Check Execution
    if [[ "${SYSTEM_CHECK}" == "true" ]]; then
        check_system_resources || true
    fi

    # 2. GPU Check Execution
    if [[ "${opt_check_gpu}" == "true" ]]; then
        check_gpu_availability || exit 1
    elif [[ "${has_targeted_check}" != "true" && "${opt_skip_gpu}" != "true" ]]; then
        check_gpu_availability || exit 1
    elif [[ "${opt_skip_gpu}" == "true" ]]; then
        log_info "GPU check skipped (--skip-gpu specified)."
    fi

    # 3. Conda Environment Check Execution
    if [[ ${#opt_target_envs[@]} -gt 0 ]]; then
        for env in "${opt_target_envs[@]}"; do
            check_single_conda_env "${env}" "${opt_skip_gpu}" || exit 2
        done
    elif [[ "${opt_all_envs}" == "true" || "${has_targeted_check}" != "true" ]]; then
        check_all_conda_envs "${opt_skip_gpu}" || exit 2
    fi

    # 4. Git Submodules Integrity Check Execution
    if [[ "${CHECK_SUBMODULES}" == "true" ]]; then
        check_submodules_integrity || exit 4
    fi

    # 5. Required Tools & Binaries Check Execution
    if [[ "${CHECK_TOOLS}" == "true" || "${has_targeted_check}" != "true" ]]; then
        check_required_tools || exit 4
    fi

    # 6. Dataset Check Execution
    if [[ -n "${opt_target_dataset}" ]]; then
        validate_dataset_path "${opt_target_dataset}" || exit 3
    elif [[ "${has_targeted_check}" != "true" ]]; then
        if [[ -d "${DEFAULT_DATASET_DIR}" ]]; then
            validate_dataset_path "${DEFAULT_DATASET_DIR}" || exit 3
        else
            log_warn "Default benchmark dataset not found at '${DEFAULT_DATASET_DIR}'. Skipping default dataset check."
        fi
    fi

    print_report_card
    exit 0
}

main "$@"
