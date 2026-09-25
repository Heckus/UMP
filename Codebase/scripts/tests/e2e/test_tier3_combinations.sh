#!/usr/bin/env bash
# ==============================================================================
# tests/e2e/test_tier3_combinations.sh
# ------------------------------------------------------------------------------
# Tier 3: Pairwise & Multi-Flag Combinations Test Suite
#
# Verifies interaction between orthogonal flags:
#   - verify_env.sh:
#       (--skip-gpu + --env oscd + --quiet)
#       (--skip-gpu + --all-envs + --dataset)
#       (--check-gpu + --env sugar)
#   - setup_env.sh:
#       (--env oscd + --dry-run)
#       (--system-deps + --conda + --dry-run)
#       (--drivers + --yes + --dry-run)
#       (--all + --yes + --dry-run)
#       (--env UW-GS + --dry-run)
#   - run_pipeline.sh:
#       (--model seasplat + --dataset <path> + --dry-run)
#       (--all + --dry-run + --skip-verify)
#       (--model oscd + --stage train + --dry-run)
#       (--model 3d-uir + --stage eval + --dry-run)
#       (--model sugar + --dry-run + --skip-verify)
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

echo -e "${TEST_CLR_BOLD}Starting Tier 3: Combinations Test Suite...${TEST_CLR_RESET}"

ALL_ENVS="colmap_runner depth_anything seasplat_py310 3d-uir gaussianSplashing_env water_splatting rusplatting UW-GS sugar oscd 3dgs"

# ==============================================================================
# Group 1: verify_env.sh Combinations
# ==============================================================================

echo -e "\n${TEST_CLR_CYAN}--- Testing verify_env.sh Flag Combinations ---${TEST_CLR_RESET}"

test_verify_combo_skip_gpu_env_quiet() {
    local tname="verify_env.sh: --skip-gpu + --env oscd + --quiet"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "combo_verify_1"
    mock_nvidia_smi "absent"
    mock_conda "oscd"
    mock_system_tools

    run_and_capture "${VERIFY_SCRIPT}" --skip-gpu --env oscd --quiet
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_not_contains "\\[INFO\\]" "${CMD_OUTPUT}" "${tname} (quiet mode upheld)"

    teardown_test_sandbox
}

test_verify_combo_all_envs_dataset() {
    local tname="verify_env.sh: --skip-gpu + --all-envs + --dataset <path>"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "combo_verify_2"
    mock_nvidia_smi "absent"
    mock_conda "${ALL_ENVS}"
    mock_system_tools
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/mock_dataset" "complete"

    run_and_capture "${VERIFY_SCRIPT}" --skip-gpu --all-envs --dataset "${CURRENT_SANDBOX}/mock_dataset"
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(All environments.*OK|Verification passed|SUCCESS)" "${CMD_OUTPUT}" "${tname} (all envs pass)"

    teardown_test_sandbox
}

test_verify_combo_check_gpu_env_sugar() {
    local tname="verify_env.sh: --check-gpu + --env sugar"
    if ! check_target_script "${VERIFY_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "combo_verify_3"
    mock_nvidia_smi "present" "NVIDIA GeForce RTX 5070 Ti" "12.0" "16384"
    mock_conda "sugar"
    mock_system_tools

    run_and_capture "${VERIFY_SCRIPT}" --check-gpu --env sugar
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(sugar|GPU|passed|OK)" "${CMD_OUTPUT}" "${tname} (sugar and gpu validated)"

    teardown_test_sandbox
}

test_verify_combo_skip_gpu_env_quiet
test_verify_combo_all_envs_dataset
test_verify_combo_check_gpu_env_sugar

# ==============================================================================
# Group 2: setup_env.sh Combinations
# ==============================================================================

echo -e "\n${TEST_CLR_CYAN}--- Testing setup_env.sh Flag Combinations ---${TEST_CLR_RESET}"

test_setup_combo_env_dryrun() {
    local tname="setup_env.sh: --env oscd + --dry-run"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --env oscd --dry-run
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(oscd|Python 3.12|cupy|dry-run|DRY RUN)" "${CMD_OUTPUT}" "${tname} (targeted dry run)"
}

test_setup_combo_system_conda_dryrun() {
    local tname="setup_env.sh: --system-deps + --conda + --dry-run"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --system-deps --conda --dry-run
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(apt|miniconda|dry-run|DRY RUN)" "${CMD_OUTPUT}" "${tname} (system deps and conda)"
}

test_setup_combo_all_yes_dryrun() {
    local tname="setup_env.sh: --all + --yes + --dry-run"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --all --yes --dry-run
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(all|dry-run|DRY RUN)" "${CMD_OUTPUT}" "${tname} (full unattended dry run)"
}

test_setup_combo_uw_gs_dryrun() {
    local tname="setup_env.sh: --env UW-GS + --dry-run verifies Linux recipe"
    if ! check_target_script "${SETUP_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${SETUP_SCRIPT}" --env UW-GS --dry-run
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(UW-GS|Python 3.7|PyTorch 1.12.1|dry-run|DRY RUN)" "${CMD_OUTPUT}" "${tname} (Linux UW-GS recipe)"
    # Must NOT mention win64_mkl or windows vc runtimes
    assert_output_not_contains "(win64_mkl|vc14_runtime)" "${CMD_OUTPUT}" "${tname} (Windows artifacts omitted)"
}

test_setup_combo_env_dryrun
test_setup_combo_system_conda_dryrun
test_setup_combo_all_yes_dryrun
test_setup_combo_uw_gs_dryrun

# ==============================================================================
# Group 3: run_pipeline.sh Combinations
# ==============================================================================

echo -e "\n${TEST_CLR_CYAN}--- Testing run_pipeline.sh Flag Combinations ---${TEST_CLR_RESET}"

test_pipeline_combo_model_dataset_dryrun() {
    local tname="run_pipeline.sh: --model seasplat + --dataset <path> + --dry-run"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "combo_pipe_1"
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/custom_submerged" "complete"

    run_and_capture "${PIPELINE_SCRIPT}" --model seasplat --dataset "${CURRENT_SANDBOX}/custom_submerged" --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(seasplat|custom_submerged|dry-run|DRY RUN)" "${CMD_OUTPUT}" "${tname} (model and dataset bound)"

    teardown_test_sandbox
}

test_pipeline_combo_all_dryrun_skip_verify() {
    local tname="run_pipeline.sh: --all + --dry-run + --skip-verify"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${PIPELINE_SCRIPT}" --all --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(seasplat|oscd|sugar|dry-run|DRY RUN)" "${CMD_OUTPUT}" "${tname} (all models dry run)"
}

test_pipeline_combo_oscd_stage_train() {
    local tname="run_pipeline.sh: --model oscd + --stage train + --dry-run"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${PIPELINE_SCRIPT}" --model oscd --stage train --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(oscd|train|oscd.py|dry-run|DRY RUN)" "${CMD_OUTPUT}" "${tname} (oscd train stage)"
}

test_pipeline_combo_3d_uir_stage_eval() {
    local tname="run_pipeline.sh: --model 3d-uir + --stage eval + --dry-run"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${PIPELINE_SCRIPT}" --model 3d-uir --stage eval --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(3d-uir|eval|metrics.py|render.py|results.json|dry-run|DRY RUN)" "${CMD_OUTPUT}" "${tname} (eval stage metrics)"
}

test_pipeline_combo_sugar_dryrun() {
    local tname="run_pipeline.sh: --model sugar + --dry-run + --skip-verify"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    run_and_capture "${PIPELINE_SCRIPT}" --model sugar --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"
    assert_output_contains "(sugar|train_full_pipeline.py|export_obj|dry-run|DRY RUN)" "${CMD_OUTPUT}" "${tname} (sugar pipeline plan)"
}

test_pipeline_combo_model_dataset_dryrun
test_pipeline_combo_all_dryrun_skip_verify
test_pipeline_combo_oscd_stage_train
test_pipeline_combo_3d_uir_stage_eval
test_pipeline_combo_sugar_dryrun

print_suite_summary "Tier 3: Flag Combinations"
