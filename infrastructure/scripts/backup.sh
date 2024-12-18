#!/usr/bin/env bash

# Hello World Web Application Backup Script
# Version: 1.0.0
# Last Updated: 2024-01-22
# Dependencies:
#   - aws-cli: 2.0+
#   - tar: 1.34+
#   - openssl: 1.1.1+

# Enable strict error handling
set -euo pipefail
IFS=$'\n\t'

# Source environment variables from infrastructure initialization
# shellcheck source=./init-infrastructure.sh
source "$(dirname "${BASH_SOURCE[0]}")/init-infrastructure.sh"

# Global Constants
readonly SCRIPT_NAME=$(basename "${0}")
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_ROOT="/var/backups/hello-world"
readonly S3_BUCKET="hello-world-backups-${ENVIRONMENT}"
readonly RETENTION_DAYS=30
readonly LOG_FILE="/var/log/backup.log"
readonly ENCRYPTION_KEY="/etc/backup/encryption.key"
readonly MAX_PARALLEL_UPLOADS=5
readonly BACKUP_TIMEOUT=3600

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
    cleanup_and_exit ${exit_code}
}

trap 'error_handler ${LINENO}' ERR

# Cleanup function
cleanup_and_exit() {
    local exit_code=$1
    log "INFO" "Performing cleanup..."
    
    # Remove temporary files and directories
    rm -rf "${BACKUP_ROOT}/temp"
    
    # Remove files older than retention period
    find "${BACKUP_ROOT}" -type f -mtime +${RETENTION_DAYS} -delete
    
    # Export metrics for monitoring
    if command -v aws >/dev/null 2>&1; then
        aws cloudwatch put-metric-data \
            --namespace "HelloWorldApp" \
            --metric-name "BackupStatus" \
            --value "${exit_code}" \
            --unit Count \
            --dimensions Environment="${ENVIRONMENT}" \
            --region "${AWS_REGION}"
    fi
    
    exit "${exit_code}"
}

# Function to check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check required commands
    local required_commands=("aws" "tar" "openssl" "find" "sha256sum")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            log "ERROR" "Required command not found: ${cmd}"
            return 1
        fi
    done
    
    # Verify AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log "ERROR" "Invalid AWS credentials"
        return 1
    fi
    
    # Check S3 bucket access
    if ! aws s3 ls "s3://${S3_BUCKET}" >/dev/null 2>&1; then
        log "ERROR" "Cannot access S3 bucket: ${S3_BUCKET}"
        return 1
    }
    
    # Verify backup directories
    local required_dirs=("${BACKUP_ROOT}" "$(dirname "${LOG_FILE}")")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}"
            chmod 750 "${dir}"
        fi
    done
    
    # Check encryption key
    if [[ ! -f "${ENCRYPTION_KEY}" ]]; then
        log "ERROR" "Encryption key not found: ${ENCRYPTION_KEY}"
        return 1
    fi
    
    return 0
}

# Function to backup web content
backup_web_content() {
    local backup_path=$1
    local encrypt=${2:-true}
    
    log "INFO" "Starting web content backup..."
    
    # Create backup directory structure
    local temp_dir="${backup_path}/web_content_${TIMESTAMP}"
    mkdir -p "${temp_dir}"
    
    # Copy web content with permissions preserved
    cp -a /var/www/html/* "${temp_dir}/"
    
    # Generate checksums
    find "${temp_dir}" -type f -exec sha256sum {} \; > "${temp_dir}/checksums.sha256"
    
    # Create tar archive
    local archive_name="web_content_${TIMESTAMP}.tar.gz"
    tar -czf "${backup_path}/${archive_name}" -C "${temp_dir}" .
    
    # Encrypt if specified
    if [[ "${encrypt}" == true ]]; then
        openssl enc -aes-256-cbc -salt -in "${backup_path}/${archive_name}" \
            -out "${backup_path}/${archive_name}.enc" -pass file:"${ENCRYPTION_KEY}"
        rm "${backup_path}/${archive_name}"
        archive_name="${archive_name}.enc"
    fi
    
    # Set secure permissions
    chmod 600 "${backup_path}/${archive_name}"
    
    # Cleanup temporary directory
    rm -rf "${temp_dir}"
    
    echo "${archive_name}"
}

# Function to backup SSL certificates
backup_certificates() {
    local backup_path=$1
    
    log "INFO" "Starting SSL certificate backup..."
    
    # Create temporary directory for certificates
    local temp_dir="${backup_path}/ssl_${TIMESTAMP}"
    mkdir -p "${temp_dir}"
    
    # Copy SSL certificates and keys
    if [[ -d "/etc/letsencrypt/live" ]]; then
        cp -rL /etc/letsencrypt/live/* "${temp_dir}/"
        cp -r /etc/letsencrypt/archive "${temp_dir}/"
        cp -r /etc/letsencrypt/renewal "${temp_dir}/"
    fi
    
    # Backup custom SSL certificates if they exist
    if [[ -d "/etc/ssl/certs" ]]; then
        mkdir -p "${temp_dir}/custom_certs"
        cp -r /etc/ssl/certs/* "${temp_dir}/custom_certs/"
    fi
    
    # Create encrypted archive
    local archive_name="ssl_certificates_${TIMESTAMP}.tar.gz"
    tar -czf - -C "${temp_dir}" . | \
        openssl enc -aes-256-cbc -salt -out "${backup_path}/${archive_name}.enc" \
        -pass file:"${ENCRYPTION_KEY}"
    
    # Set secure permissions
    chmod 600 "${backup_path}/${archive_name}.enc"
    
    # Cleanup
    rm -rf "${temp_dir}"
    
    echo "${archive_name}.enc"
}

# Function to upload backups to S3
upload_to_s3() {
    local local_path=$1
    local s3_path=$2
    local parallel_uploads=${3:-${MAX_PARALLEL_UPLOADS}}
    
    log "INFO" "Uploading backups to S3..."
    
    # Create a manifest of files to upload
    find "${local_path}" -type f -name "*.enc" > "${local_path}/upload_manifest.txt"
    
    # Upload files in parallel
    local count=0
    while IFS= read -r file; do
        {
            local basename=$(basename "${file}")
            local s3_key="${s3_path}/${basename}"
            
            # Calculate MD5 hash for integrity verification
            local md5_hash=$(openssl md5 -binary "${file}" | base64)
            
            # Upload to S3 with metadata
            aws s3 cp "${file}" "s3://${S3_BUCKET}/${s3_key}" \
                --metadata "md5checksum=${md5_hash}" \
                --storage-class STANDARD_IA \
                --server-side-encryption aws:kms \
                --metadata-directive REPLACE
                
            log "INFO" "Uploaded ${basename} to S3"
        } &
        
        ((count++))
        if ((count >= parallel_uploads)); then
            wait
            count=0
        fi
    done < "${local_path}/upload_manifest.txt"
    
    # Wait for remaining uploads
    wait
    
    # Verify uploads
    while IFS= read -r file; do
        local basename=$(basename "${file}")
        local s3_key="${s3_path}/${basename}"
        
        # Verify file exists in S3
        if ! aws s3api head-object --bucket "${S3_BUCKET}" --key "${s3_key}" >/dev/null 2>&1; then
            log "ERROR" "Failed to verify upload: ${basename}"
            return 1
        fi
    done < "${local_path}/upload_manifest.txt"
    
    return 0
}

# Main execution
main() {
    log "INFO" "Starting backup process for environment: ${ENVIRONMENT}"
    
    # Set timeout for entire backup operation
    timeout ${BACKUP_TIMEOUT} bash -c '
        # Check prerequisites
        if ! check_prerequisites; then
            log "ERROR" "Prerequisites check failed"
            exit 1
        fi
        
        # Create backup directory for this run
        backup_dir="${BACKUP_ROOT}/${TIMESTAMP}"
        mkdir -p "${backup_dir}"
        
        # Backup web content
        web_archive=$(backup_web_content "${backup_dir}" true)
        
        # Backup SSL certificates
        ssl_archive=$(backup_certificates "${backup_dir}")
        
        # Upload to S3
        s3_path="${ENVIRONMENT}/$(date +%Y/%m/%d)"
        if ! upload_to_s3 "${backup_dir}" "${s3_path}"; then
            log "ERROR" "Failed to upload backups to S3"
            exit 1
        fi
        
        # Export backup metrics
        aws cloudwatch put-metric-data \
            --namespace "HelloWorldApp" \
            --metric-name "BackupSize" \
            --value "$(du -sb "${backup_dir}" | cut -f1)" \
            --unit Bytes \
            --dimensions Environment="${ENVIRONMENT}" \
            --region "${AWS_REGION}"
        
        log "INFO" "Backup completed successfully"
        exit 0
    '
    
    exit_code=$?
    if [[ ${exit_code} -eq 124 ]]; then
        log "ERROR" "Backup operation timed out after ${BACKUP_TIMEOUT} seconds"
    fi
    
    cleanup_and_exit ${exit_code}
}

# Execute main function
main