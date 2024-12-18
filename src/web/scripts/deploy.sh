#!/usr/bin/env bash

# deploy.sh - Deployment script for Hello World web application
# Version: 1.0
# IE2: docker-compose v2.21.0, aws-cli v2.13.0, curl v8.1.0

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Global variables
ENVIRONMENT="${ENVIRONMENT:-staging}"
DOCKER_COMPOSE_FILE="../docker-compose.yml"
HEALTH_CHECK_URL="http://localhost"
MAX_RETRIES=3
RETRY_INTERVAL=10
LOG_LEVEL="${LOG_LEVEL:-INFO}"
CLOUDWATCH_GROUP="/hello-world/${ENVIRONMENT}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log() {
    local level="$1"
    shift
    if [[ "${LOG_LEVEL}" == "DEBUG" ]] || [[ "${level}" != "DEBUG" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*" >&2
    fi
}

# Check prerequisites for deployment
check_prerequisites() {
    log "INFO" "Checking prerequisites..."

    # Check Docker and docker-compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        log "ERROR" "docker-compose is not installed"
        return 1
    fi

    # Verify docker-compose version
    local compose_version
    compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
    if [[ "$(printf '%s\n' "2.21.0" "$compose_version" | sort -V | head -n1)" != "2.21.0" ]]; then
        log "ERROR" "docker-compose version must be >= 2.21.0"
        return 1
    }

    # Check AWS CLI if monitoring is enabled
    if [[ "${ENVIRONMENT}" == "production" ]]; then
        if ! command -v aws >/dev/null 2>&1; then
            log "ERROR" "AWS CLI is not installed"
            return 1
        }
        # Verify AWS credentials
        if ! aws sts get-caller-identity >/dev/null 2>&1; then
            log "ERROR" "AWS credentials not configured"
            return 1
        }
    fi

    # Check required files
    local required_files=(
        "${DOCKER_COMPOSE_FILE}"
        "../config/nginx/nginx.conf"
        "../config/security-headers.conf"
        "../src/index.html"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "${SCRIPT_DIR}/${file}" ]]; then
            log "ERROR" "Required file not found: ${file}"
            return 1
        fi
    }

    # Check port availability
    if ! netstat -tuln | grep -q ":80 "; then
        log "DEBUG" "Port 80 is available"
    else
        log "ERROR" "Port 80 is already in use"
        return 1
    fi

    log "INFO" "Prerequisites check passed"
    return 0
}

# Deploy containers
deploy_containers() {
    local env="$1"
    log "INFO" "Deploying containers for environment: ${env}"

    # Pull latest images
    log "DEBUG" "Pulling latest images"
    docker-compose -f "${SCRIPT_DIR}/${DOCKER_COMPOSE_FILE}" pull || {
        log "ERROR" "Failed to pull images"
        return 1
    }

    # Stop existing containers gracefully
    if docker-compose -f "${SCRIPT_DIR}/${DOCKER_COMPOSE_FILE}" ps -q 2>/dev/null; then
        log "DEBUG" "Stopping existing containers"
        docker-compose -f "${SCRIPT_DIR}/${DOCKER_COMPOSE_FILE}" down --remove-orphans || {
            log "ERROR" "Failed to stop existing containers"
            return 1
        }
    fi

    # Start new containers
    log "DEBUG" "Starting containers"
    docker-compose -f "${SCRIPT_DIR}/${DOCKER_COMPOSE_FILE}" up -d || {
        log "ERROR" "Failed to start containers"
        return 1
    }

    log "INFO" "Container deployment completed"
    return 0
}

# Health check function
health_check() {
    local url="$1"
    local retries="$2"
    local interval="$3"
    local attempt=1

    log "INFO" "Starting health checks for ${url}"

    while [[ $attempt -le $retries ]]; do
        log "DEBUG" "Health check attempt ${attempt}/${retries}"

        # Check HTTP response
        local response
        response=$(curl -sS -o /dev/null -w "%{http_code}" "${url}") || {
            log "WARN" "Health check failed (attempt ${attempt}/${retries})"
            attempt=$((attempt + 1))
            sleep "${interval}"
            continue
        }

        if [[ "${response}" == "200" ]]; then
            # Verify security headers
            local headers
            headers=$(curl -sI "${url}")
            
            # Check required security headers
            local required_headers=(
                "Content-Security-Policy"
                "X-Frame-Options"
                "X-Content-Type-Options"
                "Strict-Transport-Security"
                "Referrer-Policy"
            )

            local headers_ok=true
            for header in "${required_headers[@]}"; do
                if ! echo "${headers}" | grep -q "${header}"; then
                    log "WARN" "Missing security header: ${header}"
                    headers_ok=false
                fi
            done

            if [[ "${headers_ok}" == "true" ]]; then
                log "INFO" "Health check passed"
                return 0
            fi
        fi

        attempt=$((attempt + 1))
        sleep "${interval}"
    done

    log "ERROR" "Health check failed after ${retries} attempts"
    return 1
}

# Setup monitoring
setup_monitoring() {
    local env="$1"
    
    if [[ "${env}" != "production" ]]; then
        log "DEBUG" "Skipping monitoring setup for non-production environment"
        return 0
    }

    log "INFO" "Setting up monitoring for ${env}"

    # Create CloudWatch log group if it doesn't exist
    aws logs create-log-group --log-group-name "${CLOUDWATCH_GROUP}" 2>/dev/null || true

    # Set retention policy
    aws logs put-retention-policy \
        --log-group-name "${CLOUDWATCH_GROUP}" \
        --retention-in-days 30

    # Create metric filters
    aws logs put-metric-filter \
        --log-group-name "${CLOUDWATCH_GROUP}" \
        --filter-name "HTTPErrors" \
        --filter-pattern "[timestamp, requestid, HTTP, status_code=4*, size, client]" \
        --metric-transformations \
            metricName=HTTPErrors,metricNamespace=HelloWorld,metricValue=1

    log "INFO" "Monitoring setup completed"
    return 0
}

# Rollback function
rollback() {
    local env="$1"
    local version="$2"

    log "WARN" "Initiating rollback to version ${version} for ${env}"

    # Stop current deployment
    docker-compose -f "${SCRIPT_DIR}/${DOCKER_COMPOSE_FILE}" down --remove-orphans || {
        log "ERROR" "Failed to stop current deployment during rollback"
        return 1
    }

    # Start previous version
    DOCKER_TAG="${version}" docker-compose -f "${SCRIPT_DIR}/${DOCKER_COMPOSE_FILE}" up -d || {
        log "ERROR" "Failed to start previous version during rollback"
        return 1
    }

    log "INFO" "Rollback completed"
    return 0
}

# Cleanup function
cleanup() {
    log "DEBUG" "Performing cleanup"
    # Remove any temporary files or resources
    rm -f /tmp/hello-world-deploy-*
}

# Main function
main() {
    # Set up cleanup trap
    trap cleanup EXIT

    log "INFO" "Starting deployment for environment: ${ENVIRONMENT}"

    # Check prerequisites
    check_prerequisites || {
        log "ERROR" "Prerequisites check failed"
        return 1
    }

    # Deploy containers
    deploy_containers "${ENVIRONMENT}" || {
        log "ERROR" "Container deployment failed"
        return 1
    }

    # Perform health checks
    health_check "${HEALTH_CHECK_URL}" "${MAX_RETRIES}" "${RETRY_INTERVAL}" || {
        log "ERROR" "Health check failed, initiating rollback"
        rollback "${ENVIRONMENT}" "previous"
        return 1
    }

    # Setup monitoring
    setup_monitoring "${ENVIRONMENT}" || {
        log "WARN" "Monitoring setup failed, but deployment will continue"
    }

    log "INFO" "Deployment completed successfully"
    return 0
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi