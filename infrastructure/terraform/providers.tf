# Configure Terraform version and required providers
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"  # AWS provider v5.0
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"  # Cloudflare provider v4.0
      version = "~> 4.0"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  # Use us-east-1 as default region for global services
  region = "us-east-1"
  
  # Default tags applied to all AWS resources
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "hello-world"
      ManagedBy   = "terraform"
      Service     = "static-website"
      CreatedAt   = timestamp()
    }
  }
  
  # Best practice: Use environment variables for authentication
  # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY should be set in the environment
  # AWS_SESSION_TOKEN if using temporary credentials
}

# Cloudflare Provider Configuration
provider "cloudflare" {
  # Best practice: Use environment variable CLOUDFLARE_API_TOKEN for authentication
  # This provides better security than hardcoding the token
  
  # Optional: Configure retry logic for API rate limiting
  retries = 3
  
  # Optional: Configure minimum TLS version for API calls
  min_backoff = 5
}

# Provider Feature Flags and Configurations
provider "aws" {
  alias = "monitoring"
  region = "us-east-1"
  
  # Specific configuration for CloudWatch monitoring
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "hello-world"
      Component   = "monitoring"
      ManagedBy   = "terraform"
    }
  }
  
  # Enable AWS service features
  skip_credentials_validation = false
  skip_metadata_api_check    = false
  skip_requesting_account_id = false
}