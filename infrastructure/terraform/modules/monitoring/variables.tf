# Required Terraform version
terraform {
  required_version = ">= 1.0"
}

# Project name variable for resource naming
variable "project_name" {
  description = "Name of the project used for resource naming"
  type        = string
  default     = "hello-world"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens"
  }
}

# Environment variable for deployment context
variable "environment" {
  description = "Deployment environment (e.g., prod, staging)"
  type        = string

  validation {
    condition     = contains(["prod", "staging"], var.environment)
    error_message = "Environment must be either prod or staging"
  }
}

# Log retention configuration
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period"
  }
}

# CloudWatch metrics namespace
variable "metric_namespace" {
  description = "Namespace for CloudWatch metrics"
  type        = string
  default     = "WebApplication"

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_.-]+$", var.metric_namespace))
    error_message = "Metric namespace must contain only alphanumeric characters, forward slashes, underscores, dots, and hyphens"
  }
}

# Alarm evaluation configuration
variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarm conditions"
  type        = number
  default     = 3

  validation {
    condition     = var.alarm_evaluation_periods >= 1 && var.alarm_evaluation_periods <= 24
    error_message = "Alarm evaluation periods must be between 1 and 24"
  }
}

# Alarm period configuration
variable "alarm_period" {
  description = "Period in seconds over which to evaluate alarms"
  type        = number
  default     = 300

  validation {
    condition     = contains([60, 300, 3600], var.alarm_period)
    error_message = "Alarm period must be 60, 300, or 3600 seconds"
  }
}

# Error rate threshold configuration
variable "error_rate_threshold" {
  description = "Threshold percentage for error rate alarms"
  type        = number
  default     = 0.1

  validation {
    condition     = var.error_rate_threshold >= 0 && var.error_rate_threshold <= 100
    error_message = "Error rate threshold must be between 0 and 100"
  }
}

# Latency threshold configuration
variable "latency_threshold" {
  description = "Threshold in milliseconds for latency alarms"
  type        = number
  default     = 100

  validation {
    condition     = var.latency_threshold >= 0
    error_message = "Latency threshold must be greater than or equal to 0"
  }
}