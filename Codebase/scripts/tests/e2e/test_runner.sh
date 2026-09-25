#!/usr/bin/env bash
# ==============================================================================
# tests/e2e/test_runner.sh
# ------------------------------------------------------------------------------
# Master Test Runner for E2E Test Suite
#
# Coordinates execution of all test tiers (ShellCheck, Tier 1 Features,
# Tier 2 Boundaries, Tier 3 Combinations, Tier 4 Scenarios), aggregates metrics,
# and outputs structured results.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ANSI formatting
CLR_RESET="\033[0m"
CLR_RED="\033[1;31m"
CLR_GREEN="\033[1;32m"
CLR_YELLOW="\033[1;33m"
CLR_BLUE="\033[1;34m"
CLR_CYAN="\033[1;36m"
CLR_BOLD="\033[1m"

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Master E2E Test Runner for 3DGS & OSCD Automation Scripts Suite.

Options:
  --tier <tier>       Run a specific test tier:
                        shellcheck : Static analysis of bash scripts
                        1          : Tier 1 Feature coverage & isolated checks
                        2          : Tier 2 Boundary & failure cases
                        3          : Tier 3 Pairwise flag combinations
                        4          : Tier 4 Real-world end-to-end scenarios
                        all        : Run all test tiers (default)
  --verbose, -v       Show detailed diagnostic logs
  --keep-temp         Retain temporary mock sandboxes after test completion
  --help, -h          Show this help message and exit
EOF
}

TARGET_TIER="all"
VERBOSE=false
export KEEP_TEMP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier)
            [[ $# -ge 2 ]] || { echo -e "${CLR_RED}Error: --tier requires an argument${CLR_RESET}" >&2; exit 1; }
            TARGET_TIER="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --keep-temp)
            export KEEP_TEMP=1
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${CLR_RED}Error: Unknown option: $1${CLR_RESET}" >&2
            show_help
            exit 1
            ;;
    esac
done

echo -e "${CLR_BOLD}================================================================${CLR_RESET}"
echo -e "${CLR_BOLD}      3DGS & OSCD Automation Scripts - Master Test Runner       ${CLR_RESET}"
echo -e "${CLR_BOLD}================================================================${CLR_RESET}"
echo -e "Executing test tier: ${CLR_CYAN}${TARGET_TIER}${CLR_RESET}"
echo -e "Verbose mode:        ${CLR_CYAN}${VERBOSE}${CLR_RESET}"
echo -e "Keep temp sandboxes: ${CLR_CYAN}${KEEP_TEMP}${CLR_RESET}"
echo ""

SUITES=()

case "${TARGET_TIER}" in
    shellcheck)
        SUITES+=("${SCRIPT_DIR}/test_shellcheck.sh")
        ;;
    1|tier1)
        SUITES+=("${SCRIPT_DIR}/test_tier1_features.sh")
        ;;
    2|tier2)
        SUITES+=("${SCRIPT_DIR}/test_tier2_boundaries.sh")
        ;;
    3|tier3)
        SUITES+=("${SCRIPT_DIR}/test_tier3_combinations.sh")
        ;;
    4|tier4)
        SUITES+=("${SCRIPT_DIR}/test_tier4_scenarios.sh")
        ;;
    all)
        SUITES+=(
            "${SCRIPT_DIR}/test_shellcheck.sh"
            "${SCRIPT_DIR}/test_tier1_features.sh"
            "${SCRIPT_DIR}/test_tier2_boundaries.sh"
            "${SCRIPT_DIR}/test_tier3_combinations.sh"
            "${SCRIPT_DIR}/test_tier4_scenarios.sh"
        )
        ;;
    *)
        echo -e "${CLR_RED}Error: Invalid tier '${TARGET_TIER}'. Valid options: shellcheck, 1, 2, 3, 4, all${CLR_RESET}" >&2
        exit 1
        ;;
esac

OVERALL_EXIT=0
SUITE_RESULTS=()

for suite in "${SUITES[@]}"; do
    suite_name="$(basename "${suite}")"
    echo -e "${CLR_BLUE}▶ Running Suite: ${suite_name}${CLR_RESET}"
    echo "----------------------------------------------------------------"

    if [[ ! -f "${suite}" ]]; then
        echo -e "${CLR_RED}Error: Suite file not found: ${suite}${CLR_RESET}" >&2
        OVERALL_EXIT=1
        SUITE_RESULTS+=("${suite_name}: MISSING")
        continue
    fi

    # Make executable if needed
    chmod +x "${suite}" 2>/dev/null || true

    # Execute suite
    set +e
    if [[ "${VERBOSE}" == "true" ]]; then
        bash "${suite}"
        suite_rc=$?
    else
        suite_output="$(bash "${suite}" 2>&1)"
        suite_rc=$?
        echo "${suite_output}"
    fi
    set -e

    if [[ ${suite_rc} -eq 0 ]]; then
        echo -e "${CLR_GREEN}✓ Suite Succeeded: ${suite_name}${CLR_RESET}\n"
        SUITE_RESULTS+=("${suite_name}: PASSED")
    else
        echo -e "${CLR_RED}✗ Suite Failed: ${suite_name} (Exit code: ${suite_rc})${CLR_RESET}\n"
        OVERALL_EXIT=1
        SUITE_RESULTS+=("${suite_name}: FAILED (code ${suite_rc})")
    fi
done

echo -e "${CLR_BOLD}================================================================${CLR_RESET}"
echo -e "${CLR_BOLD}                    OVERALL EXECUTION REPORT                    ${CLR_RESET}"
echo -e "${CLR_BOLD}================================================================${CLR_RESET}"
for result in "${SUITE_RESULTS[@]}"; do
    if [[ "${result}" == *"PASSED"* ]]; then
        echo -e "  ${CLR_GREEN}✓ ${result}${CLR_RESET}"
    elif [[ "${result}" == *"FAILED"* ]]; then
        echo -e "  ${CLR_RED}✗ ${result}${CLR_RESET}"
    else
        echo -e "  ${CLR_YELLOW}○ ${result}${CLR_RESET}"
    fi
done
echo -e "${CLR_BOLD}================================================================${CLR_RESET}"

if [[ ${OVERALL_EXIT} -eq 0 ]]; then
    echo -e "${CLR_GREEN}${CLR_BOLD}ALL TEST TIERS COMPLETED SUCCESSFULLY (0 UNHANDLED FAILURES)${CLR_RESET}\n"
    exit 0
else
    echo -e "${CLR_RED}${CLR_BOLD}TEST RUNNER REPORTED FAILURES IN ONE OR MORE TIERS${CLR_RESET}\n"
    exit 1
fi
