# Configure Terraform settings and backend
terraform {
  required_version = ">= 1.0"
  
  # S3 backend for state management with DynamoDB locking
  backend "s3" {
    bucket         = "hello-world-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Local variables for resource naming and tagging
locals {
  project_name = "hello-world"
  common_tags = {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "static-website"
  }
}

# Networking module - Creates VPC and related networking components
module "networking" {
  source = "./modules/networking"

  environment          = var.environment
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones   = ["us-west-2a", "us-west-2b"]

  tags = local.common_tags
}

# Web server module - Provisions EC2 instance with web server
module "web" {
  source = "./modules/web"

  environment        = var.environment
  instance_type     = "t3.micro"  # As per specs: 1 vCPU, 1GB RAM
  volume_size       = 10          # As per specs: 10GB SSD
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  security_group_ids = [module.networking.web_security_group_id]
  key_name         = var.ssh_key_name

  user_data = templatefile("${path.module}/templates/user_data.tpl", {
    environment = var.environment
  })

  tags = local.common_tags
}

# CDN module - Configures Cloudflare CDN and DNS
module "cdn" {
  source = "./modules/cdn"

  environment  = var.environment
  domain_name  = var.domain_name
  zone_id      = var.cloudflare_zone_id
  origin_ip    = module.web.public_ip

  # CDN configuration as per technical specs
  ssl_mode     = "full_strict"
  cache_ttl    = 3600  # 1 hour cache as specified
  
  security_headers = {
    "Content-Security-Policy"   = "default-src 'self'"
    "X-Frame-Options"          = "DENY"
    "X-Content-Type-Options"   = "nosniff"
    "Strict-Transport-Security" = "max-age=31536000"
    "Referrer-Policy"          = "no-referrer"
  }

  tags = local.common_tags
}

# Monitoring module - Sets up CloudWatch monitoring
module "monitoring" {
  source = "./modules/monitoring"

  environment    = var.environment
  retention_days = 30
  instance_id    = module.web.instance_id

  # Alarm thresholds as per technical specs
  alarm_thresholds = {
    cpu_utilization    = 80
    memory_utilization = 80
    disk_usage        = 85
  }

  # Monitoring metrics configuration
  metrics_config = {
    namespace = "HelloWorld"
    dimensions = {
      Environment = var.environment
      Service     = "static-website"
    }
  }

  tags = local.common_tags
}

# Output the website URL and CDN distribution ID
output "web_url" {
  description = "Public URL of the web application with CDN endpoint"
  value       = "https://${var.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "Cloudflare distribution ID for CDN management and cache invalidation"
  value       = module.cdn.distribution_id
  sensitive   = true
}

# Health check configuration
resource "aws_route53_health_check" "web" {
  fqdn              = var.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-health-check"
  })
}

# Backup configuration for web server
resource "aws_backup_plan" "web" {
  name = "${local.project_name}-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.web.name
    schedule          = "cron(0 5 ? * * *)"  # Daily backup at 5 AM UTC

    lifecycle {
      delete_after = 30  # Keep backups for 30 days
    }
  }

  tags = local.common_tags
}

resource "aws_backup_vault" "web" {
  name = "${local.project_name}-backup-vault"
  tags = local.common_tags
}