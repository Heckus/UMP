#!/usr/bin/env bash
# ==============================================================================
# setup_env.sh - Automated Environment Setup for 3DGS & OSCD
#
# Provisions system packages, NVIDIA drivers, Miniconda, Git submodules,
# and isolated Conda environments for all 3D Gaussian Splatting and
# Online Scene Change Detection models.
#
# Fully compliant with ShellCheck (0.11.0+) with zero errors and zero warnings.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Dynamic Directory Resolution
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CODEBASE_DIR="${REPO_ROOT}/Codebase"
CONDA_DIR="${CONDA_DIR:-$HOME/miniconda3}"

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
# Error Handling Trap
# ------------------------------------------------------------------------------
error_trap() {
    local exit_code="$1"
    local line_num="$2"
    local cmd="$3"
    if [[ "${exit_code}" -ne 0 ]]; then
        log_error "Command failed with status ${exit_code} at line ${line_num}: '${cmd}'"
    fi
}
trap 'error_trap $? $LINENO "$BASH_COMMAND"' ERR

# ------------------------------------------------------------------------------
# CLI State Flags
# ------------------------------------------------------------------------------
DRY_RUN=false
YES_MODE=false
DO_ALL=false
DO_SYSTEM_DEPS=false
DO_DRIVERS=false
DO_CONDA=false
TARGET_ENV=""

# ------------------------------------------------------------------------------
# Help and Usage Documentation
# ------------------------------------------------------------------------------
show_help() {
    cat << 'EOF'
Usage: setup_env.sh [OPTIONS]

Automated Environment Setup for 3D Gaussian Splatting & Online Scene Change Detection

Options:
  -h, --help            Show this help message and exit
  --all                 Run complete setup (system deps, drivers, miniconda, and all conda environments)
  --system-deps         Install Ubuntu system packages (apt-get) only
  --drivers             Install NVIDIA proprietary drivers via ubuntu-drivers autoinstall
  --conda               Install / bootstrap Miniconda3 to ~/miniconda3
  --env <name>          Provision a specific isolated Conda environment
  --dry-run             Print planned installation commands and actions without executing
  -y, --yes             Non-interactive mode (auto-accept confirmation prompts)

Available Conda Environments:
  colmap_runner         Python 3.9   COLMAP convert.py runner
  depth_anything        Python 3.10  Depth-Anything-V2 ViT-L depth estimation & weights
  seasplat_py310        Python 3.10  SeaSplat physics-based underwater 3DGS
  3d-uir                Python 3.10  3D-UIR image restoration with depth priors & tiny-cuda-nn
  gaussianSplashing_env Python 3.10  Gaussian Splashing direct volumetric rendering (HYB)
  water_splatting       Python 3.8   WaterSplatting Nerfstudio framework (CUDA 11.8)
  rusplatting           Python 3.12  RUSplatting sparse-view underwater 3DGS (PyTorch 2.5.1)
  UW-GS                 Python 3.7   Underwater 3DGS (Linux-sanitized recipe, PyTorch 1.12.1)
  sugar                 Python 3.9   SuGaR surface mesh extraction (PyTorch 2.0.1, PyTorch3D)
  oscd                  Python 3.12  Online Scene Change Detection (PyTorch cu121, CuPy, Viser)
  3dgs                  Python 3.10  Reference 3DGS reconstruction (Kerbl et al., 2023)

Examples:
  ./setup_env.sh --help
  ./setup_env.sh --dry-run
  ./setup_env.sh --dry-run --env seasplat_py310
  ./setup_env.sh --system-deps -y
  ./setup_env.sh --env oscd -y
  ./setup_env.sh --all -y
EOF
}

# ------------------------------------------------------------------------------
# Environment Name Normalization
# ------------------------------------------------------------------------------
normalize_env_name() {
    local raw="$1"
    local lower
    lower="$(echo "${raw}" | tr '[:upper:]' '[:lower:]')"
    case "${lower}" in
        colmap_runner|colmap) echo "colmap_runner" ;;
        depth_anything|depth-anything|depth_anything_v2) echo "depth_anything" ;;
        seasplat_py310|seasplat) echo "seasplat_py310" ;;
        3d-uir|3d_uir) echo "3d-uir" ;;
        gaussiansplashing_env|gaussiansplashing|gaussian_splashing) echo "gaussianSplashing_env" ;;
        water_splatting|watersplatting) echo "water_splatting" ;;
        rusplatting|ru_splatting) echo "rusplatting" ;;
        uw-gs|uw_gs) echo "UW-GS" ;;
        sugar) echo "sugar" ;;
        oscd|o-scd) echo "oscd" ;;
        3dgs|gaussian_splatting) echo "3dgs" ;;
        *) echo "${raw}" ;;
    esac
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
parse_args() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --all)
                DO_ALL=true
                shift
                ;;
            --system-deps)
                DO_SYSTEM_DEPS=true
                shift
                ;;
            --drivers)
                DO_DRIVERS=true
                shift
                ;;
            --conda)
                DO_CONDA=true
                shift
                ;;
            --env)
                if [[ $# -lt 2 ]]; then
                    log_error "Option --env requires an environment name."
                    exit 1
                fi
                TARGET_ENV="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -y|--yes)
                YES_MODE=true
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# User Confirmation
# ------------------------------------------------------------------------------
confirm_proceed() {
    if [[ "${YES_MODE}" == "true" ]] || [[ "${DRY_RUN}" == "true" ]]; then
        return 0
    fi
    printf "%bDo you wish to proceed with the planned setup? [y/N]: %b" "${CLR_YELLOW}" "${CLR_RESET}"
    local response
    read -r response
    case "${response}" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *)
            log_info "Operation cancelled by user."
            exit 0
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Command Execution Wrapper
# ------------------------------------------------------------------------------
get_conda_exe() {
    if command -v conda >/dev/null 2>&1; then
        command -v conda
    elif [[ -x "${CONDA_DIR}/bin/conda" ]]; then
        echo "${CONDA_DIR}/bin/conda"
    elif [[ -x "$HOME/miniconda3/bin/conda" ]]; then
        echo "$HOME/miniconda3/bin/conda"
    elif [[ -x "$HOME/anaconda3/bin/conda" ]]; then
        echo "$HOME/anaconda3/bin/conda"
    elif [[ -x "/opt/conda/bin/conda" ]]; then
        echo "/opt/conda/bin/conda"
    else
        return 1
    fi
}

run_cmd() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "$*"
    else
        log_info "Running: $*"
        if [[ "$1" == "conda" ]]; then
            local conda_bin
            conda_bin="$(get_conda_exe 2>/dev/null || echo "conda")"
            shift
            "${conda_bin}" "$@"
        else
            "$@"
        fi
    fi
}

# ------------------------------------------------------------------------------
# Safe Conda Activation Under `set -u`
# ------------------------------------------------------------------------------
activate_env() {
    local env_name="$1"
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "conda activate ${env_name}"
        return 0
    fi
    local conda_bin
    conda_bin="$(get_conda_exe)" || {
        log_error "Cannot activate ${env_name}: Conda executable not found."
        return 1
    }
    set +u
    # Evaluate shell hook safely without unbound variable errors
    # shellcheck disable=SC1090
    eval "$("${conda_bin}" shell.bash hook 2>/dev/null || conda shell.bash hook)"
    conda activate "${env_name}"
    set -u
    log_info "Active environment: ${env_name}"
}

deactivate_env() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "conda deactivate"
        return 0
    fi
    set +u
    conda deactivate 2>/dev/null || true
    set -u
}

# ------------------------------------------------------------------------------
# Submodule Repair Helpers
# ------------------------------------------------------------------------------
ensure_submodule() {
    local target_dir="$1"
    local repo_url="$2"
    local branch="${3:-}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Verify submodule: ${target_dir} (source: ${repo_url})"
        return 0
    fi

    if [[ -d "${target_dir}" ]] && { [[ -f "${target_dir}/setup.py" ]] || [[ -f "${target_dir}/CMakeLists.txt" ]] || [[ -d "${target_dir}/.git" ]]; }; then
        log_info "Submodule verified: $(basename "$(dirname "${target_dir}")")/$(basename "${target_dir}")"
        return 0
    fi

    log_warn "Submodule empty or unpopulated at ${target_dir}. Cloning from ${repo_url}..."
    rm -rf "${target_dir}"
    mkdir -p "$(dirname "${target_dir}")"
    if [[ -n "${branch}" ]]; then
        git clone --depth 1 -b "${branch}" "${repo_url}" "${target_dir}" || \
        git clone "${repo_url}" "${target_dir}"
    else
        git clone --depth 1 "${repo_url}" "${target_dir}" || \
        git clone "${repo_url}" "${target_dir}"
    fi
    log_success "Submodule cloned into ${target_dir}."
}

ensure_submodule_with_fallback() {
    local target_dir="$1"
    local primary_url="$2"
    local fallback_url="$3"
    local branch="${4:-}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Verify submodule: ${target_dir} (primary: ${primary_url}, fallback: ${fallback_url})"
        return 0
    fi

    if [[ -d "${target_dir}" ]] && { [[ -f "${target_dir}/setup.py" ]] || [[ -f "${target_dir}/CMakeLists.txt" ]] || [[ -d "${target_dir}/.git" ]]; }; then
        log_info "Submodule verified: $(basename "$(dirname "${target_dir}")")/$(basename "${target_dir}")"
        return 0
    fi

    log_warn "Submodule empty or unpopulated at ${target_dir}. Cloning from ${primary_url}..."
    rm -rf "${target_dir}"
    mkdir -p "$(dirname "${target_dir}")"
    if [[ -n "${branch}" ]]; then
        if ! git clone --depth 1 -b "${branch}" "${primary_url}" "${target_dir}"; then
            log_warn "Primary clone failed. Retrying with fallback: ${fallback_url}..."
            git clone --depth 1 -b "${branch}" "${fallback_url}" "${target_dir}" || \
            git clone "${fallback_url}" "${target_dir}"
        fi
    else
        if ! git clone --depth 1 "${primary_url}" "${target_dir}"; then
            log_warn "Primary clone failed. Retrying with fallback: ${fallback_url}..."
            git clone --depth 1 "${fallback_url}" "${target_dir}" || \
            git clone "${fallback_url}" "${target_dir}"
        fi
    fi
    log_success "Submodule cloned into ${target_dir}."
}

# ------------------------------------------------------------------------------
# 1. System Dependencies Provisioning
# ------------------------------------------------------------------------------
install_system_deps() {
    log_section "System Dependencies Provisioning (Ubuntu APT)"
    local packages=(
        build-essential
        colmap
        ffmpeg
        git
        wget
        curl
        cmake
        ninja-build
        libgl1-mesa-glx
        libglib2.0-0
    )

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "sudo apt-get update"
        log_dry "sudo apt-get install -y ${packages[*]}"
        return 0
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        log_warn "apt-get not found on this system ($(uname -s) / $(uname -m))."
        log_warn "Please ensure equivalent packages are installed manually:"
        log_warn "  ${packages[*]}"
        return 0
    fi

    local sudo_cmd=()
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo_cmd=("sudo")
        else
            log_error "Root privileges or sudo required to install apt packages."
            return 1
        fi
    fi

    log_info "Updating package index..."
    "${sudo_cmd[@]}" apt-get update -y
    log_info "Installing system dependencies: ${packages[*]}..."
    "${sudo_cmd[@]}" apt-get install -y "${packages[@]}"
    log_success "System dependencies successfully installed."
}

# ------------------------------------------------------------------------------
# 2. NVIDIA Proprietary Driver Provisioning
# ------------------------------------------------------------------------------
install_nvidia_drivers() {
    log_section "NVIDIA Proprietary Drivers Provisioning"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Check NVIDIA GPU presence via lspci / nvidia-smi"
        log_dry "sudo ubuntu-drivers autoinstall"
        return 0
    fi

    if command -v nvidia-smi >/dev/null 2>&1; then
        log_success "NVIDIA driver is active and functional:"
        nvidia-smi --query-gpu=gpu_name,driver_version --format=csv,noheader || true
        return 0
    fi

    if ! command -v ubuntu-drivers >/dev/null 2>&1; then
        log_warn "'ubuntu-drivers' tool not found. Skipping automated driver installation."
        log_warn "If running on Ubuntu, install via: sudo apt install -y ubuntu-drivers-common"
        return 0
    fi

    local sudo_cmd=()
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo_cmd=("sudo")
        else
            log_error "Root privileges or sudo required to install drivers."
            return 1
        fi
    fi

    log_info "Detecting and installing recommended NVIDIA proprietary drivers..."
    "${sudo_cmd[@]}" ubuntu-drivers autoinstall
    log_success "NVIDIA driver installation completed. A system reboot may be required."
}

# ------------------------------------------------------------------------------
# 3. Miniconda3 Bootstrap
# ------------------------------------------------------------------------------
install_miniconda() {
    log_section "Miniconda3 Bootstrap"
    local target_dir="${CONDA_DIR}"
    local installer_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    local installer_tmp="/tmp/miniconda_installer_$$.sh"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Check if conda exists in PATH or ${target_dir}"
        log_dry "wget -O ${installer_tmp} ${installer_url}"
        log_dry "bash ${installer_tmp} -b -u -p ${target_dir}"
        log_dry "${target_dir}/bin/conda init bash"
        return 0
    fi

    if command -v conda >/dev/null 2>&1; then
        log_success "Conda is already available in PATH: $(command -v conda)"
        return 0
    fi

    if [[ -x "${target_dir}/bin/conda" ]]; then
        log_success "Miniconda found at ${target_dir}/bin/conda."
        "${target_dir}/bin/conda" init bash || true
        return 0
    fi

    log_info "Downloading Miniconda3 installer from ${installer_url}..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "${installer_tmp}" "${installer_url}"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "${installer_tmp}" "${installer_url}"
    else
        log_error "Neither curl nor wget available to download Miniconda."
        return 1
    fi

    log_info "Executing silent Miniconda3 installation to ${target_dir}..."
    bash "${installer_tmp}" -b -u -p "${target_dir}"
    rm -f "${installer_tmp}"

    log_info "Initializing Conda for Bash..."
    "${target_dir}/bin/conda" init bash || true
    log_success "Miniconda3 successfully installed to ${target_dir}."
}

# ------------------------------------------------------------------------------
# 4. Master Submodule Verification & Repair
# ------------------------------------------------------------------------------
ensure_all_submodules() {
    log_section "Verifying and Repairing Submodules Across Codebase"
    local seasplat_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Physics/seasplat-master/submodules"
    local gs_splashing_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Image/gaussianSplashing-main/submodules"
    local tools_gs_dir="${CODEBASE_DIR}/Tools/gaussian-splatting-main/submodules"
    local uir_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Physics/3D-UIR-main/submodules"
    local rusplat_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Additional/RUSplatting-main/submodules"
    local uwgs_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Additional/UW-GS-main/submodules"
    local sugar_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Additional/SuGaR-main/gaussian_splatting/submodules"
    local oscd_dir="${CODEBASE_DIR}/3DGS-Change-Detection/O-SCD-main/submodules"

    ensure_submodule "${seasplat_dir}/diff-gaussian-rasterization" "https://github.com/dxyang/diff-gaussian-rasterization"
    ensure_submodule_with_fallback "${seasplat_dir}/simple-knn" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    ensure_submodule "${gs_splashing_dir}/diff-gaussian-rasterization_UW" "https://github.com/BGU-CS-VIL/diff-gaussian-rasterization_UW.git"
    ensure_submodule_with_fallback "${gs_splashing_dir}/simple-knn" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    ensure_submodule "${tools_gs_dir}/diff-gaussian-rasterization" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule_with_fallback "${tools_gs_dir}/simple-knn" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"
    ensure_submodule "${tools_gs_dir}/fused-ssim" "https://github.com/rahul-goel/fused-ssim.git"

    ensure_submodule "${uir_dir}/diff-gaussian-rasterization" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule_with_fallback "${uir_dir}/simple-knn" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"
    ensure_submodule "${uir_dir}/fused-ssim" "https://github.com/rahul-goel/fused-ssim.git"

    ensure_submodule "${rusplat_dir}/diff-gaussian-rasterization" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule_with_fallback "${rusplat_dir}/simple-knn" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    ensure_submodule "${uwgs_dir}/diff-gaussian-rasterization" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule_with_fallback "${uwgs_dir}/simple-knn" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    ensure_submodule "${sugar_dir}/diff-gaussian-rasterization" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule_with_fallback "${sugar_dir}/simple-knn" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    ensure_submodule "${oscd_dir}/diff-gaussian-rasterization" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule "${oscd_dir}/diff-gaussian-rasterization_fastgs" "https://github.com/Chumsy0725/diff-gaussian-rasterization_fastgs.git"
    ensure_submodule "${oscd_dir}/fused-ssim" "https://github.com/rahul-goel/fused-ssim.git"
    ensure_submodule_with_fallback "${oscd_dir}/simple-knn" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    log_success "All submodule checks completed."
}

# ------------------------------------------------------------------------------
# 5. Conda Environment Provisioning Recipes
# ------------------------------------------------------------------------------

# Recipe 1: colmap_runner
setup_colmap_runner() {
    log_section "Provisioning Conda Environment: colmap_runner (Python 3.9)"
    run_cmd conda create -n colmap_runner python=3.9 -y
    activate_env colmap_runner
    run_cmd pip install --upgrade pip
    run_cmd pip install tqdm
    deactivate_env
    log_success "Environment 'colmap_runner' successfully provisioned."
}

# Recipe 2: depth_anything
setup_depth_anything() {
    log_section "Provisioning Conda Environment: depth_anything (Python 3.10)"
    local tool_dir="${CODEBASE_DIR}/Tools/Depth-Anything-V2-main"
    local chk_dir="${tool_dir}/checkpoints"
    local chk_file="${chk_dir}/depth_anything_v2_vitl.pth"
    local chk_url="https://huggingface.co/depth-anything/Depth-Anything-V2-Large/resolve/main/depth_anything_v2_vitl.pth?download=true"

    run_cmd conda create -n depth_anything python=3.10 -y
    activate_env depth_anything
    run_cmd pip install --upgrade pip
    run_cmd pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
    if [[ -f "${tool_dir}/requirements.txt" ]]; then
        run_cmd pip install -r "${tool_dir}/requirements.txt"
    else
        run_cmd pip install gradio gradio_imageslider matplotlib opencv-python
    fi
    deactivate_env

    # Checkpoint provisioning
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "mkdir -p ${chk_dir}"
        log_dry "wget -O ${chk_file} \"${chk_url}\""
    else
        mkdir -p "${chk_dir}"
        if [[ ! -f "${chk_file}" ]]; then
            log_info "Downloading Depth-Anything-V2 ViT-L checkpoint to ${chk_file}..."
            if command -v curl >/dev/null 2>&1; then
                curl -L -o "${chk_file}" "${chk_url}"
            elif command -v wget >/dev/null 2>&1; then
                wget -O "${chk_file}" "${chk_url}"
            else
                log_warn "Neither curl nor wget available. Please download ${chk_url} to ${chk_file} manually."
            fi
        else
            log_info "Depth-Anything-V2 checkpoint verified at ${chk_file}."
        fi
    fi
    log_success "Environment 'depth_anything' successfully provisioned."
}

# Recipe 3: seasplat_py310
setup_seasplat_py310() {
    log_section "Provisioning Conda Environment: seasplat_py310 (Python 3.10)"
    local repo_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Physics/seasplat-master"
    local sub_diff="${repo_dir}/submodules/diff-gaussian-rasterization"
    local sub_knn="${repo_dir}/submodules/simple-knn"

    ensure_submodule "${sub_diff}" "https://github.com/dxyang/diff-gaussian-rasterization"
    ensure_submodule_with_fallback "${sub_knn}" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    run_cmd conda create -n seasplat_py310 python=3.10 -y
    activate_env seasplat_py310
    run_cmd pip install --upgrade pip
    run_cmd pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    run_cmd pip install plyfile==0.8.1 tqdm opencv-python scipy ninja matplotlib
    run_cmd pip install "${sub_diff}"
    run_cmd pip install "${sub_knn}"
    deactivate_env
    log_success "Environment 'seasplat_py310' successfully provisioned."
}

# Recipe 4: 3d-uir
setup_3d_uir() {
    log_section "Provisioning Conda Environment: 3d-uir (Python 3.10)"
    local repo_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Physics/3D-UIR-main"
    local sub_diff="${repo_dir}/submodules/diff-gaussian-rasterization"
    local sub_knn="${repo_dir}/submodules/simple-knn"
    local sub_ssim="${repo_dir}/submodules/fused-ssim"

    ensure_submodule "${sub_diff}" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule_with_fallback "${sub_knn}" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"
    ensure_submodule "${sub_ssim}" "https://github.com/rahul-goel/fused-ssim.git"

    run_cmd conda create -n 3d-uir python=3.10 -y
    run_cmd conda install -y -n 3d-uir -c conda-forge cudatoolkit-dev=11.8
    activate_env 3d-uir
    run_cmd pip install --upgrade pip
    run_cmd pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
    run_cmd pip install plyfile tqdm opencv-python joblib ninja
    run_cmd pip install "${sub_diff}"
    run_cmd pip install "${sub_knn}"
    run_cmd pip install "${sub_ssim}"
    run_cmd pip install ninja git+https://github.com/NVlabs/tiny-cuda-nn/#subdirectory=bindings/torch
    deactivate_env
    log_success "Environment '3d-uir' successfully provisioned."
}

# Recipe 5: gaussianSplashing_env
setup_gaussianSplashing_env() {
    log_section "Provisioning Conda Environment: gaussianSplashing_env (Python 3.10)"
    local repo_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Image/gaussianSplashing-main"
    local sub_diff="${repo_dir}/submodules/diff-gaussian-rasterization_UW"
    local sub_knn="${repo_dir}/submodules/simple-knn"

    ensure_submodule "${sub_diff}" "https://github.com/BGU-CS-VIL/diff-gaussian-rasterization_UW.git"
    ensure_submodule_with_fallback "${sub_knn}" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    run_cmd conda create -n gaussianSplashing_env python=3.10 -y
    run_cmd conda install -y -n gaussianSplashing_env -c conda-forge plyfile=0.8.1 tqdm
    activate_env gaussianSplashing_env
    run_cmd pip install --upgrade pip
    run_cmd pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    run_cmd pip install matplotlib wandb timm scikit-learn pdc-dp-means opencv-python pyyaml
    run_cmd pip install "${sub_diff}"
    run_cmd pip install "${sub_knn}"
    deactivate_env
    log_success "Environment 'gaussianSplashing_env' successfully provisioned."
}

# Recipe 6: water_splatting
setup_water_splatting() {
    log_section "Provisioning Conda Environment: water_splatting (Python 3.8, Nerfstudio)"
    local repo_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Image/water-splatting-main"

    run_cmd conda create -n water_splatting python=3.8 -y
    run_cmd conda install -y -n water_splatting -c "nvidia/label/cuda-11.8.0" cuda-toolkit
    activate_env water_splatting
    run_cmd pip install --upgrade pip
    run_cmd pip install torch==2.1.2+cu118 torchvision==0.16.2+cu118 --extra-index-url https://download.pytorch.org/whl/cu118
    run_cmd pip install ninja git+https://github.com/NVlabs/tiny-cuda-nn/#subdirectory=bindings/torch
    run_cmd pip install nerfstudio==1.1.4
    run_cmd ns-install-cli
    run_cmd pip install --no-use-pep517 -e "${repo_dir}"
    deactivate_env
    log_success "Environment 'water_splatting' successfully provisioned."
}

# Recipe 7: rusplatting
setup_rusplatting() {
    log_section "Provisioning Conda Environment: rusplatting (Python 3.12, PyTorch 2.5.1)"
    local repo_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Additional/RUSplatting-main"
    local sub_diff="${repo_dir}/submodules/diff-gaussian-rasterization"
    local sub_knn="${repo_dir}/submodules/simple-knn"

    ensure_submodule "${sub_diff}" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule_with_fallback "${sub_knn}" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    run_cmd conda create -n rusplatting python=3.12 -y
    activate_env rusplatting
    run_cmd pip install --upgrade pip
    run_cmd pip install torch==2.5.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
    run_cmd pip install plyfile tqdm opencv-python joblib scipy imageio imageio-ffmpeg dearpygui lpips
    run_cmd pip install "${sub_diff}"
    run_cmd pip install "${sub_knn}"
    deactivate_env
    log_success "Environment 'rusplatting' successfully provisioned."
}

# Recipe 8: UW-GS
setup_UW_GS() {
    log_section "Provisioning Conda Environment: UW-GS (Python 3.7, Linux Sanitized Recipe)"
    local repo_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Additional/UW-GS-main"
    local sub_diff="${repo_dir}/submodules/diff-gaussian-rasterization"
    local sub_knn="${repo_dir}/submodules/simple-knn"

    ensure_submodule "${sub_diff}" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule_with_fallback "${sub_knn}" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    log_info "Creating UW-GS environment (omitting Windows mkl/vc dependencies)..."
    run_cmd conda create -n UW-GS python=3.7 -y
    activate_env UW-GS
    run_cmd pip install --upgrade pip
    run_cmd pip install torch==1.12.1+cu116 torchvision==0.13.1+cu116 torchaudio==0.12.1 --extra-index-url https://download.pytorch.org/whl/cu116
    run_cmd pip install plyfile==0.8.1 tqdm imageio==2.27.0 opencv-python imageio-ffmpeg scipy dearpygui lpips
    run_cmd pip install "${sub_diff}"
    run_cmd pip install "${sub_knn}"
    deactivate_env
    log_success "Environment 'UW-GS' successfully provisioned."
}

# Recipe 9: sugar
setup_sugar() {
    log_section "Provisioning Conda Environment: sugar (Python 3.9, PyTorch 2.0.1, PyTorch3D)"
    local repo_dir="${CODEBASE_DIR}/3DGS-Water-Approaches/Additional/SuGaR-main"
    local sub_diff="${repo_dir}/gaussian_splatting/submodules/diff-gaussian-rasterization"
    local sub_knn="${repo_dir}/gaussian_splatting/submodules/simple-knn"

    ensure_submodule "${sub_diff}" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule_with_fallback "${sub_knn}" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    run_cmd conda create -n sugar python=3.9 -y
    run_cmd conda install -y -n sugar pytorch=2.0.1 torchvision=0.15.2 torchaudio=2.0.2 pytorch-cuda=11.8 -c pytorch -c nvidia
    run_cmd conda install -y -n sugar -c fvcore -c iopath -c conda-forge fvcore iopath
    run_cmd conda install -y -n sugar -c pytorch3d pytorch3d==0.7.4
    activate_env sugar
    run_cmd pip install --upgrade pip
    run_cmd pip install open3d PyMCubes plyfile==0.8.1 rich plotly
    run_cmd pip install "${sub_diff}"
    run_cmd pip install "${sub_knn}"
    deactivate_env
    log_success "Environment 'sugar' successfully provisioned."
}

# Recipe 10: oscd
setup_oscd() {
    log_section "Provisioning Conda Environment: oscd (Python 3.12, PyTorch cu121, CuPy, Viser)"
    local repo_dir="${CODEBASE_DIR}/3DGS-Change-Detection/O-SCD-main"
    local sub_diff="${repo_dir}/submodules/diff-gaussian-rasterization"
    local sub_fastgs="${repo_dir}/submodules/diff-gaussian-rasterization_fastgs"
    local sub_ssim="${repo_dir}/submodules/fused-ssim"
    local sub_knn="${repo_dir}/submodules/simple-knn"

    ensure_submodule "${sub_diff}" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule "${sub_fastgs}" "https://github.com/Chumsy0725/diff-gaussian-rasterization_fastgs.git"
    ensure_submodule "${sub_ssim}" "https://github.com/rahul-goel/fused-ssim.git"
    ensure_submodule_with_fallback "${sub_knn}" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"

    run_cmd conda create -n oscd python=3.12 -y
    activate_env oscd
    run_cmd pip install --upgrade pip
    run_cmd pip install torch torchvision xformers --index-url https://download.pytorch.org/whl/cu121
    run_cmd pip install cupy-cuda12x
    run_cmd pip install plyfile tqdm opencv-python lpips transformers==4.56.1 torchmetrics viser
    run_cmd pip install "${sub_fastgs}"
    run_cmd pip install "${sub_ssim}"
    run_cmd pip install "${sub_knn}"
    deactivate_env
    log_success "Environment 'oscd' successfully provisioned."
}

# Recipe 11: 3dgs
setup_3dgs() {
    log_section "Provisioning Conda Environment: 3dgs (Python 3.10, PyTorch cu121)"
    local repo_dir="${CODEBASE_DIR}/Tools/gaussian-splatting-main"
    local sub_diff="${repo_dir}/submodules/diff-gaussian-rasterization"
    local sub_knn="${repo_dir}/submodules/simple-knn"
    local sub_ssim="${repo_dir}/submodules/fused-ssim"

    ensure_submodule "${sub_diff}" "https://github.com/graphdeco-inria/diff-gaussian-rasterization.git"
    ensure_submodule_with_fallback "${sub_knn}" "https://gitlab.inria.fr/bkerbl/simple-knn.git" "https://github.com/camenduru/simple-knn.git"
    ensure_submodule "${sub_ssim}" "https://github.com/rahul-goel/fused-ssim.git"

    run_cmd conda create -n 3dgs python=3.10 -y
    activate_env 3dgs
    run_cmd pip install --upgrade pip
    run_cmd pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    run_cmd pip install plyfile tqdm opencv-python joblib
    run_cmd pip install "${sub_diff}"
    run_cmd pip install "${sub_knn}"
    run_cmd pip install "${sub_ssim}"
    deactivate_env
    log_success "Environment '3dgs' successfully provisioned."
}

# ------------------------------------------------------------------------------
# Dispatch Single Environment Provisioning
# ------------------------------------------------------------------------------
provision_single_env() {
    local env_name="$1"
    local norm_name
    norm_name="$(normalize_env_name "${env_name}")"

    case "${norm_name}" in
        colmap_runner)
            setup_colmap_runner
            ;;
        depth_anything)
            setup_depth_anything
            ;;
        seasplat_py310)
            setup_seasplat_py310
            ;;
        3d-uir)
            setup_3d_uir
            ;;
        gaussianSplashing_env)
            setup_gaussianSplashing_env
            ;;
        water_splatting)
            setup_water_splatting
            ;;
        rusplatting)
            setup_rusplatting
            ;;
        UW-GS)
            setup_UW_GS
            ;;
        sugar)
            setup_sugar
            ;;
        oscd)
            setup_oscd
            ;;
        3dgs)
            setup_3dgs
            ;;
        *)
            log_error "Unknown environment: ${env_name}"
            log_error "Valid environments:"
            log_error "  colmap_runner, depth_anything, seasplat_py310, 3d-uir,"
            log_error "  gaussianSplashing_env, water_splatting, rusplatting, UW-GS,"
            log_error "  sugar, oscd, 3dgs"
            exit 1
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Master Setup Execution
# ------------------------------------------------------------------------------
provision_all_environments() {
    log_section "Provisioning All 11 Isolated Conda Environments"
    setup_colmap_runner
    setup_depth_anything
    setup_seasplat_py310
    setup_3d_uir
    setup_gaussianSplashing_env
    setup_water_splatting
    setup_rusplatting
    setup_UW_GS
    setup_sugar
    setup_oscd
    setup_3dgs
    log_success "All 11 Conda environments successfully provisioned."
}

# ------------------------------------------------------------------------------
# Main Execution Entry Point
# ------------------------------------------------------------------------------
main() {
    parse_args "$@"

    # If --dry-run was requested without specific target, default to --all
    if [[ "${DRY_RUN}" == "true" ]] && [[ "${DO_ALL}" == "false" ]] && \
       [[ "${DO_SYSTEM_DEPS}" == "false" ]] && [[ "${DO_DRIVERS}" == "false" ]] && \
       [[ "${DO_CONDA}" == "false" ]] && [[ -z "${TARGET_ENV}" ]]; then
        DO_ALL=true
    fi

    # Check that at least one action was requested
    if [[ "${DO_ALL}" == "false" ]] && [[ "${DO_SYSTEM_DEPS}" == "false" ]] && \
       [[ "${DO_DRIVERS}" == "false" ]] && [[ "${DO_CONDA}" == "false" ]] && \
       [[ -z "${TARGET_ENV}" ]]; then
        log_error "No action specified. Please specify --all, --env <name>, --system-deps, --drivers, or --conda."
        log_error "Use --help for usage details."
        exit 1
    fi

    log_info "3DGS & OSCD Automation Setup Script Initialized"
    log_info "Repository root: ${REPO_ROOT}"
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY-RUN MODE ACTIVE: No files or environments will be modified."
    fi

    confirm_proceed

    # Execute specific component requests or complete pipeline
    if [[ "${DO_ALL}" == "true" ]]; then
        install_system_deps
        install_nvidia_drivers
        install_miniconda
        ensure_all_submodules
        provision_all_environments
    else
        if [[ "${DO_SYSTEM_DEPS}" == "true" ]]; then
            install_system_deps
        fi
        if [[ "${DO_DRIVERS}" == "true" ]]; then
            install_nvidia_drivers
        fi
        if [[ "${DO_CONDA}" == "true" ]]; then
            install_miniconda
        fi
        if [[ -n "${TARGET_ENV}" ]]; then
            provision_single_env "${TARGET_ENV}"
        fi
    fi

    log_section "Setup Execution Completed Successfully"
}

main "$@"
