# Cloudflare account ID for CDN configuration
variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID for CDN configuration"
  sensitive   = true
}

# Domain name for the Hello World website
variable "domain_name" {
  type        = string
  description = "Domain name for the Hello World website"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain name format."
  }
}

# Environment name for deployment context
variable "environment" {
  type        = string
  description = "Environment name (prod/staging)"

  validation {
    condition     = contains(["prod", "staging"], var.environment)
    error_message = "Environment must be either 'prod' or 'staging'."
  }
}

# CDN cache TTL configuration
variable "cache_ttl" {
  type        = number
  description = "CDN cache TTL in seconds"
  default     = 3600 # 1 hour default as specified in technical requirements

  validation {
    condition     = var.cache_ttl >= 0
    error_message = "Cache TTL must be a non-negative number."
  }
}

# TLS version configuration
variable "min_tls_version" {
  type        = string
  description = "Minimum TLS version for HTTPS"
  default     = "1.2"

  validation {
    condition     = contains(["1.2", "1.3"], var.min_tls_version)
    error_message = "Minimum TLS version must be either '1.2' or '1.3'."
  }
}

# Security headers configuration
variable "security_headers" {
  type        = map(string)
  description = "Security header configurations"
  default = {
    "Content-Security-Policy"   = "default-src 'self'"
    "X-Frame-Options"          = "DENY"
    "X-Content-Type-Options"   = "nosniff"
    "Strict-Transport-Security" = "max-age=31536000"
    "Referrer-Policy"          = "no-referrer"
  }

  validation {
    condition = alltrue([
      for k, v in var.security_headers : contains([
        "Content-Security-Policy",
        "X-Frame-Options",
        "X-Content-Type-Options",
        "Strict-Transport-Security",
        "Referrer-Policy"
      ], k)
    ])
    error_message = "Security headers must only contain allowed header names."
  }
}