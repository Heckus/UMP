#!/usr/bin/env bash
# ==============================================================================
# tests/e2e/mock_helpers.sh
# ------------------------------------------------------------------------------
# Hermetic Mocking, Test Fixtures, and Assertion Framework for E2E Tests
#
# Provides isolated temporary environments, mock binaries (nvidia-smi, conda,
# colmap, ubuntu-drivers), synthetic dataset trees, and assertion primitives.
# ==============================================================================

# Ensure strict bash mode is active when sourced or run
set -euo pipefail

# ANSI color codes for formatted test outputs (used across test scripts)
# shellcheck disable=SC2034
TEST_CLR_RESET="\033[0m"
# shellcheck disable=SC2034
TEST_CLR_RED="\033[1;31m"
# shellcheck disable=SC2034
TEST_CLR_GREEN="\033[1;32m"
# shellcheck disable=SC2034
TEST_CLR_YELLOW="\033[1;33m"
# shellcheck disable=SC2034
TEST_CLR_BLUE="\033[1;34m"
# shellcheck disable=SC2034
TEST_CLR_CYAN="\033[1;36m"
# shellcheck disable=SC2034
TEST_CLR_BOLD="\033[1m"

# Global test tracking metrics
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Sandbox environment paths
ORIGINAL_PATH="${PATH}"
CURRENT_SANDBOX=""
MOCK_BIN_DIR=""
MOCK_CONDA_BASE=""

# Command execution capture variables
# shellcheck disable=SC2034
CMD_OUTPUT=""
# shellcheck disable=SC2034
CMD_RC=0

# Execute command safely capturing output and exit code
run_and_capture() {
    set +e
    # shellcheck disable=SC2034
    CMD_OUTPUT="$("$@" </dev/null 2>&1)"
    # shellcheck disable=SC2034
    CMD_RC=$?
    set -e
    return 0
}

# ------------------------------------------------------------------------------
# Test Lifecycle Management
# ------------------------------------------------------------------------------

# Initialize an isolated test sandbox directory and mock execution paths
setup_test_sandbox() {
    local prefix="${1:-e2e_sandbox}"
    CURRENT_SANDBOX="$(mktemp -d "/tmp/${prefix}_XXXXXX")"
    MOCK_BIN_DIR="${CURRENT_SANDBOX}/mock_bin"
    MOCK_CONDA_BASE="${CURRENT_SANDBOX}/miniconda3"

    mkdir -p "${MOCK_BIN_DIR}"
    mkdir -p "${MOCK_CONDA_BASE}/etc/profile.d"
    mkdir -p "${MOCK_CONDA_BASE}/envs"

    # Prepend mock bin to PATH
    export PATH="${MOCK_BIN_DIR}:${ORIGINAL_PATH}"
    export HOME="${CURRENT_SANDBOX}/home"
    mkdir -p "${HOME}"
}

# Clean up sandbox environment and restore system state
teardown_test_sandbox() {
    export PATH="${ORIGINAL_PATH}"
    if [[ -n "${CURRENT_SANDBOX:-}" && -d "${CURRENT_SANDBOX}" ]]; then
        if [[ "${KEEP_TEMP:-0}" != "1" ]]; then
            rm -rf "${CURRENT_SANDBOX}"
        fi
    fi
    CURRENT_SANDBOX=""
    MOCK_BIN_DIR=""
    MOCK_CONDA_BASE=""
}

# Register an automated teardown trap on script exit
init_test_trap() {
    trap teardown_test_sandbox EXIT INT TERM
}

# ------------------------------------------------------------------------------
# Logging & Metric Reporting
# ------------------------------------------------------------------------------

log_test_info() {
    echo -e "${TEST_CLR_BLUE}[INFO]${TEST_CLR_RESET} $*"
}

log_test_success() {
    echo -e "${TEST_CLR_GREEN}[PASS]${TEST_CLR_RESET} $*"
}

log_test_fail() {
    echo -e "${TEST_CLR_RED}[FAIL]${TEST_CLR_RESET} $*" >&2
}

log_test_skip() {
    echo -e "${TEST_CLR_YELLOW}[SKIP]${TEST_CLR_RESET} $*"
}

record_pass() {
    local test_name="$1"
    local message="${2:-}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    if [[ -n "${message}" ]]; then
        echo -e "  ${TEST_CLR_GREEN}✓ PASS:${TEST_CLR_RESET} ${test_name} (${message})"
    else
        echo -e "  ${TEST_CLR_GREEN}✓ PASS:${TEST_CLR_RESET} ${test_name}"
    fi
}

record_fail() {
    local test_name="$1"
    local reason="${2:-assertion failed}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${TEST_CLR_RED}✗ FAIL:${TEST_CLR_RESET} ${test_name}" >&2
    echo -e "         ${TEST_CLR_RED}Reason:${TEST_CLR_RESET} ${reason}" >&2
}

record_skip() {
    local test_name="$1"
    local reason="${2:-not applicable}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo -e "  ${TEST_CLR_YELLOW}○ SKIP:${TEST_CLR_RESET} ${test_name} (${reason})"
}

print_suite_summary() {
    local suite_title="$1"
    echo ""
    echo -e "${TEST_CLR_BOLD}================================================================${TEST_CLR_RESET}"
    echo -e "${TEST_CLR_BOLD}Suite Summary: ${suite_title}${TEST_CLR_RESET}"
    echo -e "  Total Tests: ${TESTS_RUN}"
    echo -e "  ${TEST_CLR_GREEN}Passed:${TEST_CLR_RESET}      ${TESTS_PASSED}"
    echo -e "  ${TEST_CLR_RED}Failed:${TEST_CLR_RESET}      ${TESTS_FAILED}"
    echo -e "  ${TEST_CLR_YELLOW}Skipped:${TEST_CLR_RESET}     ${TESTS_SKIPPED}"
    echo -e "${TEST_CLR_BOLD}================================================================${TEST_CLR_RESET}"
    echo ""

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Assertion Functions
# ------------------------------------------------------------------------------

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [[ "${actual}" -eq "${expected}" ]]; then
        record_pass "${test_name}" "Exit code ${actual}"
        return 0
    else
        record_fail "${test_name}" "Expected exit code ${expected}, got ${actual}"
        return 1
    fi
}

assert_output_contains() {
    local pattern="$1"
    local content="$2"
    local test_name="$3"

    if grep -Ei "${pattern}" <<< "${content}" >/dev/null 2>&1; then
        record_pass "${test_name}" "Output matched regex: '${pattern}'"
        return 0
    else
        record_fail "${test_name}" "Expected output to match '${pattern}', but got:\n${content}"
        return 1
    fi
}

assert_output_not_contains() {
    local pattern="$1"
    local content="$2"
    local test_name="$3"

    if ! grep -Ei "${pattern}" <<< "${content}" >/dev/null 2>&1; then
        record_pass "${test_name}" "Output correctly omitted: '${pattern}'"
        return 0
    else
        record_fail "${test_name}" "Expected output to NOT contain '${pattern}', but found:\n${content}"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local test_name="$2"

    if [[ -e "${file_path}" ]]; then
        record_pass "${test_name}" "File/Dir exists: ${file_path}"
        return 0
    else
        record_fail "${test_name}" "Path does not exist: ${file_path}"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Mock Creation Functions
# ------------------------------------------------------------------------------

# Mock nvidia-smi with configurable behavior:
#   mode: "present" (default), "absent", or "failing"
#   gpu_name: (optional) e.g. "NVIDIA GeForce RTX 5070 Ti"
#   compute_cap: (optional) e.g. "12.0"
#   vram_mb: (optional) e.g. "16384"
mock_nvidia_smi() {
    local mode="${1:-present}"
    local gpu_name="${2:-NVIDIA GeForce RTX 5070 Ti}"
    local compute_cap="${3:-12.0}"
    local vram_mb="${4:-16384}"
    local target="${MOCK_BIN_DIR}/nvidia-smi"

    if [[ "${mode}" == "absent" ]]; then
        rm -f "${target}"
        return 0
    fi

    cat <<EOF > "${target}"
#!/usr/bin/env bash
if [[ "${mode}" == "failing" ]]; then
    echo "NVIDIA-SMI has failed because no driver was loaded or device is missing." >&2
    exit 1
fi

# Parse standard queries
for arg in "\$@"; do
    if [[ "\$arg" == "-L" ]] || [[ "\$arg" == "--list-gpus" ]]; then
        echo "GPU 0: ${gpu_name} (UUID: GPU-mock-uuid-0001)"
        exit 0
    elif [[ "\$arg" == *"--query-gpu=gpu_name"* ]]; then
        echo "${gpu_name}"
        exit 0
    elif [[ "\$arg" == *"--query-gpu=compute_cap"* ]]; then
        echo "${compute_cap}"
        exit 0
    elif [[ "\$arg" == *"--query-gpu=memory.total"* ]]; then
        echo "${vram_mb} MiB"
        exit 0
    fi
done

# Standard default banner output
echo "+-----------------------------------------------------------------------------------------+"
echo "| NVIDIA-SMI 570.86.16              Driver Version: 570.86.16      CUDA Version: 12.8     |"
echo "|-----------------------------------------+------------------------+----------------------+"
echo "| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |"
echo "| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |"
echo "|                                         |                        |               MIG M. |"
echo "|=========================================+========================+======================|"
echo "|   0  ${gpu_name}            Off |   00000000:01:00.0 Off |                  N/A |"
echo "|  0%   32C    P8              8W / 250W |       1MiB / ${vram_mb}MiB |      0%      Default |"
echo "+-----------------------------------------+------------------------+----------------------+"
exit 0
EOF
    chmod +x "${target}"
}

# Mock conda binary and conda shell profile
#   installed_envs: space-separated list of Conda environment names
mock_conda() {
    local envs_list="${1:-base}"
    local conda_bin="${MOCK_BIN_DIR}/conda"
    local conda_sh="${MOCK_CONDA_BASE}/etc/profile.d/conda.sh"
    local env_db="${CURRENT_SANDBOX}/.conda_envs"

    # Initialize environment database
    mkdir -p "$(dirname "${env_db}")"
    # Write installed envs line by line
    true > "${env_db}"
    echo "base" >> "${env_db}"
    for e in ${envs_list}; do
        if [[ "${e}" != "base" ]]; then
            echo "${e}" >> "${env_db}"
            mkdir -p "${MOCK_CONDA_BASE}/envs/${e}"
        fi
    done

    # Generate mock conda CLI
    cat <<EOF > "${conda_bin}"
#!/usr/bin/env bash
set -e
ENV_DB="${env_db}"
BASE_DIR="${MOCK_CONDA_BASE}"

case "\${1:-}" in
    info)
        case "\${2:-}" in
            --base)
                echo "\${BASE_DIR}"
                exit 0
                ;;
            --envs|-e)
                echo "# conda environments:"
                echo "#"
                while IFS= read -r env_name; do
                    if [[ "\$env_name" == "base" ]]; then
                        printf "%-25s *  %s\n" "\$env_name" "\${BASE_DIR}"
                    else
                        printf "%-25s    %s/envs/%s\n" "\$env_name" "\${BASE_DIR}" "\$env_name"
                    fi
                done < "\${ENV_DB}"
                exit 0
                ;;
            *)
                echo "conda-info mock output"
                exit 0
                ;;
        esac
        ;;
    env)
        if [[ "\${2:-}" == "list" ]]; then
            echo "# conda environments:"
            echo "#"
            while IFS= read -r env_name; do
                if [[ "\$env_name" == "base" ]]; then
                    printf "%-25s *  %s\n" "\$env_name" "\${BASE_DIR}"
                else
                    printf "%-25s    %s/envs/%s\n" "\$env_name" "\${BASE_DIR}" "\$env_name"
                fi
            done < "\${ENV_DB}"
            exit 0
        fi
        ;;
    activate)
        target_env="\${2:-}"
        if grep -Fxq "\${target_env}" "\${ENV_DB}"; then
            exit 0
        else
            echo "EnvironmentNameNotFound: Could not find environment: \${target_env}" >&2
            exit 1
        fi
        ;;
    create)
        # Scan for -n or --name
        while [[ \$# -gt 0 ]]; do
            case "\$1" in
                -n|--name)
                    shift
                    if [[ \$# -gt 0 ]]; then
                        new_env="\$1"
                        echo "\${new_env}" >> "\${ENV_DB}"
                        mkdir -p "\${BASE_DIR}/envs/\${new_env}"
                    fi
                    ;;
            esac
            shift
        done
        exit 0
        ;;
    --version|-V)
        echo "conda 24.11.0"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "${conda_bin}"

    # Generate mock conda shell sourcing hook
    cat <<EOF > "${conda_sh}"
# Mock conda.sh for subshell sourcing
conda() {
    "${conda_bin}" "\$@"
}
export -f conda 2>/dev/null || true
EOF
}

# Mock colmap binary
mock_colmap() {
    local mode="${1:-present}"
    local target="${MOCK_BIN_DIR}/colmap"

    if [[ "${mode}" == "absent" ]]; then
        rm -f "${target}"
        return 0
    fi

    cat <<'EOF' > "${target}"
#!/usr/bin/env bash
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "COLMAP 3.9.1 -- Structure-from-Motion and Multi-View Stereo"
    exit 0
fi
# Emulate successful feature extraction, matching, and mapping
echo "[MOCK COLMAP] Running $1 command..."
exit 0
EOF
    chmod +x "${target}"
}

# Mock ubuntu-drivers binary
mock_ubuntu_drivers() {
    local mode="${1:-present}"
    local target="${MOCK_BIN_DIR}/ubuntu-drivers"

    if [[ "${mode}" == "absent" ]]; then
        rm -f "${target}"
        return 0
    fi

    cat <<'EOF' > "${target}"
#!/usr/bin/env bash
case "$1" in
    devices)
        echo "== /sys/devices/pci0000:00/0000:00:01.0/0000:01:00.0 =="
        echo "modalias : pci:v000010DEd00002782sv00001043sd000088F5bc03sc00i00"
        echo "vendor   : NVIDIA Corporation"
        echo "model    : AD104 [GeForce RTX 5070 Ti]"
        echo "driver   : nvidia-driver-570 - distro non-free recommended"
        exit 0
        ;;
    autoinstall|install)
        echo "[MOCK ubuntu-drivers] Successfully processed driver install."
        exit 0
        ;;
    *)
        echo "ubuntu-drivers mock utility"
        exit 0
        ;;
esac
EOF
    chmod +x "${target}"
}

# Mock standard system commands (ffmpeg, cmake, ninja, git, wget, curl)
mock_system_tools() {
    local tools=("ffmpeg" "cmake" "ninja" "git" "wget" "curl")
    for tool in "${tools[@]}"; do
        local target="${MOCK_BIN_DIR}/${tool}"
        cat <<EOF > "${target}"
#!/usr/bin/env bash
if [[ "\$1" == "--version" ]] || [[ "\$1" == "-v" ]]; then
    echo "${tool} mock version 1.0.0"
    exit 0
fi
exit 0
EOF
        chmod +x "${target}"
    done
}

# ------------------------------------------------------------------------------
# Mock Dataset Generators
# ------------------------------------------------------------------------------

# Create a mock Submerged3D dataset structure
#   target_dir: root directory for Submerged3D dataset
#   layout_type: "complete", "raw_images_only", "empty_input", or "missing_input"
create_mock_submerged3d_dataset() {
    local target_dir="$1"
    local layout_type="${2:-complete}"
    local scenes=("Cormoran" "Isro" "Kwaj" "Tokai")

    for scene in "${scenes[@]}"; do
        local scene_dir="${target_dir}/${scene}"
        mkdir -p "${scene_dir}"

        case "${layout_type}" in
            complete)
                mkdir -p "${scene_dir}/input"
                for i in $(seq -w 1 20); do
                    touch "${scene_dir}/input/frame_${i}.jpg"
                done
                mkdir -p "${scene_dir}/images"
                for i in $(seq -w 1 20); do
                    touch "${scene_dir}/images/frame_${i}.jpg"
                done
                mkdir -p "${scene_dir}/sparse/0"
                touch "${scene_dir}/sparse/0/cameras.bin"
                touch "${scene_dir}/sparse/0/images.bin"
                touch "${scene_dir}/sparse/0/points3D.bin"
                mkdir -p "${scene_dir}/depthmap"
                touch "${scene_dir}/depthmap/frame_01.png"
                mkdir -p "${scene_dir}/depthmap_inverted"
                touch "${scene_dir}/depthmap_inverted/frame_01.png"
                ;;
            raw_images_only)
                mkdir -p "${scene_dir}/input"
                for i in $(seq -w 1 20); do
                    touch "${scene_dir}/input/frame_${i}.jpg"
                done
                ;;
            empty_input)
                mkdir -p "${scene_dir}/input"
                ;;
            missing_input)
                # Scene dir exists but no input folder
                ;;
        esac
    done
}

# Create a mock OSCD dataset structure
#   target_dir: root directory for Custom_OSCD_Dataset
#   layout_type: "complete", "raw_only", "missing_ref", "missing_inf"
create_mock_oscd_dataset() {
    local target_dir="$1"
    local layout_type="${2:-complete}"

    mkdir -p "${target_dir}"

    case "${layout_type}" in
        complete)
            mkdir -p "${target_dir}/reference_scene/input"
            mkdir -p "${target_dir}/reference_scene/images"
            mkdir -p "${target_dir}/reference_scene/sparse/0"
            touch "${target_dir}/reference_scene/sparse/0/cameras.bin"
            touch "${target_dir}/reference_scene/sparse/0/images.bin"
            touch "${target_dir}/reference_scene/sparse/0/points3D.bin"
            for i in $(seq -w 1 30); do
                touch "${target_dir}/reference_scene/input/frame_${i}.jpg"
                touch "${target_dir}/reference_scene/images/frame_${i}.jpg"
            done

            mkdir -p "${target_dir}/inference_scene/input"
            mkdir -p "${target_dir}/inference_scene/images"
            mkdir -p "${target_dir}/inference_scene/sparse/0"
            for i in $(seq -w 1 30); do
                touch "${target_dir}/inference_scene/input/frame_${i}.jpg"
                touch "${target_dir}/inference_scene/images/frame_${i}.jpg"
            done

            mkdir -p "${target_dir}/reference_reconstruction/point_cloud/iteration_30000"
            touch "${target_dir}/reference_reconstruction/point_cloud/iteration_30000/point_cloud.ply"
            ;;
        raw_only)
            mkdir -p "${target_dir}/reference_scene/input"
            mkdir -p "${target_dir}/inference_scene/input"
            for i in $(seq -w 1 10); do
                touch "${target_dir}/reference_scene/input/frame_${i}.jpg"
                touch "${target_dir}/inference_scene/input/frame_${i}.jpg"
            done
            ;;
        missing_ref)
            mkdir -p "${target_dir}/inference_scene/input"
            ;;
        missing_inf)
            mkdir -p "${target_dir}/reference_scene/input"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Target Script Discovery & Guard Helper
# ------------------------------------------------------------------------------

# Helper to verify target script existence or mark test as SKIP
check_target_script() {
    local script_path="$1"
    local test_name="$2"

    if [[ ! -f "${script_path}" ]]; then
        record_skip "${test_name}" "Target script not yet implemented: ${script_path}"
        return 1
    fi
    if [[ ! -x "${script_path}" ]]; then
        # Try to make it executable if it exists
        chmod +x "${script_path}" 2>/dev/null || true
    fi
    return 0
}
