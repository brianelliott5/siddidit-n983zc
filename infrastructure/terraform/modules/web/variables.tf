# AWS Provider version ~> 5.0 required
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Environment variable to distinguish between prod and staging
variable "environment" {
  type        = string
  description = "Deployment environment (prod/staging)"
  
  validation {
    condition     = contains(["prod", "staging"], var.environment)
    error_message = "Environment must be either 'prod' or 'staging'."
  }
}

# EC2 instance type based on minimum requirements (1 vCPU, 1GB RAM)
variable "instance_type" {
  type        = string
  description = "EC2 instance type for web server (minimum 1 vCPU, 1GB RAM)"
  default     = "t3.micro"
  
  validation {
    condition     = can(regex("^t3\\.(micro|small|medium)|t2\\.(micro|small|medium)$", var.instance_type))
    error_message = "Instance type must be t3.micro or larger to meet minimum requirements."
  }
}

# Root volume size for web server (10GB as specified)
variable "root_volume_size" {
  type        = number
  description = "Size of root EBS volume in GB"
  default     = 10
  
  validation {
    condition     = var.root_volume_size >= 10
    error_message = "Root volume size must be at least 10GB."
  }
}

# Public subnet ID for web server deployment
variable "public_subnet_id" {
  type        = string
  description = "ID of the public subnet where web server will be deployed"
  
  validation {
    condition     = can(regex("^subnet-[a-f0-9]+$", var.public_subnet_id))
    error_message = "Public subnet ID must be a valid AWS subnet ID."
  }
}

# Security group ID for web server
variable "web_security_group_id" {
  type        = string
  description = "ID of the security group for web server"
  
  validation {
    condition     = can(regex("^sg-[a-f0-9]+$", var.web_security_group_id))
    error_message = "Security group ID must be a valid AWS security group ID."
  }
}

# CloudWatch log group name for web server logs
variable "log_group_name" {
  type        = string
  description = "Name of CloudWatch log group for web server logs"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_/]+$", var.log_group_name))
    error_message = "Log group name must contain only alphanumeric characters, hyphens, underscores, and forward slashes."
  }
}

# Rate limiting configuration as per security requirements
variable "rate_limit_requests" {
  type        = number
  description = "Maximum number of requests per minute"
  default     = 100
  
  validation {
    condition     = var.rate_limit_requests > 0 && var.rate_limit_requests <= 1000
    error_message = "Rate limit must be between 1 and 1000 requests per minute."
  }
}

# Security configuration flags for web server
variable "server_security_flags" {
  type        = map(bool)
  description = "Security configuration flags for web server"
  default = {
    disable_directory_listing = true
    disable_server_signature = true
    enable_rate_limiting     = true
    enable_security_headers  = true
  }
  
  validation {
    condition     = length(setsubtract(keys(var.server_security_flags), ["disable_directory_listing", "disable_server_signature", "enable_rate_limiting", "enable_security_headers"])) == 0
    error_message = "Invalid security flag specified. Allowed flags are: disable_directory_listing, disable_server_signature, enable_rate_limiting, enable_security_headers."
  }
}