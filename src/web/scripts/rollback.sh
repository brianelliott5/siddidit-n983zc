#!/usr/bin/env bash

# Rollback script for Hello World web application
# Version: 1.0
# Dependencies:
# - docker-compose v2.21.0
# - aws-cli v2.13.0
# - curl v8.1.0

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Trap errors and interrupts
trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR
trap 'cleanup' EXIT
trap 'handle_interrupt' INT TERM

# Global variables with defaults
ENVIRONMENT=${ENVIRONMENT:-staging}
DOCKER_COMPOSE_FILE="docker-compose.yml"
PROD_COMPOSE_FILE="docker-compose.prod.yml"
HEALTH_CHECK_URL="http://localhost"
MAX_RETRIES=3
RETRY_INTERVAL=10
PREVIOUS_VERSION=${PREVIOUS_VERSION:-}
LOG_LEVEL=${LOG_LEVEL:-INFO}
GRACEFUL_TIMEOUT=30
AWS_REGION=${AWS_REGION:-us-east-1}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOCKFILE="/tmp/hello_world_rollback.lock"
LOG_FILE="/var/log/hello-world/rollback_${TIMESTAMP}.log"

# Logging functions
log() {
    local level=$1
    shift
    local message=$*
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
    
    # Send critical logs to CloudWatch
    if [[ "${level}" == "ERROR" || "${level}" == "CRITICAL" ]]; then
        aws cloudwatch put-metric-data \
            --region "${AWS_REGION}" \
            --namespace "HelloWorld/Rollback" \
            --metric-name "RollbackErrors" \
            --value 1 \
            --timestamp "$(date -u +%FT%TZ)"
    fi
}

# Error handler function
error_handler() {
    local exit_code=$1
    local line_number=$2
    local bash_lineno=$3
    local last_command=$4
    local func_trace=$5
    
    log "ERROR" "Error in script at line ${line_number}"
    log "ERROR" "Exit code: ${exit_code}"
    log "ERROR" "Command: ${last_command}"
    log "ERROR" "Function trace: ${func_trace}"
    
    # Update monitoring
    update_monitoring "${ENVIRONMENT}" "FAILED"
    
    # Cleanup and exit
    cleanup
    exit "${exit_code}"
}

# Cleanup function
cleanup() {
    log "INFO" "Performing cleanup operations"
    rm -f "${LOCKFILE}"
    
    # Remove temporary files
    find /tmp -name "hello_world_rollback_*" -type f -mmin +60 -delete
    
    # Archive logs older than 7 days
    find /var/log/hello-world -name "rollback_*.log" -type f -mtime +7 \
        -exec gzip {} \; \
        -exec mv {}.gz /var/log/hello-world/archive/ \;
}

# Handle interrupt signals
handle_interrupt() {
    log "WARN" "Received interrupt signal"
    cleanup
    exit 130
}

# Check prerequisites function
check_prerequisites() {
    log "INFO" "Checking prerequisites"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root"
        exit 1
    }
    
    # Check required tools
    local required_tools=("docker-compose" "aws" "curl")
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            log "ERROR" "Required tool not found: ${tool}"
            exit 1
        fi
    done
    
    # Verify Docker Compose version
    local compose_version=$(docker-compose version --short)
    if [[ "${compose_version}" < "2.21.0" ]]; then
        log "ERROR" "Docker Compose version must be >= 2.21.0"
        exit 1
    }
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log "ERROR" "Invalid AWS credentials"
        exit 1
    }
    
    # Verify previous version exists
    if [[ -z "${PREVIOUS_VERSION}" ]]; then
        log "ERROR" "PREVIOUS_VERSION environment variable not set"
        exit 1
    }
    
    # Check lock file
    if [[ -f "${LOCKFILE}" ]]; then
        log "ERROR" "Another rollback process is running"
        exit 1
    fi
    touch "${LOCKFILE}"
    
    return 0
}

# Stop current deployment function
stop_current_deployment() {
    local environment=$1
    log "INFO" "Stopping current deployment in ${environment}"
    
    # Select appropriate compose file
    local compose_file="${DOCKER_COMPOSE_FILE}"
    [[ "${environment}" == "production" ]] && compose_file="${PROD_COMPOSE_FILE}"
    
    # Gracefully stop containers
    if ! docker-compose -f "${compose_file}" stop -t "${GRACEFUL_TIMEOUT}"; then
        log "WARN" "Graceful stop failed, forcing container shutdown"
        docker-compose -f "${compose_file}" kill
    fi
    
    # Wait for containers to stop
    local timeout=30
    while docker-compose -f "${compose_file}" ps --quiet | grep -q .; do
        ((timeout--))
        if [[ ${timeout} -le 0 ]]; then
            log "ERROR" "Timeout waiting for containers to stop"
            return 1
        fi
        sleep 1
    done
    
    return 0
}

# Rollback to previous version function
rollback_to_previous() {
    local environment=$1
    local previous_version=$2
    log "INFO" "Rolling back to version ${previous_version} in ${environment}"
    
    # Select appropriate compose file
    local compose_file="${DOCKER_COMPOSE_FILE}"
    [[ "${environment}" == "production" ]] && compose_file="${PROD_COMPOSE_FILE}"
    
    # Pull previous version image
    local retries=${MAX_RETRIES}
    while ! docker-compose -f "${compose_file}" pull; do
        ((retries--))
        if [[ ${retries} -le 0 ]]; then
            log "ERROR" "Failed to pull previous version image"
            return 1
        fi
        sleep "${RETRY_INTERVAL}"
    done
    
    # Start containers with previous version
    export PREVIOUS_VERSION="${previous_version}"
    if ! docker-compose -f "${compose_file}" up -d; then
        log "ERROR" "Failed to start containers with previous version"
        return 1
    fi
    
    return 0
}

# Health check function
health_check() {
    local url=$1
    local retries=$2
    local interval=$3
    log "INFO" "Performing health checks against ${url}"
    
    while ((retries > 0)); do
        if curl -sf "${url}" &> /dev/null; then
            # Verify response content
            if curl -s "${url}" | grep -q "Hello World"; then
                log "INFO" "Health check passed"
                return 0
            fi
        fi
        
        ((retries--))
        if [[ ${retries} -gt 0 ]]; then
            sleep "${interval}"
        fi
    done
    
    log "ERROR" "Health check failed"
    return 1
}

# Update monitoring function
update_monitoring() {
    local environment=$1
    local version=$2
    log "INFO" "Updating monitoring for ${environment} with version ${version}"
    
    # Update CloudWatch metrics
    aws cloudwatch put-metric-data \
        --region "${AWS_REGION}" \
        --namespace "HelloWorld/Rollback" \
        --metric-name "RollbackStatus" \
        --dimensions Environment="${environment}" \
        --value "$(if [[ "${version}" == "FAILED" ]]; then echo 0; else echo 1; fi)" \
        --timestamp "$(date -u +%FT%TZ)"
    
    # Create CloudWatch log entry
    aws logs put-log-events \
        --region "${AWS_REGION}" \
        --log-group-name "/hello-world/rollback" \
        --log-stream-name "${TIMESTAMP}" \
        --log-events timestamp="$(date +%s)000",message="Rollback to ${version} in ${environment}"
    
    return 0
}

# Main function
main() {
    log "INFO" "Starting rollback process"
    
    # Check prerequisites
    check_prerequisites || exit 1
    
    # Create rollback checkpoint
    cp "${LOG_FILE}" "${LOG_FILE}.checkpoint"
    
    # Stop current deployment
    if ! stop_current_deployment "${ENVIRONMENT}"; then
        log "ERROR" "Failed to stop current deployment"
        exit 1
    fi
    
    # Execute rollback
    if ! rollback_to_previous "${ENVIRONMENT}" "${PREVIOUS_VERSION}"; then
        log "ERROR" "Failed to rollback to previous version"
        exit 1
    fi
    
    # Perform health checks
    if ! health_check "${HEALTH_CHECK_URL}" "${MAX_RETRIES}" "${RETRY_INTERVAL}"; then
        log "ERROR" "Health check failed after rollback"
        exit 1
    fi
    
    # Update monitoring
    if ! update_monitoring "${ENVIRONMENT}" "${PREVIOUS_VERSION}"; then
        log "WARN" "Failed to update monitoring"
    fi
    
    log "INFO" "Rollback completed successfully"
    return 0
}

# Execute main function
main "$@"