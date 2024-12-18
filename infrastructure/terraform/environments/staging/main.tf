# Configure Terraform settings and required providers
terraform {
  required_version = ">= 1.0"
  
  # S3 backend configuration for staging environment
  backend "s3" {
    bucket         = "terraform-state-staging"
    key            = "staging/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks-staging"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"      # AWS provider v5.0
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"  # Cloudflare provider v4.0
      version = "~> 4.0"
    }
  }
}

# Local variables for staging environment
locals {
  environment = "staging"
  project_name = "hello-world"
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    Service     = "static-website"
  }
}

# Configure AWS provider for staging
provider "aws" {
  region = "us-west-2"
  
  default_tags {
    tags = local.common_tags
  }
}

# Configure Cloudflare provider
provider "cloudflare" {}

# Root module configuration for staging environment
module "root" {
  source = "../../"

  # Environment configuration
  environment = local.environment
  
  # Instance configuration as per technical specs
  instance_type = "t2.micro"  # 1 vCPU, 1GB RAM
  volume_size   = 10          # 10GB SSD
  
  # Domain configuration
  domain_name = "staging.example.com"
  cloudflare_zone_id = var.cloudflare_zone_id
  
  # Monitoring configuration
  cloudwatch_retention_days = 30
  
  # Staging-specific features
  enable_auto_shutdown     = true
  auto_shutdown_schedule   = "cron(0 20 ? * MON-FRI *)"  # Shutdown at 8 PM
  auto_startup_schedule    = "cron(0 6 ? * MON-FRI *)"   # Startup at 6 AM
  detailed_monitoring_enabled = true
  
  # Alarm configuration
  alarm_evaluation_periods = 2
  alarm_period            = 60
  
  # Network configuration
  vpc_cidr     = "10.1.0.0/16"  # Staging VPC CIDR
  allowed_ips  = [var.office_ip, var.vpn_ip]
}

# Outputs for staging environment
output "web_url" {
  description = "Staging environment website URL"
  value       = "https://${module.root.web_url}"
}

output "cloudfront_distribution_id" {
  description = "Staging CDN distribution ID"
  value       = module.root.cloudfront_distribution_id
  sensitive   = true
}

output "instance_id" {
  description = "Staging EC2 instance ID"
  value       = module.root.instance_id
}

# Staging-specific auto-shutdown Lambda function
resource "aws_lambda_function" "auto_shutdown" {
  count         = var.enable_auto_shutdown ? 1 : 0
  filename      = "${path.module}/functions/auto_shutdown.zip"
  function_name = "${local.project_name}-${local.environment}-auto-shutdown"
  role         = aws_iam_role.lambda_role[0].arn
  handler      = "index.handler"
  runtime      = "nodejs18.x"

  environment {
    variables = {
      INSTANCE_ID = module.root.instance_id
      ENVIRONMENT = local.environment
    }
  }

  tags = local.common_tags
}

# Staging-specific CloudWatch alarms with lower thresholds
resource "aws_cloudwatch_metric_alarm" "staging_health" {
  alarm_name          = "${local.project_name}-${local.environment}-health"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name        = "HealthyHostCount"
  namespace          = "AWS/EC2"
  period             = 60
  statistic          = "Average"
  threshold          = 1
  alarm_description  = "Monitor staging environment health"
  alarm_actions      = [var.sns_topic_arn]

  dimensions = {
    InstanceId = module.root.instance_id
  }

  tags = local.common_tags
}

# Staging-specific security group rules
resource "aws_security_group_rule" "staging_access" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ips
  security_group_id = module.root.security_group_id
  description       = "Allow HTTPS access from specified IPs in staging"
}