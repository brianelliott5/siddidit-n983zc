# Terraform version constraint
terraform {
  required_version = ">=1.0"
}

# VPC CIDR block variable
variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC network"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block (e.g., 10.0.0.0/16)"
  }

  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) <= 24
    error_message = "VPC CIDR block must have a prefix length less than or equal to /24 to accommodate required subnets"
  }
}

# Public subnet CIDR block variable
variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR block for the public subnet where web servers will be deployed"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.public_subnet_cidr))
    error_message = "Public subnet CIDR must be a valid IPv4 CIDR block (e.g., 10.0.1.0/24)"
  }

  validation {
    condition     = tonumber(split("/", var.public_subnet_cidr)[1]) >= 24
    error_message = "Public subnet CIDR block must have a prefix length greater than or equal to /24 for proper sizing"
  }
}

# Environment variable for resource tagging
variable "environment" {
  type        = string
  description = "Environment name for resource tagging (prod/staging)"

  validation {
    condition     = contains(["prod", "staging"], var.environment)
    error_message = "Environment must be either 'prod' or 'staging'"
  }
}

# Allowed HTTP/HTTPS access IPs
variable "allowed_http_ips" {
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Default allows all IPs - should be restricted in production
  description = "List of IP CIDR blocks allowed for HTTP/HTTPS access to web servers"

  validation {
    condition = alltrue([
      for cidr in var.allowed_http_ips :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
    ])
    error_message = "All HTTP allowed IPs must be valid CIDR blocks"
  }
}

# Allowed SSH access IPs
variable "allowed_ssh_ips" {
  type        = list(string)
  default     = []  # Empty by default for security - must be explicitly specified
  description = "List of IP CIDR blocks allowed for SSH maintenance access to web servers"

  validation {
    condition = alltrue([
      for cidr in var.allowed_ssh_ips :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
    ])
    error_message = "All SSH allowed IPs must be valid CIDR blocks"
  }

  validation {
    condition     = length(var.allowed_ssh_ips) > 0
    error_message = "At least one SSH CIDR block must be specified for maintenance access"
  }
}