#!/bin/bash

# Test Script v1.0.0
# Orchestrates all testing operations for Hello World web application
# Including HTML validation, Jest unit tests, and accessibility checks

# Import local validation script
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/validate-html.sh"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1

# Colors for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_RESET='\033[0m'

# Project paths
readonly PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
readonly HTML_FILES_DIR="${PROJECT_ROOT}/src"
readonly TEST_REPORTS_DIR="${PROJECT_ROOT}/test-reports"
readonly JEST_CONFIG="${PROJECT_ROOT}/jest.config.ts"

# Debug mode flag
DEBUG_MODE=${DEBUG_MODE:-false}

# Debug logging function
debug_log() {
    if [[ "${DEBUG_MODE}" == "true" ]]; then
        echo -e "${COLOR_YELLOW}[DEBUG]${COLOR_RESET} $*" >&2
    fi
}

# Check all required testing dependencies
check_dependencies() {
    local missing_deps=0
    debug_log "Checking dependencies..."

    # Check for Jest
    if ! command -v jest >/dev/null 2>&1; then
        echo -e "${COLOR_RED}Error: Jest is not installed${COLOR_RESET}"
        echo "Install Jest with: npm install --save-dev jest@^29.0.0"
        missing_deps=1
    fi

    # Check for html5validator
    if ! command -v html5validator >/dev/null 2>&1; then
        echo -e "${COLOR_RED}Error: html5validator is not installed${COLOR_RESET}"
        echo "Install html5validator with: pip install html5validator>=2.0.0"
        missing_deps=1
    fi

    # Check for node_modules
    if [[ ! -d "${PROJECT_ROOT}/node_modules" ]]; then
        echo -e "${COLOR_RED}Error: node_modules not found${COLOR_RESET}"
        echo "Run 'npm install' to install dependencies"
        missing_deps=1
    fi

    # Check for Jest config
    if [[ ! -f "${JEST_CONFIG}" ]]; then
        echo -e "${COLOR_RED}Error: Jest configuration not found at ${JEST_CONFIG}${COLOR_RESET}"
        missing_deps=1
    fi

    return $missing_deps
}

# Run HTML validation tests
run_html_validation() {
    debug_log "Starting HTML validation..."
    local validation_status=0
    local html_files=()

    # Create test reports directory if it doesn't exist
    mkdir -p "${TEST_REPORTS_DIR}/html-validation"

    # Find all HTML files
    while IFS= read -r -d '' file; do
        html_files+=("$file")
    done < <(find "${HTML_FILES_DIR}" -type f -name "*.html" -print0)

    if [[ ${#html_files[@]} -eq 0 ]]; then
        echo -e "${COLOR_RED}Error: No HTML files found to validate${COLOR_RESET}"
        return 1
    fi

    # Validate each HTML file
    for file in "${html_files[@]}"; do
        echo "Validating: ${file}"
        if ! validate_html_local "${file}"; then
            validation_status=1
            echo -e "${COLOR_RED}Validation failed for: ${file}${COLOR_RESET}"
        fi
    done

    return $validation_status
}

# Run Jest test suites
run_jest_tests() {
    debug_log "Starting Jest tests..."
    local jest_status=0

    # Create test reports directory if it doesn't exist
    mkdir -p "${TEST_REPORTS_DIR}/jest"

    # Set Node environment to test
    export NODE_ENV=test

    # Run Jest with coverage
    jest \
        --config="${JEST_CONFIG}" \
        --coverage \
        --coverageDirectory="${TEST_REPORTS_DIR}/jest/coverage" \
        --json --outputFile="${TEST_REPORTS_DIR}/jest/results.json" \
        --testLocationInResults \
        || jest_status=$?

    return $jest_status
}

# Print test summary
print_test_summary() {
    local html_validation_status=$1
    local jest_tests_status=$2
    local summary_file="${TEST_REPORTS_DIR}/test-summary.txt"

    # Create test reports directory if it doesn't exist
    mkdir -p "${TEST_REPORTS_DIR}"

    {
        echo "Test Summary Report"
        echo "=================="
        echo "Generated: $(date)"
        echo
        echo "HTML Validation Status: $([ $html_validation_status -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "Jest Tests Status: $([ $jest_tests_status -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo
        echo "Detailed Results:"
        echo "----------------"
        if [[ -f "${TEST_REPORTS_DIR}/jest/results.json" ]]; then
            echo "Jest Coverage: $(jq '.coverageMap.total.lines.pct' "${TEST_REPORTS_DIR}/jest/results.json")%"
        fi
    } | tee "$summary_file"

    # Print colored summary to console
    if [[ $html_validation_status -eq 0 && $jest_tests_status -eq 0 ]]; then
        echo -e "\n${COLOR_GREEN}All tests passed successfully!${COLOR_RESET}"
    else
        echo -e "\n${COLOR_RED}Some tests failed. Check detailed reports for more information.${COLOR_RESET}"
    fi
}

# Main execution function
main() {
    local exit_status=0
    local html_validation_status=0
    local jest_tests_status=0

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--debug] [--help]"
                echo "Runs all tests for the Hello World web application"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Check dependencies
    if ! check_dependencies; then
        echo -e "${COLOR_RED}Error: Missing required dependencies${COLOR_RESET}"
        exit 1
    fi

    # Create test reports directory
    mkdir -p "${TEST_REPORTS_DIR}"

    # Run HTML validation
    echo "Running HTML validation..."
    if ! run_html_validation; then
        html_validation_status=1
        exit_status=1
    fi

    # Run Jest tests
    echo "Running Jest tests..."
    if ! run_jest_tests; then
        jest_tests_status=1
        exit_status=1
    fi

    # Print test summary
    print_test_summary $html_validation_status $jest_tests_status

    # Clean up temporary files
    find "${TEST_REPORTS_DIR}" -type f -name "*.tmp" -delete

    exit $exit_status
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi