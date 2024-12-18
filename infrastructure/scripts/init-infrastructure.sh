#!/usr/bin/env bash

# Infrastructure Initialization Script for Hello World Web Application
# Version: 1.0.0
# Last Updated: 2024-01-22
# Required: AWS CLI v2.0+, Terraform v1.0+, Ansible v2.9+

set -euo pipefail
IFS=$'\n\t'

# Global Variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
readonly ANSIBLE_DIR="${SCRIPT_DIR}/../ansible"
readonly MONITORING_DIR="${SCRIPT_DIR}/../monitoring"
readonly LOG_FILE="/var/log/infrastructure-init.log"
readonly BACKUP_DIR="/var/backup/infrastructure"

# Environment Variables with defaults
ENVIRONMENT=${ENVIRONMENT:-"staging"}
AWS_REGION=${AWS_REGION:-"us-east-1"}
TERRAFORM_WORKSPACE=${TERRAFORM_WORKSPACE:-"${ENVIRONMENT}"}
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}
HEALTH_CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-60}
METRIC_COLLECTION_INTERVAL=${METRIC_COLLECTION_INTERVAL:-300}

# Logging function with timestamp
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

# Error handling function
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
    
    # Backup terraform state if exists
    if [[ -f "${TERRAFORM_DIR}/terraform.tfstate" ]]; then
        mkdir -p "${BACKUP_DIR}/terraform"
        cp "${TERRAFORM_DIR}/terraform.tfstate" "${BACKUP_DIR}/terraform/terraform.tfstate.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Remove temporary files
    rm -f /tmp/cloudwatch-agent.rpm
    
    exit "${exit_code}"
}

# Function to check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("aws" "terraform" "ansible")
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            log "ERROR" "${tool} is required but not installed"
            return 1
        fi
    done
    
    # Verify AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log "ERROR" "Invalid AWS credentials"
        return 1
    fi
    
    # Check Terraform version
    if ! terraform version | grep -q "v1.0"; then
        log "ERROR" "Terraform v1.0+ is required"
        return 1
    }
    
    # Check Ansible version
    if ! ansible --version | grep -q "2.9"; then
        log "ERROR" "Ansible v2.9+ is required"
        return 1
    }
    
    return 0
}

# Function to initialize Terraform
init_terraform() {
    log "INFO" "Initializing Terraform..."
    
    cd "${TERRAFORM_DIR}"
    
    # Initialize Terraform
    terraform init -input=false
    
    # Select workspace
    terraform workspace select "${TERRAFORM_WORKSPACE}" || terraform workspace new "${TERRAFORM_WORKSPACE}"
    
    # Validate Terraform configuration
    terraform validate
    
    # Plan Terraform changes
    terraform plan \
        -var="environment=${ENVIRONMENT}" \
        -var="aws_region=${AWS_REGION}" \
        -out=tfplan
    
    # Apply Terraform changes
    terraform apply -auto-approve tfplan
    
    cd - > /dev/null
}

# Function to configure Ansible
configure_ansible() {
    log "INFO" "Configuring Ansible..."
    
    cd "${ANSIBLE_DIR}"
    
    # Validate Ansible playbook
    ansible-playbook playbooks/web-server.yml --syntax-check
    
    # Run Ansible playbook
    ansible-playbook playbooks/web-server.yml \
        -e "environment=${ENVIRONMENT}" \
        -e "aws_region=${AWS_REGION}" \
        -e "metric_collection_interval=${METRIC_COLLECTION_INTERVAL}"
    
    cd - > /dev/null
}

# Function to setup monitoring
setup_monitoring() {
    log "INFO" "Setting up monitoring..."
    
    # Deploy CloudWatch dashboard
    aws cloudwatch put-dashboard \
        --dashboard-name "HelloWorld-${ENVIRONMENT}" \
        --dashboard-body "$(cat ${MONITORING_DIR}/cloudwatch-dashboard.json)"
    
    # Configure CloudWatch alarms
    aws cloudwatch put-metric-alarm \
        --alarm-name "HelloWorld-HighErrorRate-${ENVIRONMENT}" \
        --metric-name "ErrorRate" \
        --namespace "HelloWorldApp" \
        --statistic "Average" \
        --period 300 \
        --threshold 0.1 \
        --comparison-operator "GreaterThanThreshold" \
        --evaluation-periods 2 \
        --alarm-actions "${SNS_TOPIC_ARN}"
}

# Function to verify deployment
verify_deployment() {
    log "INFO" "Verifying deployment..."
    
    # Check web server health
    if ! curl -sf -o /dev/null "http://localhost"; then
        log "ERROR" "Web server health check failed"
        return 1
    fi
    
    # Verify SSL certificate
    if ! openssl s_client -connect localhost:443 -servername localhost </dev/null 2>/dev/null | openssl x509 -noout -dates; then
        log "ERROR" "SSL certificate verification failed"
        return 1
    fi
    
    # Check CloudWatch agent
    if ! aws cloudwatch list-metrics --namespace "HelloWorldApp" --region "${AWS_REGION}" &> /dev/null; then
        log "ERROR" "CloudWatch metrics not available"
        return 1
    }
    
    return 0
}

# Main execution
main() {
    log "INFO" "Starting infrastructure initialization for environment: ${ENVIRONMENT}"
    
    # Create necessary directories
    mkdir -p "${BACKUP_DIR}" "$(dirname "${LOG_FILE}")"
    
    # Check prerequisites
    if ! check_prerequisites; then
        log "ERROR" "Prerequisites check failed"
        cleanup_and_exit 1
    fi
    
    # Initialize infrastructure
    init_terraform
    
    # Configure web server
    configure_ansible
    
    # Setup monitoring
    setup_monitoring
    
    # Verify deployment
    if ! verify_deployment; then
        log "ERROR" "Deployment verification failed"
        cleanup_and_exit 1
    fi
    
    log "INFO" "Infrastructure initialization completed successfully"
    cleanup_and_exit 0
}

# Execute main function
main