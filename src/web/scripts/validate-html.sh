#!/bin/bash

# HTML Validation Script v1.0.0
# Validates HTML files against W3C standards with comprehensive error handling
# Supports both local and remote validation with detailed reporting
# Requirements: html5validator (v0.4.0+), curl, tput

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_DEPENDENCY_ERROR=2
readonly EXIT_INVALID_ARGS=3

# Default configuration
DEBUG=${DEBUG:-false}
QUIET_MODE=${QUIET_MODE:-false}
COLOR_OUTPUT=${COLOR_OUTPUT:-true}
VALIDATION_TIMEOUT=${VALIDATION_TIMEOUT:-30}
W3C_VALIDATOR_URL="https://validator.w3.org/nu/?out=json"

# Color codes (if supported)
if [[ "$COLOR_OUTPUT" == "true" ]] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    RESET=""
fi

# Logging functions
log_debug() {
    [[ "$DEBUG" == "true" ]] && echo "${YELLOW}[DEBUG]${RESET} $*" >&2
}

log_error() {
    [[ "$QUIET_MODE" != "true" ]] && echo "${RED}[ERROR]${RESET} $*" >&2
}

log_success() {
    [[ "$QUIET_MODE" != "true" ]] && echo "${GREEN}[SUCCESS]${RESET} $*"
}

log_info() {
    [[ "$QUIET_MODE" != "true" ]] && echo "[INFO] $*"
}

# Print usage instructions
print_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <html-file>

Validates HTML files against W3C standards for HTML5 compliance and accessibility.

Options:
    -h, --help              Show this help message
    -d, --debug            Enable debug output
    -q, --quiet            Suppress all output except errors
    -n, --no-color         Disable colored output
    -t, --timeout SECONDS  Set validation timeout (default: 30s)
    -r, --remote-only      Use only remote W3C validation
    -l, --local-only       Use only local html5validator

Environment variables:
    DEBUG                  Enable debug mode (true/false)
    QUIET_MODE             Enable quiet mode (true/false)
    COLOR_OUTPUT           Enable colored output (true/false)
    VALIDATION_TIMEOUT     Validation timeout in seconds

Examples:
    $(basename "$0") index.html
    $(basename "$0") --debug index.html
    $(basename "$0") --remote-only index.html

Requirements:
    - html5validator (v0.4.0+)
    - curl
    - tput (for colored output)
EOF
}

# Check if all required dependencies are installed
check_dependencies() {
    local missing_deps=0

    # Check html5validator
    if ! command -v html5validator >/dev/null 2>&1; then
        log_error "html5validator not found. Install with: pip install html5validator>=0.4.0"
        missing_deps=1
    else
        local version
        version=$(html5validator --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
        if [[ "$(printf '%s\n' "0.4.0" "$version" | sort -V | head -n1)" == "$version" ]]; then
            log_error "html5validator version $version is too old. Version 0.4.0 or higher required."
            missing_deps=1
        fi
    fi

    # Check curl
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl not found. Install curl package using your system's package manager."
        missing_deps=1
    fi

    # Check tput (optional)
    if [[ "$COLOR_OUTPUT" == "true" ]] && ! command -v tput >/dev/null 2>&1; then
        log_info "tput not found. Colored output will be disabled."
        COLOR_OUTPUT=false
    fi

    [[ $missing_deps -eq 1 ]] && return $EXIT_DEPENDENCY_ERROR
    return $EXIT_SUCCESS
}

# Validate HTML file using local html5validator
validate_html_local() {
    local file_path=$1
    local validation_output
    local exit_code

    log_debug "Starting local validation of $file_path"

    # Check file size
    local file_size
    file_size=$(wc -c < "$file_path")
    if [[ $file_size -gt 1024 ]]; then
        log_error "File size exceeds 1KB limit (size: $file_size bytes)"
        return $EXIT_FAILURE
    fi

    # Run html5validator with WCAG checks
    validation_output=$(html5validator \
        --format json \
        --also-check-css \
        --also-check-svg \
        --wcag 2.1 A \
        "$file_path" 2>&1)
    exit_code=$?

    log_debug "html5validator exit code: $exit_code"
    log_debug "Validation output: $validation_output"

    if [[ $exit_code -eq 0 ]]; then
        log_success "Local validation passed successfully"
        return $EXIT_SUCCESS
    else
        log_error "Local validation failed:"
        echo "$validation_output" | grep -E "error|warning" >&2
        return $EXIT_FAILURE
    fi
}

# Validate HTML file using remote W3C validator
validate_html_remote() {
    local file_path=$1
    local response
    local exit_code

    log_debug "Starting remote validation of $file_path"

    # Submit file to W3C validator
    response=$(curl -sS --max-time "$VALIDATION_TIMEOUT" \
        -H "Content-Type: text/html; charset=utf-8" \
        --data-binary "@$file_path" \
        "$W3C_VALIDATOR_URL")
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to connect to W3C validator service (curl exit code: $exit_code)"
        return $EXIT_FAILURE
    fi

    # Parse validation results
    if echo "$response" | grep -q '"type":"error"'; then
        log_error "Remote validation failed:"
        echo "$response" | grep -Eo '"message":"[^"]*"' | cut -d'"' -f4 >&2
        return $EXIT_FAILURE
    else
        log_success "Remote validation passed successfully"
        return $EXIT_SUCCESS
    fi
}

# Main validation function
main() {
    local file_path=""
    local local_only=false
    local remote_only=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit $EXIT_SUCCESS
                ;;
            -d|--debug)
                DEBUG=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -n|--no-color)
                COLOR_OUTPUT=false
                shift
                ;;
            -t|--timeout)
                VALIDATION_TIMEOUT=$2
                shift 2
                ;;
            -r|--remote-only)
                remote_only=true
                shift
                ;;
            -l|--local-only)
                local_only=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit $EXIT_INVALID_ARGS
                ;;
            *)
                file_path=$1
                shift
                ;;
        esac
    done

    # Validate arguments
    if [[ -z "$file_path" ]]; then
        log_error "No HTML file specified"
        print_usage
        exit $EXIT_INVALID_ARGS
    fi

    if [[ ! -f "$file_path" ]]; then
        log_error "File not found: $file_path"
        exit $EXIT_INVALID_ARGS
    fi

    if [[ "$local_only" == "true" && "$remote_only" == "true" ]]; then
        log_error "Cannot specify both --local-only and --remote-only"
        exit $EXIT_INVALID_ARGS
    fi

    # Check dependencies
    check_dependencies || exit $?

    # Perform validation
    if [[ "$remote_only" == "true" ]]; then
        validate_html_remote "$file_path"
    elif [[ "$local_only" == "true" ]]; then
        validate_html_local "$file_path"
    else
        # Try local validation first, fall back to remote
        log_info "Attempting local validation..."
        if ! validate_html_local "$file_path"; then
            log_info "Local validation failed, trying remote validation..."
            validate_html_remote "$file_path"
        fi
    fi
}

# Export functions for testing
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f validate_html_local
    export -f validate_html_remote
else
    main "$@"
fi