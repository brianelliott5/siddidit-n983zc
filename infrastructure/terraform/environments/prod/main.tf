# Configure Terraform settings and required providers
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"  # v5.0
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"  # v4.0
      version = "~> 4.0"
    }
  }

  # Production environment state management in S3 with DynamoDB locking
  backend "s3" {
    bucket         = "hello-world-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "hello-world-terraform-locks-prod"
  }
}

# AWS Provider configuration for production environment
provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      Environment = "prod"
      Project     = "hello-world"
      ManagedBy   = "terraform"
    }
  }
}

# Cloudflare provider configuration
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Root module instantiation with production-specific configurations
module "root" {
  source = "../../"

  # Environment configuration
  environment = "prod"
  
  # Compute resources as per technical specifications
  instance_type = "t3.micro"  # 1 vCPU, 1GB RAM
  volume_size   = 10          # 10GB SSD
  
  # Domain and CDN configuration
  domain_name        = var.domain_name
  cloudflare_zone_id = var.cloudflare_zone_id
  
  # Enhanced monitoring configuration for production
  cloudwatch_retention_days    = 30
  enable_detailed_monitoring   = true
  backup_retention_days       = 7
  
  # Security configuration
  ssl_certificate_arn = var.ssl_certificate_arn
  vpc_cidr           = "10.0.0.0/16"
  enable_waf         = true
  enable_cloudtrail  = true

  # Production environment tags
  tags = {
    Environment = "prod"
    Project     = "hello-world"
    ManagedBy   = "terraform"
  }
}

# Output the production website URL
output "web_url" {
  description = "Production website URL with CDN endpoint"
  value       = module.root.web_url
}

# Output the CDN distribution ID for cache management
output "cloudfront_distribution_id" {
  description = "Production CDN distribution ID"
  value       = module.root.cloudfront_distribution_id
  sensitive   = true
}

# Output the EC2 instance ID for monitoring
output "instance_id" {
  description = "Production EC2 instance ID"
  value       = module.root.instance_id
}

# Output the CloudWatch log group name
output "cloudwatch_log_group_name" {
  description = "Production CloudWatch log group name"
  value       = module.root.cloudwatch_log_group_name
}