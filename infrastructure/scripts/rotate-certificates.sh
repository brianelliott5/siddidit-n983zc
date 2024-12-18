#!/usr/bin/env bash

# SSL/TLS Certificate Rotation Script for Hello World Web Application
# Version: 1.0.0
# Last Updated: 2024-01-22
# Dependencies:
#   - certbot: 2.0+
#   - openssl: 1.1.1+
#   - aws-cli: 2.0+

# Enable strict error handling
set -euo pipefail
IFS=$'\n\t'

# Source infrastructure initialization script for environment variables
# shellcheck source=./init-infrastructure.sh
source "$(dirname "${BASH_SOURCE[0]}")/init-infrastructure.sh"

# Global Constants
readonly SCRIPT_NAME=$(basename "${0}")
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly CERT_PATH="${CERT_PATH:-/etc/letsencrypt/live}"
readonly BACKUP_DIR="${BACKUP_DIR:-/etc/ssl/backup}"
readonly LOG_FILE="${LOG_FILE:-/var/log/cert-rotation.log}"
readonly METRIC_NAMESPACE="${METRIC_NAMESPACE:-HelloWorld/Certificates}"
readonly RATE_LIMIT_REQUESTS="${RATE_LIMIT_REQUESTS:-50}"
readonly BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
readonly OPERATION_TIMEOUT="${OPERATION_TIMEOUT:-300}"

# Logging function with ISO 8601 timestamp
log() {
    local level=$1
    shift
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [${level}] [${SCRIPT_NAME}] $*" | tee -a "${LOG_FILE}"
}

# Error handler
error_handler() {
    local exit_code=$?
    local line_number=$1
    log "ERROR" "Failed at line ${line_number} with exit code ${exit_code}"
    
    # Emit error metric
    aws cloudwatch put-metric-data \
        --namespace "${METRIC_NAMESPACE}" \
        --metric-name "CertificateRotationError" \
        --value 1 \
        --unit Count \
        --dimensions Environment="${ENVIRONMENT}"
    
    cleanup_and_exit ${exit_code}
}

trap 'error_handler ${LINENO}' ERR

# Cleanup function
cleanup_and_exit() {
    local exit_code=$1
    log "INFO" "Performing cleanup..."
    
    # Remove temporary files
    rm -f /tmp/cert-*.pem
    
    # Remove old backups
    find "${BACKUP_DIR}" -type f -mtime "+${BACKUP_RETENTION_DAYS}" -delete
    
    exit "${exit_code}"
}

# Function to check certbot prerequisites
check_certbot() {
    log "INFO" "Checking certbot prerequisites..."
    
    # Verify certbot installation
    if ! command -v certbot >/dev/null 2>&1; then
        log "ERROR" "Certbot is not installed"
        return 1
    fi
    
    # Check certbot version
    local certbot_version
    certbot_version=$(certbot --version | grep -oP '\d+\.\d+\.\d+')
    if ! [[ "${certbot_version}" =~ ^2\. ]]; then
        log "ERROR" "Certbot version 2.0+ is required, found ${certbot_version}"
        return 1
    }
    
    # Verify required directories
    local required_dirs=("${CERT_PATH}" "${BACKUP_DIR}" "$(dirname "${LOG_FILE}")")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}"
            chmod 750 "${dir}"
        fi
    done
    
    # Check rate limits
    local daily_requests
    daily_requests=$(certbot certificates 2>/dev/null | grep -c "VALID:")
    if ((daily_requests >= RATE_LIMIT_REQUESTS)); then
        log "ERROR" "Rate limit exceeded: ${daily_requests}/${RATE_LIMIT_REQUESTS} requests"
        return 1
    }
    
    return 0
}

# Function to backup current certificates
backup_current_certs() {
    local domain_name=$1
    log "INFO" "Backing up certificates for ${domain_name}..."
    
    # Create backup directory with timestamp
    local backup_path="${BACKUP_DIR}/${domain_name}/${TIMESTAMP}"
    mkdir -p "${backup_path}"
    
    # Import backup function from backup.sh
    source "${SCRIPT_DIR}/backup.sh"
    
    # Backup certificates using imported function
    if ! backup_certificates "${backup_path}"; then
        log "ERROR" "Certificate backup failed"
        return 1
    fi
    
    # Verify backup integrity
    if ! verify_backup_integrity "${backup_path}"; then
        log "ERROR" "Backup integrity verification failed"
        return 1
    }
    
    # Set secure permissions
    chmod -R 600 "${backup_path}"
    chmod 700 "$(dirname "${backup_path}")"
    
    # Emit backup metric
    aws cloudwatch put-metric-data \
        --namespace "${METRIC_NAMESPACE}" \
        --metric-name "CertificateBackupSuccess" \
        --value 1 \
        --unit Count \
        --dimensions Environment="${ENVIRONMENT}"
    
    return 0
}

# Function to rotate certificates
rotate_certificates() {
    local domain_name=$1
    local email=$2
    log "INFO" "Rotating certificates for ${domain_name}..."
    
    # Stop nginx service
    systemctl stop nginx
    
    # Request new certificate
    if ! certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "${email}" \
        --domain "${domain_name}" \
        --rsa-key-size 4096 \
        --must-staple \
        --staple-ocsp \
        --http-01-port 80; then
        log "ERROR" "Certificate rotation failed"
        systemctl start nginx
        return 1
    fi
    
    # Verify new certificates
    if ! verify_new_certs "${domain_name}"; then
        log "ERROR" "New certificate verification failed"
        rollback_certificates "${domain_name}"
        return 1
    }
    
    # Update permissions
    chown -R root:www-data "${CERT_PATH}/${domain_name}"
    chmod -R 640 "${CERT_PATH}/${domain_name}"
    
    # Start nginx service
    systemctl start nginx
    
    # Emit rotation metric
    aws cloudwatch put-metric-data \
        --namespace "${METRIC_NAMESPACE}" \
        --metric-name "CertificateRotationSuccess" \
        --value 1 \
        --unit Count \
        --dimensions Environment="${ENVIRONMENT}"
    
    return 0
}

# Function to verify new certificates
verify_new_certs() {
    local domain_name=$1
    log "INFO" "Verifying new certificates for ${domain_name}..."
    
    # Check certificate existence
    local cert_file="${CERT_PATH}/${domain_name}/fullchain.pem"
    if [[ ! -f "${cert_file}" ]]; then
        log "ERROR" "Certificate file not found: ${cert_file}"
        return 1
    }
    
    # Verify certificate validity
    if ! openssl x509 -in "${cert_file}" -noout -checkend 0; then
        log "ERROR" "Certificate is not valid"
        return 1
    }
    
    # Check certificate chain
    if ! openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt "${cert_file}"; then
        log "ERROR" "Certificate chain verification failed"
        return 1
    }
    
    # Verify key pair
    local key_file="${CERT_PATH}/${domain_name}/privkey.pem"
    if ! openssl x509 -noout -modulus -in "${cert_file}" | \
        openssl md5 | \
        grep -q "$(openssl rsa -noout -modulus -in "${key_file}" | openssl md5)"; then
        log "ERROR" "Certificate and key do not match"
        return 1
    }
    
    return 0
}

# Function to rollback certificates
rollback_certificates() {
    local domain_name=$1
    log "INFO" "Rolling back certificates for ${domain_name}..."
    
    # Find latest backup
    local latest_backup
    latest_backup=$(find "${BACKUP_DIR}/${domain_name}" -type d -name "*" | sort -r | head -n1)
    
    if [[ -z "${latest_backup}" ]]; then
        log "ERROR" "No backup found for rollback"
        return 1
    }
    
    # Stop nginx service
    systemctl stop nginx
    
    # Restore certificates from backup
    if ! cp -a "${latest_backup}"/* "${CERT_PATH}/${domain_name}/"; then
        log "ERROR" "Certificate restoration failed"
        return 1
    }
    
    # Verify restored certificates
    if ! verify_new_certs "${domain_name}"; then
        log "ERROR" "Restored certificate verification failed"
        return 1
    }
    
    # Update permissions
    chown -R root:www-data "${CERT_PATH}/${domain_name}"
    chmod -R 640 "${CERT_PATH}/${domain_name}"
    
    # Start nginx service
    systemctl start nginx
    
    # Emit rollback metric
    aws cloudwatch put-metric-data \
        --namespace "${METRIC_NAMESPACE}" \
        --metric-name "CertificateRollbackRequired" \
        --value 1 \
        --unit Count \
        --dimensions Environment="${ENVIRONMENT}"
    
    return 0
}

# Function to cleanup old certificates and backups
cleanup() {
    log "INFO" "Cleaning up old certificates and backups..."
    
    # Remove expired certificates
    find "${CERT_PATH}" -type f -name "cert*.pem" -mtime "+${BACKUP_RETENTION_DAYS}" -delete
    
    # Remove old backups
    find "${BACKUP_DIR}" -type d -mtime "+${BACKUP_RETENTION_DAYS}" -exec rm -rf {} +
    
    # Clean up logs
    find "$(dirname "${LOG_FILE}")" -type f -name "cert-rotation*.log" -mtime "+${BACKUP_RETENTION_DAYS}" -delete
    
    return 0
}

# Main execution
main() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <domain_name> <email>"
        exit 1
    fi
    
    local domain_name=$1
    local email=$2
    
    log "INFO" "Starting certificate rotation for ${domain_name}"
    
    # Set timeout for entire operation
    timeout "${OPERATION_TIMEOUT}" bash -c "
        # Check prerequisites
        if ! check_certbot; then
            log 'ERROR' 'Prerequisites check failed'
            exit 1
        fi
        
        # Backup current certificates
        if ! backup_current_certs '${domain_name}'; then
            log 'ERROR' 'Certificate backup failed'
            exit 1
        fi
        
        # Rotate certificates
        if ! rotate_certificates '${domain_name}' '${email}'; then
            log 'ERROR' 'Certificate rotation failed'
            exit 1
        fi
        
        # Cleanup old certificates and backups
        if ! cleanup; then
            log 'WARNING' 'Cleanup operation failed'
        fi
        
        log 'INFO' 'Certificate rotation completed successfully'
        exit 0
    "
    
    exit_code=$?
    if [[ ${exit_code} -eq 124 ]]; then
        log "ERROR" "Certificate rotation timed out after ${OPERATION_TIMEOUT} seconds"
    fi
    
    cleanup_and_exit ${exit_code}
}

# Execute main function with provided arguments
main "$@"