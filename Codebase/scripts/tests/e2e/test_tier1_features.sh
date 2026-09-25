#!/usr/bin/env bash
# ==============================================================================
# tests/e2e/test_tier1_features.sh
# ------------------------------------------------------------------------------
# Tier 1: Feature Coverage & Isolated Happy-Path Test Suite
#
# Tests isolated CLI flags and single-feature happy paths across:
#   - verify_env.sh (--help, --skip-gpu, --check-gpu, --env, --dataset, --quiet)
#   - setup_env.sh (--help, --dry-run, --all, --system-deps, --drivers, --conda, --env)
#   - run_pipeline.sh (--help, --dry-run, --model <all 8 models>, --all, --stage, --skip-verify)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/Codebase/scripts"

VERIFY_SCRIPT="${SCRIPTS_DIR}/verify_env.sh"
SETUP_SCRIPT="${SCRIPTS_DIR}/setup_env.sh"
PIPELINE_SCRIPT="${SCRIPTS_DIR}/run_pipeline.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/mock_helpers.sh"
init_test_trap

echo -e "${TEST_CLR_BOLD}Starting Tier 1: Feature Coverage Test Suite...${TEST_CLR_RESET}"

ALL_ENVS="colmap_runner depth_anything seasplat_py310 3d-uir gaussianSplashing_env water_splatting rusplatting UW-GS sugar oscd 3dgs"

# ==============================================================================
# Group 1: verify_env.sh Feature Tests
# ==============================================================================

echo -e "\n${TEST_CLR_CYAN}--- Testing verify_env.sh Features ---${TEST_CLR_RESET}"

test_verify_env_help() {
    local tname="verify_env.sh: --help / -h displays usage and exits 0"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${VERIFY_SCRIPT}" --help
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code)"
    assert_output_contains "(Usage|Options|--skip-gpu|--dataset|--env)" "${CMD_OUTPUT}" "${tname} (usage text)"

    run_and_capture "${VERIFY_SCRIPT}" -h
    assert_exit_code 0 "${CMD_RC}" "verify_env.sh: -h alias (exit code)"
    assert_output_contains "(Usage|Options)" "${CMD_OUTPUT}" "verify_env.sh: -h alias (content)"
}

test_verify_env_skip_gpu() {
    local tname="verify_env.sh: --skip-gpu flag bypasses GPU requirement"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "verify_skip_gpu"
    mock_nvidia_smi "absent"
    mock_conda "${ALL_ENVS}"
    mock_system_tools
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/mock_dataset" "complete"

    run_and_capture "${VERIFY_SCRIPT}" --skip-gpu --env colmap_runner --dataset "${CURRENT_SANDBOX}/mock_dataset"
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(GPU check skipped|Skipping GPU|passed|SUCCESS|OK)" "${CMD_OUTPUT}" "${tname} (output note)"

    teardown_test_sandbox
}

test_verify_env_check_gpu() {
    local tname="verify_env.sh: --check-gpu verifies GPU when present"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "verify_check_gpu"
    mock_nvidia_smi "present" "NVIDIA GeForce RTX 5070 Ti" "12.0" "16384"
    mock_conda "${ALL_ENVS}"
    mock_system_tools
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/mock_dataset" "complete"

    run_and_capture "${VERIFY_SCRIPT}" --check-gpu --env colmap_runner --dataset "${CURRENT_SANDBOX}/mock_dataset"
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(RTX 5070 Ti|NVIDIA|GPU|passed|OK)" "${CMD_OUTPUT}" "${tname} (GPU detected)"

    teardown_test_sandbox
}

test_verify_env_env_flag() {
    local tname="verify_env.sh: --env <name> verifies specific Conda env"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "verify_env_flag"
    mock_nvidia_smi "absent"
    mock_conda "colmap_runner seasplat_py310"
    mock_system_tools
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/mock_dataset" "complete"

    run_and_capture "${VERIFY_SCRIPT}" --skip-gpu --env seasplat_py310 --dataset "${CURRENT_SANDBOX}/mock_dataset"
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(seasplat_py310.*(found|OK|passed|valid|present|verified)|Environment.*seasplat_py310)" "${CMD_OUTPUT}" "${tname} (env verified)"

    teardown_test_sandbox
}

test_verify_env_dataset_flag() {
    local tname="verify_env.sh: --dataset <path> validates custom dataset directory"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "verify_dataset_flag"
    mock_nvidia_smi "absent"
    mock_conda "colmap_runner"
    mock_system_tools
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/custom_dataset" "complete"

    run_and_capture "${VERIFY_SCRIPT}" --skip-gpu --env colmap_runner --dataset "${CURRENT_SANDBOX}/custom_dataset"
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(Dataset.*(valid|found|OK|passed)|Submerged3D)" "${CMD_OUTPUT}" "${tname} (dataset confirmed)"

    teardown_test_sandbox
}

test_verify_env_quiet_flag() {
    local tname="verify_env.sh: --quiet / -q suppresses non-error output"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "verify_quiet"
    mock_nvidia_smi "absent"
    mock_conda "${ALL_ENVS}"
    mock_system_tools
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/mock_dataset" "complete"

    run_and_capture "${VERIFY_SCRIPT}" --quiet --skip-gpu --env colmap_runner --dataset "${CURRENT_SANDBOX}/mock_dataset"
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_not_contains "(\\[INFO\\]|Checking GPU|Scanning directory)" "${CMD_OUTPUT}" "${tname} (quiet output verified)"

    teardown_test_sandbox
}

test_verify_env_help
test_verify_env_skip_gpu
test_verify_env_check_gpu
test_verify_env_env_flag
test_verify_env_dataset_flag
test_verify_env_quiet_flag

# ==============================================================================
# Group 2: setup_env.sh Feature Tests
# ==============================================================================

echo -e "\n${TEST_CLR_CYAN}--- Testing setup_env.sh Features ---${TEST_CLR_RESET}"

test_setup_env_help() {
    local tname="setup_env.sh: --help / -h displays usage and exits 0"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --help
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code)"
    assert_output_contains "(--all|--system-deps|--drivers|--conda|--env|--dry-run)" "${CMD_OUTPUT}" "${tname} (flags documented)"

    run_and_capture "${SETUP_SCRIPT}" -h
    assert_exit_code 0 "${CMD_RC}" "setup_env.sh: -h alias (exit code)"
}

test_setup_env_dry_run_all() {
    local tname="setup_env.sh: --all --dry-run prints planned full installation"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --all --dry-run
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(dry-run|DRY RUN|Planned|miniconda|colmap_runner|seasplat_py310|oscd|sugar)" "${CMD_OUTPUT}" "${tname} (dry run plan)"
}

test_setup_env_dry_run_system_deps() {
    local tname="setup_env.sh: --system-deps --dry-run prints apt-get package plan"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --system-deps --dry-run
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(apt|build-essential|colmap|ffmpeg|ninja)" "${CMD_OUTPUT}" "${tname} (system deps list)"
}

test_setup_env_dry_run_drivers() {
    local tname="setup_env.sh: --drivers --dry-run prints driver installation step"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --drivers --dry-run
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(driver|ubuntu-drivers|nvidia)" "${CMD_OUTPUT}" "${tname} (driver plan)"
}

test_setup_env_dry_run_conda() {
    local tname="setup_env.sh: --conda --dry-run prints miniconda bootstrap plan"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --conda --dry-run
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(miniconda|Miniconda3|conda)" "${CMD_OUTPUT}" "${tname} (conda bootstrap plan)"
}

test_setup_env_dry_run_specific_env() {
    local tname="setup_env.sh: --env seasplat_py310 --dry-run prints SeaSplat recipe"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --env seasplat_py310 --dry-run
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(seasplat_py310|Python 3.10|diff-gaussian-rasterization)" "${CMD_OUTPUT}" "${tname} (recipe output)"
}

test_setup_env_dry_run_oscd_env() {
    local tname="setup_env.sh: --env oscd --dry-run prints OSCD recipe"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --env oscd --dry-run
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(oscd|Python 3.12|cupy|torch|sam2)" "${CMD_OUTPUT}" "${tname} (oscd recipe output)"
}

test_setup_env_help
test_setup_env_dry_run_all
test_setup_env_dry_run_system_deps
test_setup_env_dry_run_drivers
test_setup_env_dry_run_conda
test_setup_env_dry_run_specific_env
test_setup_env_dry_run_oscd_env

# ==============================================================================
# Group 3: run_pipeline.sh Feature Tests
# ==============================================================================

echo -e "\n${TEST_CLR_CYAN}--- Testing run_pipeline.sh Features ---${TEST_CLR_RESET}"

test_run_pipeline_help() {
    local tname="run_pipeline.sh: --help / -h displays usage and exits 0"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${PIPELINE_SCRIPT}" --help
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code)"
    assert_output_contains "(--model|--all|--dataset|--stage|--dry-run|--skip-verify)" "${CMD_OUTPUT}" "${tname} (options list)"

    run_and_capture "${PIPELINE_SCRIPT}" -h
    assert_exit_code 0 "${CMD_RC}" "run_pipeline.sh: -h alias (exit code)"
}

test_run_pipeline_dry_run_models() {
    local models=("seasplat" "3d-uir" "gaussiansplashing" "watersplatting" "rusplatting" "uw-gs" "oscd" "sugar")

    for model in "${models[@]}"; do
        local tname="run_pipeline.sh: --model ${model} --dry-run prints execution path"
        if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

        run_and_capture "${PIPELINE_SCRIPT}" --model "${model}" --dry-run --skip-verify
        assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
        assert_output_contains "(dry-run|DRY RUN|${model})" "${CMD_OUTPUT}" "${tname} (model identified)"
    done
}

test_run_pipeline_dry_run_all() {
    local tname="run_pipeline.sh: --all --dry-run prints sequential plan for all models"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${PIPELINE_SCRIPT}" --all --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(seasplat|3d-uir|gaussiansplashing|watersplatting|rusplatting|uw-gs|oscd|sugar)" "${CMD_OUTPUT}" "${tname} (all models listed)"
}

test_run_pipeline_stages() {
    local stages=("colmap" "depth" "train" "mesh" "eval" "all")

    for stage in "${stages[@]}"; do
        local tname="run_pipeline.sh: --stage ${stage} accepted under dry-run"
        if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

        run_and_capture "${PIPELINE_SCRIPT}" --model seasplat --stage "${stage}" --dry-run --skip-verify
        assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
        assert_output_contains "(${stage}|dry-run|DRY RUN)" "${CMD_OUTPUT}" "${tname} (stage mentioned)"
    done
}

test_run_pipeline_help
test_run_pipeline_dry_run_models
test_run_pipeline_dry_run_all
test_run_pipeline_stages

print_suite_summary "Tier 1: Feature Coverage"
