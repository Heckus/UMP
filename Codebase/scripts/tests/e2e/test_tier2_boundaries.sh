#!/usr/bin/env bash
# ==============================================================================
# tests/e2e/test_tier2_boundaries.sh
# ------------------------------------------------------------------------------
# Tier 2: Boundary, Error Handling & Failure Case Test Suite
#
# Verifies non-zero exit codes, error reporting, and defensive validation:
#   - verify_env.sh:
#       Exit code 1 on GPU check failure / driver missing
#       Exit code 2 on missing or damaged Conda environment
#       Exit code 3 on missing dataset folder or invalid layout
#       Exit code 4 on missing required tool/dependency
#       Non-zero exit on unknown/malformed arguments
#   - setup_env.sh:
#       Non-zero exit on unknown flags, invalid env names, missing arguments
#   - run_pipeline.sh:
#       Non-zero exit on invalid model, invalid stage, missing dataset, bad args
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

echo -e "${TEST_CLR_BOLD}Starting Tier 2: Boundary & Error Handling Test Suite...${TEST_CLR_RESET}"

# ==============================================================================
# Group 1: verify_env.sh Boundary & Failure Tests
# ==============================================================================

echo -e "\n${TEST_CLR_CYAN}--- Testing verify_env.sh Boundary Cases ---${TEST_CLR_RESET}"

test_verify_env_gpu_failure() {
    local tname="verify_env.sh: exits code 1 when GPU check fails or driver is missing"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "verify_gpu_fail"
    mock_nvidia_smi "failing"
    mock_conda "colmap_runner"
    mock_system_tools
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/mock_dataset" "complete"

    run_and_capture "${VERIFY_SCRIPT}" --check-gpu --env colmap_runner --dataset "${CURRENT_SANDBOX}/mock_dataset"
    assert_exit_code 1 "${CMD_RC}" "${tname} (exit code 1)"
    assert_output_contains "(GPU|nvidia-smi|NVIDIA|driver|fail|ERROR)" "${CMD_OUTPUT}" "${tname} (diagnostic error)"

    teardown_test_sandbox
}

test_verify_env_missing_conda_env() {
    local tname="verify_env.sh: exits code 2 when requested Conda env is missing"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "verify_missing_env"
    mock_nvidia_smi "absent"
    mock_conda "base colmap_runner"  # seasplat_py310 is missing!
    mock_system_tools
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/mock_dataset" "complete"

    run_and_capture "${VERIFY_SCRIPT}" --skip-gpu --env seasplat_py310 --dataset "${CURRENT_SANDBOX}/mock_dataset"
    assert_exit_code 2 "${CMD_RC}" "${tname} (exit code 2)"
    assert_output_contains "(seasplat_py310|environment.*(missing|not found|does not exist)|ERROR)" "${CMD_OUTPUT}" "${tname} (missing env error)"

    teardown_test_sandbox
}

test_verify_env_all_envs_missing() {
    local tname="verify_env.sh: exits code 2 when --all-envs finds missing environments"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "verify_all_envs_missing"
    mock_nvidia_smi "absent"
    mock_conda "colmap_runner"  # only 1 of 11 envs present
    mock_system_tools
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/mock_dataset" "complete"

    run_and_capture "${VERIFY_SCRIPT}" --skip-gpu --all-envs --dataset "${CURRENT_SANDBOX}/mock_dataset"
    assert_exit_code 2 "${CMD_RC}" "${tname} (exit code 2)"
    assert_output_contains "(missing|not found|ERROR)" "${CMD_OUTPUT}" "${tname} (all-envs failure message)"

    teardown_test_sandbox
}

test_verify_env_missing_dataset_dir() {
    local tname="verify_env.sh: exits code 3 when dataset directory does not exist"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "verify_missing_dataset"
    mock_nvidia_smi "absent"
    mock_conda "colmap_runner"
    mock_system_tools

    local non_existent="${CURRENT_SANDBOX}/non_existent_dataset_path_9999"
    run_and_capture "${VERIFY_SCRIPT}" --skip-gpu --env colmap_runner --dataset "${non_existent}"
    assert_exit_code 3 "${CMD_RC}" "${tname} (exit code 3)"
    assert_output_contains "(dataset.*(not found|does not exist|missing)|ERROR)" "${CMD_OUTPUT}" "${tname} (missing dataset error)"

    teardown_test_sandbox
}

test_verify_env_corrupt_dataset_layout() {
    local tname="verify_env.sh: exits code 3 when scene input directory is missing or empty"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "verify_corrupt_dataset"
    mock_nvidia_smi "absent"
    mock_conda "colmap_runner"
    mock_system_tools
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/corrupt_dataset" "empty_input"

    run_and_capture "${VERIFY_SCRIPT}" --skip-gpu --env colmap_runner --dataset "${CURRENT_SANDBOX}/corrupt_dataset"
    assert_exit_code 3 "${CMD_RC}" "${tname} (exit code 3)"
    assert_output_contains "(input.*(empty|missing|no images)|dataset.*invalid|ERROR)" "${CMD_OUTPUT}" "${tname} (empty input error)"

    teardown_test_sandbox
}

test_verify_env_invalid_argument() {
    local tname="verify_env.sh: exits non-zero on unknown CLI flag"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${VERIFY_SCRIPT}" --unrecognized-flag-xyz
    if [[ "${CMD_RC}" -ne 0 ]]; then
        record_pass "${tname} (exit code non-zero: ${CMD_RC})"
    else
        record_fail "${tname}" "Expected non-zero exit code on unknown flag, got 0"
    fi
    assert_output_contains "(unknown|unrecognized|invalid|Usage)" "${CMD_OUTPUT}" "${tname} (error message)"
}

test_verify_env_missing_flag_value() {
    local tname="verify_env.sh: exits non-zero when --env is passed without argument"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${VERIFY_SCRIPT}" --env
    if [[ "${CMD_RC}" -ne 0 ]]; then
        record_pass "${tname} (exit code non-zero: ${CMD_RC})"
    else
        record_fail "${tname}" "Expected non-zero exit code on missing flag argument, got 0"
    fi
}

test_verify_env_gpu_failure
test_verify_env_missing_conda_env
test_verify_env_all_envs_missing
test_verify_env_missing_dataset_dir
test_verify_env_corrupt_dataset_layout
test_verify_env_invalid_argument
test_verify_env_missing_flag_value

# ==============================================================================
# Group 2: setup_env.sh Boundary & Failure Tests
# ==============================================================================

echo -e "\n${TEST_CLR_CYAN}--- Testing setup_env.sh Boundary Cases ---${TEST_CLR_RESET}"

test_setup_env_invalid_flag() {
    local tname="setup_env.sh: exits non-zero on unknown CLI option"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --totally-invalid-option
    if [[ "${CMD_RC}" -ne 0 ]]; then
        record_pass "${tname} (exit code non-zero: ${CMD_RC})"
    else
        record_fail "${tname}" "Expected non-zero exit code on unknown option, got 0"
    fi
    assert_output_contains "(unknown|unrecognized|invalid|Usage)" "${CMD_OUTPUT}" "${tname} (error message)"
}

test_setup_env_invalid_env_name() {
    local tname="setup_env.sh: exits non-zero on unknown environment name"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --yes --env non_existent_model_env_xyz
    if [[ "${CMD_RC}" -ne 0 ]]; then
        record_pass "${tname} (exit code non-zero: ${CMD_RC})"
    else
        record_fail "${tname}" "Expected non-zero exit code on unknown env, got 0"
    fi
    assert_output_contains "(unknown|invalid|not supported|ERROR)" "${CMD_OUTPUT}" "${tname} (invalid env message)"
}

test_setup_env_missing_env_value() {
    local tname="setup_env.sh: exits non-zero when --env is passed without argument"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --env
    if [[ "${CMD_RC}" -ne 0 ]]; then
        record_pass "${tname} (exit code non-zero: ${CMD_RC})"
    else
        record_fail "${tname}" "Expected non-zero exit code on missing arg, got 0"
    fi
}

test_setup_env_invalid_flag
test_setup_env_invalid_env_name
test_setup_env_missing_env_value

# ==============================================================================
# Group 3: run_pipeline.sh Boundary & Failure Tests
# ==============================================================================

echo -e "\n${TEST_CLR_CYAN}--- Testing run_pipeline.sh Boundary Cases ---${TEST_CLR_RESET}"

test_run_pipeline_invalid_model() {
    local tname="run_pipeline.sh: exits non-zero on invalid --model argument"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${PIPELINE_SCRIPT}" --model invalid_model_xyz --dry-run --skip-verify
    if [[ "${CMD_RC}" -ne 0 ]]; then
        record_pass "${tname} (exit code non-zero: ${CMD_RC})"
    else
        record_fail "${tname}" "Expected non-zero exit code on invalid model, got 0"
    fi
    assert_output_contains "(invalid.*model|unknown.*model|Supported models|ERROR)" "${CMD_OUTPUT}" "${tname} (invalid model message)"
}

test_run_pipeline_invalid_stage() {
    local tname="run_pipeline.sh: exits non-zero on invalid --stage argument"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${PIPELINE_SCRIPT}" --model seasplat --stage invalid_stage_xyz --dry-run --skip-verify
    if [[ "${CMD_RC}" -ne 0 ]]; then
        record_pass "${tname} (exit code non-zero: ${CMD_RC})"
    else
        record_fail "${tname}" "Expected non-zero exit code on invalid stage, got 0"
    fi
    assert_output_contains "(invalid.*stage|unknown.*stage|ERROR)" "${CMD_OUTPUT}" "${tname} (invalid stage message)"
}

test_run_pipeline_missing_dataset() {
    local tname="run_pipeline.sh: exits non-zero when provided non-existent dataset directory"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${PIPELINE_SCRIPT}" --model seasplat --dataset /tmp/nonexistent_dataset_88888 --dry-run
    if [[ "${CMD_RC}" -ne 0 ]]; then
        record_pass "${tname} (exit code non-zero: ${CMD_RC})"
    else
        record_fail "${tname}" "Expected non-zero exit code on non-existent dataset, got 0"
    fi
    assert_output_contains "(dataset.*(not found|does not exist|invalid)|ERROR)" "${CMD_OUTPUT}" "${tname} (dataset error message)"
}

test_run_pipeline_missing_model_and_all() {
    local tname="run_pipeline.sh: exits non-zero when neither --model nor --all is specified"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${PIPELINE_SCRIPT}" --dry-run --skip-verify
    if [[ "${CMD_RC}" -ne 0 ]]; then
        record_pass "${tname} (exit code non-zero: ${CMD_RC})"
    else
        record_fail "${tname}" "Expected non-zero exit code when no model specified, got 0"
    fi
    assert_output_contains "(Must specify|--model|--all|Usage)" "${CMD_OUTPUT}" "${tname} (missing model or all guidance)"
}

test_run_pipeline_invalid_model
test_run_pipeline_invalid_stage
test_run_pipeline_missing_dataset
test_run_pipeline_missing_model_and_all

print_suite_summary "Tier 2: Boundaries & Error Handling"
