#!/usr/bin/env bash
# ==============================================================================
# tests/e2e/test_shellcheck.sh
# ------------------------------------------------------------------------------
# ShellCheck Static Analysis Test Suite
#
# Runs shellcheck against all bash scripts in Codebase/scripts/ and tests/e2e/
# verifying 0 errors and 0 warnings.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/Codebase/scripts"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/mock_helpers.sh"

echo -e "${TEST_CLR_BOLD}Starting ShellCheck Static Analysis Suite...${TEST_CLR_RESET}"

# Verify shellcheck binary is available
if ! command -v shellcheck >/dev/null 2>&1; then
    record_fail "ShellCheck Availability" "shellcheck executable not found in PATH"
    print_suite_summary "ShellCheck Suite"
    exit 1
fi
record_pass "ShellCheck Binary Check" "Found: $(command -v shellcheck)"

# 1. Check all scripts in Codebase/scripts/
EXPECTED_CORE_SCRIPTS=("verify_env.sh" "setup_env.sh" "run_pipeline.sh")

if [[ ! -d "${SCRIPTS_DIR}" ]]; then
    log_test_skip "Directory ${SCRIPTS_DIR} does not exist yet."
    for target in "${EXPECTED_CORE_SCRIPTS[@]}"; do
        record_skip "ShellCheck: Codebase/scripts/${target}" "Script not yet created"
    done
else
    # Scan for any .sh file in Codebase/scripts
    found_scripts=()
    while IFS= read -r -d '' file; do
        found_scripts+=("${file}")
    done < <(find "${SCRIPTS_DIR}" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)

    if [[ ${#found_scripts[@]} -eq 0 ]]; then
        for target in "${EXPECTED_CORE_SCRIPTS[@]}"; do
            record_skip "ShellCheck: Codebase/scripts/${target}" "Script not yet created"
        done
    else
        for script_file in "${found_scripts[@]}"; do
            script_rel="$(realpath --relative-to="${REPO_ROOT}" "${script_file}")"
            test_title="ShellCheck: ${script_rel}"

            # Run shellcheck with external sources allowed (-x)
            lint_output=""
            if lint_output="$(shellcheck -x "${script_file}" 2>&1)"; then
                record_pass "${test_title}" "Zero errors and warnings"
            else
                record_fail "${test_title}" "ShellCheck violations found:\n${lint_output}"
            fi
        done
    fi
fi

# 2. Check all test scripts in tests/e2e/ to ensure our test harness is clean
test_scripts=()
while IFS= read -r -d '' file; do
    test_scripts+=("${file}")
done < <(find "${SCRIPT_DIR}" -maxdepth 1 -name "*.sh" -print0)

for script_file in "${test_scripts[@]}"; do
    script_rel="$(realpath --relative-to="${REPO_ROOT}" "${script_file}")"
    test_title="ShellCheck: ${script_rel}"

    lint_output=""
    if lint_output="$(shellcheck -x "${script_file}" 2>&1)"; then
        record_pass "${test_title}" "Zero errors and warnings"
    else
        record_fail "${test_title}" "ShellCheck violations found:\n${lint_output}"
    fi
done

print_suite_summary "ShellCheck Suite"
