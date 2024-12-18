# Hello World Infrastructure Documentation

## Overview

This document provides comprehensive documentation for the Hello World web application infrastructure, including setup instructions, deployment procedures, and maintenance guidelines for both production and staging environments.

### Project Structure
```
infrastructure/
├── terraform/           # Infrastructure as Code
│   ├── main.tf         # Main Terraform configuration
│   ├── variables.tf    # Variable definitions
│   ├── providers.tf    # Provider configurations
│   └── modules/        # Terraform modules
├── docker/             # Container configurations
│   └── docker-compose.prod.yml  # Production Docker Compose
└── ansible/            # Configuration management
    └── roles/          # Ansible roles
```

### Technology Stack
- **Infrastructure as Code**: Terraform v1.0+
- **Container Runtime**: Docker with Compose v3.8
- **Web Server**: Nginx v1.24-Alpine
- **CDN/DNS**: Cloudflare
- **Monitoring**: AWS CloudWatch
- **SSL/TLS**: Let's Encrypt

## Prerequisites

### Required Tools
- AWS CLI v2+
- Terraform v1.0+
- Docker v20.10+
- Docker Compose v2.0+
- Ansible v2.9+

### Access Credentials
```bash
# Required AWS Environment Variables
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="us-west-2"

# Required Cloudflare Environment Variables
export CLOUDFLARE_API_TOKEN="your_api_token"
```

## Infrastructure Components

### Networking (VPC, Subnets)
- VPC CIDR: 10.0.0.0/16
- Public Subnets: 10.0.1.0/24, 10.0.2.0/24
- Private Subnets: 10.0.3.0/24, 10.0.4.0/24
- Availability Zones: us-west-2a, us-west-2b

### Web Server (EC2, Nginx)
- Instance Type: t3.micro (1 vCPU, 1GB RAM)
- Storage: 10GB SSD
- OS: Ubuntu 22.04 LTS
- Web Server: Nginx v1.24-Alpine
- Container Runtime: Docker v20.10+

### CDN (Cloudflare)
- SSL Mode: Full (Strict)
- Cache TTL: 3600s (1 hour)
- Security Headers:
  - Content-Security-Policy: default-src 'self'
  - X-Frame-Options: DENY
  - X-Content-Type-Options: nosniff
  - Strict-Transport-Security: max-age=31536000
  - Referrer-Policy: no-referrer

### Monitoring (CloudWatch)
- Metrics Collection: Every 60 seconds
- Log Retention: 30 days
- Alarms:
  - CPU Utilization: >80%
  - Memory Utilization: >80%
  - Disk Usage: >85%

## Deployment

### Production Environment

1. Initialize Terraform:
```bash
cd infrastructure/terraform
terraform init
```

2. Deploy Infrastructure:
```bash
# Set environment to production
export TF_VAR_environment="prod"

# Plan and apply infrastructure changes
terraform plan -out=tfplan
terraform apply tfplan
```

3. Deploy Application:
```bash
cd ../docker
docker-compose -f docker-compose.prod.yml up -d
```

### Staging Environment

1. Initialize Terraform:
```bash
cd infrastructure/terraform
terraform init -backend-config="key=staging/terraform.tfstate"
```

2. Deploy Infrastructure:
```bash
# Set environment to staging
export TF_VAR_environment="staging"

# Plan and apply infrastructure changes
terraform plan -out=tfplan
terraform apply tfplan
```

3. Deploy Application:
```bash
cd ../docker
docker-compose -f docker-compose.prod.yml -f docker-compose.staging.yml up -d
```

## Maintenance

### Backup Procedures
- **EBS Snapshots**: Daily automated backups at 5 AM UTC
- **Retention Period**: 30 days
- **Backup Verification**:
```bash
# List available backups
aws backup list-recovery-points-by-backup-vault \
    --backup-vault-name hello-world-backup-vault
```

### SSL Certificate Rotation
- Automated via Let's Encrypt with Cloudflare DNS validation
- 90-day certificate validity
- Auto-renewal 30 days before expiration

### Log Management
- Location: `/var/log/nginx/`
- Rotation: Daily with 3 rotations
- CloudWatch Log Groups:
  - `/hello-world/nginx/access`
  - `/hello-world/nginx/error`

### Monitoring
- CloudWatch Dashboard: `hello-world-${environment}`
- Metrics Collection: 60-second intervals
- Custom Metrics:
  - Request Rate
  - Error Rate
  - Response Time

## Security

### Network Security
- VPC Security Groups
- Inbound Rules:
  - HTTP (80): Cloudflare IPs only
  - HTTPS (443): Cloudflare IPs only
  - SSH (22): Management IPs only

### Access Control
- IAM Roles and Policies
- Principle of Least Privilege
- MFA Enforcement for AWS Console

### SSL/TLS Configuration
- Protocol: TLSv1.2, TLSv1.3
- Ciphers:
  - ECDHE-ECDSA-AES128-GCM-SHA256
  - ECDHE-RSA-AES128-GCM-SHA256
  - ECDHE-ECDSA-AES256-GCM-SHA384
  - ECDHE-RSA-AES256-GCM-SHA384

### Security Headers
- Implemented via Nginx configuration
- Regular security scanning
- Automated compliance checks

## Troubleshooting

### Deployment Issues
1. Check Terraform state:
```bash
terraform show
```

2. Verify Docker containers:
```bash
docker ps
docker logs hello-world-web-prod
```

### Network Problems
1. Check Security Groups:
```bash
aws ec2 describe-security-groups --group-ids <sg-id>
```

2. Verify Cloudflare Status:
```bash
curl -v -H "CF-Ray: <ray-id>" https://<domain>
```

### Performance Issues
1. Check Resource Usage:
```bash
docker stats hello-world-web-prod
```

2. View CloudWatch Metrics:
```bash
aws cloudwatch get-metric-statistics \
    --namespace HelloWorld \
    --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value=<instance-id> \
    --start-time $(date -u -v-1H +%FT%TZ) \
    --end-time $(date -u +%FT%TZ) \
    --period 300 \
    --statistics Average
```

### Security Alerts
1. Check CloudWatch Logs:
```bash
aws logs tail /hello-world/nginx/error
```

2. Review Access Logs:
```bash
aws logs tail /hello-world/nginx/access
```

For additional support or questions, please contact the infrastructure team.