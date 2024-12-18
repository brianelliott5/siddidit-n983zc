#!/bin/bash

# Build Script for Hello World Web Application v1.0.0
# Builds Docker container with comprehensive validation and security checks
# Dependencies: docker v20.10+, docker-compose v2.0+, trivy

# Import local validation script
# @version v1.0.0
source "$(dirname "$0")/validate-html.sh"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1

# Build configuration
readonly DOCKER_IMAGE_NAME="hello-world-web"
readonly DOCKER_IMAGE_TAG="latest"
readonly VALIDATION_TIMEOUT=30
readonly SECURITY_SCAN_LEVEL="HIGH"
readonly BUILD_CACHE_DIR="/tmp/docker-build-cache"
readonly LOG_DIR="/var/log/build"

# Ensure required build environment variables
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Logging setup
setup_logging() {
    mkdir -p "$LOG_DIR"
    exec 1> >(tee -a "${LOG_DIR}/build.log")
    exec 2> >(tee -a "${LOG_DIR}/build.error.log")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Build script started"
}

# Log function execution with timing
log_function_call() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: $1"
}

# Check if all required dependencies are installed and properly configured
check_dependencies() {
    log_function_call "${FUNCNAME[0]}"
    
    local status=0

    # Check Docker version and daemon
    if ! docker version --format '{{.Server.Version}}' 2>/dev/null | grep -qE '^2[0-9]\.' ; then
        echo "Error: Docker version 20.10+ is required"
        status=1
    fi

    # Check Docker Compose
    if ! docker-compose version --short 2>/dev/null | grep -qE '^2\.' ; then
        echo "Error: Docker Compose version 2.0+ is required"
        status=1
    fi

    # Check Trivy scanner
    if ! command -v trivy >/dev/null 2>&1; then
        echo "Error: Trivy security scanner not found"
        status=1
    fi

    # Check build directory permissions
    if [[ ! -w "$(dirname "$0")" ]]; then
        echo "Error: Build directory is not writable"
        status=1
    fi

    # Check available disk space (minimum 1GB)
    if [[ $(df -P . | awk 'NR==2 {print $4}') -lt 1048576 ]]; then
        echo "Error: Insufficient disk space"
        status=1
    fi

    return $status
}

# Validate all required files and configurations
validate_files() {
    log_function_call "${FUNCNAME[0]}"
    
    local status=0
    local project_root
    project_root="$(dirname "$0")/.."

    # Validate HTML file
    if ! validate_html_local "${project_root}/src/index.html"; then
        echo "Error: HTML validation failed"
        status=1
    fi

    # Validate Dockerfile existence and syntax
    if [[ ! -f "${project_root}/Dockerfile" ]]; then
        echo "Error: Dockerfile not found"
        status=1
    else
        if ! docker run --rm -i hadolint/hadolint < "${project_root}/Dockerfile"; then
            echo "Error: Dockerfile validation failed"
            status=1
        fi
    fi

    # Validate docker-compose.yml
    if [[ ! -f "${project_root}/docker-compose.yml" ]]; then
        echo "Error: docker-compose.yml not found"
        status=1
    else
        if ! docker-compose -f "${project_root}/docker-compose.yml" config >/dev/null; then
            echo "Error: docker-compose.yml validation failed"
            status=1
        fi
    fi

    return $status
}

# Build and validate the Docker container
build_container() {
    log_function_call "${FUNCNAME[0]}"
    
    local status=0
    local project_root
    project_root="$(dirname "$0")/.."

    # Setup build cache
    mkdir -p "$BUILD_CACHE_DIR"
    
    # Build container
    if ! docker-compose -f "${project_root}/docker-compose.yml" build \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VERSION="1.0.0" \
        --no-cache; then
        echo "Error: Container build failed"
        status=1
    fi

    # Security scan
    if [[ $status -eq 0 ]]; then
        if ! trivy image --severity "$SECURITY_SCAN_LEVEL" \
            --no-progress \
            "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"; then
            echo "Error: Security scan failed"
            status=1
        fi
    fi

    # Tag image if build successful
    if [[ $status -eq 0 ]]; then
        docker tag "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" \
            "${DOCKER_IMAGE_NAME}:$(date +%Y%m%d)"
    fi

    return $status
}

# Cleanup function
cleanup() {
    log_function_call "${FUNCNAME[0]}"
    
    # Remove build cache
    rm -rf "$BUILD_CACHE_DIR"
    
    # Remove dangling images
    docker image prune -f
}

# Main execution function
main() {
    local status=0

    # Setup logging
    setup_logging

    # Check dependencies
    if ! check_dependencies; then
        echo "Error: Dependency check failed"
        return $EXIT_FAILURE
    fi

    # Validate files
    if ! validate_files; then
        echo "Error: File validation failed"
        return $EXIT_FAILURE
    fi

    # Build container
    if ! build_container; then
        echo "Error: Container build failed"
        status=$EXIT_FAILURE
    fi

    # Cleanup
    cleanup

    # Generate build report
    {
        echo "Build Report"
        echo "============"
        echo "Date: $(date)"
        echo "Status: $([[ $status -eq 0 ]] && echo 'Success' || echo 'Failed')"
        echo "Image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
        echo "Security Scan Level: $SECURITY_SCAN_LEVEL"
    } > "${LOG_DIR}/build-report.txt"

    return $status
}

# Export build_container function for CI/CD integration
export -f build_container

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi