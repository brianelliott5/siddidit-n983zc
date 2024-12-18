# AWS and Cloudflare provider requirements
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "hashicorp/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Environment variable - determines deployment environment (prod/staging)
variable "environment" {
  type        = string
  description = "Deployment environment (prod/staging)"
  
  validation {
    condition     = can(regex("^(prod|staging)$", var.environment))
    error_message = "Environment must be either 'prod' or 'staging'"
  }
}

# EC2 instance type variable - defines the server size
variable "instance_type" {
  type        = string
  description = "EC2 instance type for web server"
  default     = "t2.micro"  # 1 vCPU, 1GB RAM as per technical specs
  
  validation {
    condition     = can(regex("^t2\\.(micro|small|medium)$", var.instance_type))
    error_message = "Instance type must be t2.micro, t2.small, or t2.medium"
  }
}

# EBS volume size variable - defines storage capacity
variable "volume_size" {
  type        = number
  description = "Size of the EBS volume in GB"
  default     = 10  # 10GB SSD as per technical specs
  
  validation {
    condition     = var.volume_size >= 8 && var.volume_size <= 16384
    error_message = "Volume size must be between 8 and 16384 GB"
  }
}

# Domain name variable - defines the website's domain
variable "domain_name" {
  type        = string
  description = "Domain name for the website"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain name format"
  }
}

# Cloudflare zone ID variable - for CDN and DNS management
variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID for DNS management"
  sensitive   = true
  
  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.cloudflare_zone_id))
    error_message = "Cloudflare zone ID must be a valid 32-character hexadecimal string"
  }
}

# CloudWatch logs retention period variable
variable "cloudwatch_retention_days" {
  type        = number
  description = "Number of days to retain CloudWatch logs"
  default     = 30
  
  validation {
    condition     = var.cloudwatch_retention_days >= 1 && var.cloudwatch_retention_days <= 365
    error_message = "CloudWatch retention days must be between 1 and 365"
  }
}