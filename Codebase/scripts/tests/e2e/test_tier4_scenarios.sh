#!/usr/bin/env bash
# ==============================================================================
# tests/e2e/test_tier4_scenarios.sh
# ------------------------------------------------------------------------------
# Tier 4: Real-World End-to-End Execution Pipeline Scenarios (Dry-Run Mode)
#
# Validates complete multi-stage execution pipelines against technical plans:
#   Scenario 1: SeaSplat complete workflow (COLMAP -> Depth -> --do_seathru -> Eval)
#   Scenario 2: 3D-UIR workflow (Depth -> depths/ symlink -> make_depth_scale.py -> Eval)
#   Scenario 3: RUSplatting workflow (Inverted depth -> RIFE _to_ -> --adaptive -> Eval)
#   Scenario 4: SuGaR mesh extraction workflow (Best 3DGS prior -> train_full_pipeline -> .obj)
#   Scenario 5: O-SCD workflow (Ref + Inf COLMAP -> 30k 3DGS -> oscd.py -> update.py -> metrics)
#   Scenario 6: Full multi-model sequential execution (--all)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/Codebase/scripts"

PIPELINE_SCRIPT="${SCRIPTS_DIR}/run_pipeline.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/mock_helpers.sh"
init_test_trap

echo -e "${TEST_CLR_BOLD}Starting Tier 4: Real-World Scenarios Test Suite...${TEST_CLR_RESET}"

# ==============================================================================
# Scenario 1: SeaSplat Workflow
# ==============================================================================

test_scenario_seasplat_workflow() {
    local tname="Scenario 1: SeaSplat end-to-end dry-run execution path"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "scenario_seasplat"
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/Submerged3D" "complete"

    run_and_capture "${PIPELINE_SCRIPT}" --model seasplat --dataset "${CURRENT_SANDBOX}/Submerged3D" --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"

    # Verify execution path items
    assert_output_contains "(colmap_runner|convert\\.py)" "${CMD_OUTPUT}" "${tname} (COLMAP stage)"
    assert_output_contains "(depth_anything|Depth-Anything|depth_anything_v2)" "${CMD_OUTPUT}" "${tname} (Depth stage)"
    assert_output_contains "(seasplat_py310|train\\.py)" "${CMD_OUTPUT}" "${tname} (Environment seasplat_py310)"
    assert_output_contains "(--do_seathru)" "${CMD_OUTPUT}" "${tname} (--do_seathru flag)"
    assert_output_contains "(--seathru_from_iter 10000)" "${CMD_OUTPUT}" "${tname} (--seathru_from_iter flag)"
    assert_output_contains "(--eval)" "${CMD_OUTPUT}" "${tname} (--eval flag for test split)"
    assert_output_contains "(metrics\\.py|render\\.py|results\\.json)" "${CMD_OUTPUT}" "${tname} (Evaluation stage)"

    teardown_test_sandbox
}

# ==============================================================================
# Scenario 2: 3D-UIR Workflow
# ==============================================================================

test_scenario_3d_uir_workflow() {
    local tname="Scenario 2: 3D-UIR end-to-end dry-run execution path"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "scenario_3duir"
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/Submerged3D" "complete"

    run_and_capture "${PIPELINE_SCRIPT}" --model 3d-uir --dataset "${CURRENT_SANDBOX}/Submerged3D" --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"

    # Verify 3D-UIR prerequisites and execution
    assert_output_contains "(3d-uir)" "${CMD_OUTPUT}" "${tname} (Environment 3d-uir)"
    assert_output_contains "(depths|depthmap)" "${CMD_OUTPUT}" "${tname} (Depths path handling)"
    assert_output_contains "(make_depth_scale\\.py|depth_scale)" "${CMD_OUTPUT}" "${tname} (make_depth_scale hook)"
    assert_output_contains "(train\\.py.*-d.*depths|--eval)" "${CMD_OUTPUT}" "${tname} (Training with depths)"

    teardown_test_sandbox
}

# ==============================================================================
# Scenario 3: RUSplatting Workflow
# ==============================================================================

test_scenario_rusplatting_workflow() {
    local tname="Scenario 3: RUSplatting end-to-end dry-run execution path"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "scenario_rusplatting"
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/Submerged3D" "complete"

    run_and_capture "${PIPELINE_SCRIPT}" --model rusplatting --dataset "${CURRENT_SANDBOX}/Submerged3D" --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"

    # Verify RUSplatting prerequisites
    assert_output_contains "(rusplatting)" "${CMD_OUTPUT}" "${tname} (Environment rusplatting)"
    assert_output_contains "(depthmap_inverted|inverted)" "${CMD_OUTPUT}" "${tname} (Inverted depth map hook)"
    assert_output_contains "(--adaptive)" "${CMD_OUTPUT}" "${tname} (--adaptive flag)"
    assert_output_contains "(_to_|RIFE|interpolation)" "${CMD_OUTPUT}" "${tname} (RIFE frame interpolation reference)"

    teardown_test_sandbox
}

# ==============================================================================
# Scenario 4: SuGaR Workflow
# ==============================================================================

test_scenario_sugar_workflow() {
    local tname="Scenario 4: SuGaR mesh extraction dry-run execution path"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "scenario_sugar"
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/Submerged3D" "complete"

    run_and_capture "${PIPELINE_SCRIPT}" --model sugar --dataset "${CURRENT_SANDBOX}/Submerged3D" --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"

    # Verify SuGaR execution details
    assert_output_contains "(sugar)" "${CMD_OUTPUT}" "${tname} (Environment sugar)"
    assert_output_contains "(train_full_pipeline\\.py)" "${CMD_OUTPUT}" "${tname} (Invocation train_full_pipeline.py)"
    assert_output_contains "(dn_consistency|-r)" "${CMD_OUTPUT}" "${tname} (Regularization dn_consistency)"
    assert_output_contains "(--high_poly.*True|high_poly)" "${CMD_OUTPUT}" "${tname} (High poly flag)"
    assert_output_contains "(--export_obj.*True|export_obj|\\.obj)" "${CMD_OUTPUT}" "${tname} (OBJ mesh export)"
    assert_output_contains "(--gs_output_dir|point_cloud)" "${CMD_OUTPUT}" "${tname} (3DGS checkpoint prior)"

    teardown_test_sandbox
}

# ==============================================================================
# Scenario 5: O-SCD Workflow
# ==============================================================================

test_scenario_oscd_workflow() {
    local tname="Scenario 5: O-SCD change detection dry-run execution path"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "scenario_oscd"
    create_mock_oscd_dataset "${CURRENT_SANDBOX}/Custom_OSCD_Dataset" "complete"

    run_and_capture "${PIPELINE_SCRIPT}" --model oscd --dataset "${CURRENT_SANDBOX}/Custom_OSCD_Dataset" --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"

    # Verify O-SCD stages
    assert_output_contains "(reference_scene.*inference_scene|convert\\.py)" "${CMD_OUTPUT}" "${tname} (Dual scene COLMAP undistortion)"
    assert_output_contains "(reference_reconstruction|iteration_30000)" "${CMD_OUTPUT}" "${tname} (30k reference 3DGS reconstruction)"
    assert_output_contains "(oscd|O-SCD-main|oscd\\.py)" "${CMD_OUTPUT}" "${tname} (O-SCD change detection script)"
    assert_output_contains "(--resolution 1|--test_hold 5)" "${CMD_OUTPUT}" "${tname} (O-SCD resolution and test hold)"
    assert_output_contains "(update\\.py|updated_scene)" "${CMD_OUTPUT}" "${tname} (Scene update script)"
    assert_output_contains "(metrics\\.py|evaluate\\.py)" "${CMD_OUTPUT}" "${tname} (O-SCD metrics evaluation)"

    teardown_test_sandbox
}

# ==============================================================================
# Scenario 6: Full Sequential Execution Workflow (--all)
# ==============================================================================

test_scenario_all_models_sequential() {
    local tname="Scenario 6: Full multi-model sequential execution plan (--all)"
    if ! check_target_script "${PIPELINE_SCRIPT}" "${tname}"; then return 0; fi

    setup_test_sandbox "scenario_all"
    create_mock_submerged3d_dataset "${CURRENT_SANDBOX}/Submerged3D" "complete"

    run_and_capture "${PIPELINE_SCRIPT}" --all --dataset "${CURRENT_SANDBOX}/Submerged3D" --dry-run --skip-verify
    assert_exit_code 0 "${CMD_RC}" "${tname} (exit code 0)"

    # Verify sequential presence of all models
    local expected_models=("seasplat" "3d-uir" "gaussiansplashing" "watersplatting" "rusplatting" "uw-gs" "sugar" "oscd")
    for mod in "${expected_models[@]}"; do
        assert_output_contains "${mod}" "${CMD_OUTPUT}" "${tname} (Includes ${mod})"
    done

    teardown_test_sandbox
}

test_scenario_seasplat_workflow
test_scenario_3d_uir_workflow
test_scenario_rusplatting_workflow
test_scenario_sugar_workflow
test_scenario_oscd_workflow
test_scenario_all_models_sequential

print_suite_summary "Tier 4: Scenarios"
