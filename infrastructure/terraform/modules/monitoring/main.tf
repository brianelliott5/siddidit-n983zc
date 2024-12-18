# Configure Terraform and required providers
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Local variables for resource naming and tagging
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/web/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["${var.metric_namespace}", "TimeToFirstByte", "Environment", var.environment],
            ["${var.metric_namespace}", "PageLoadTime", "Environment", var.environment]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Response Times"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["${var.metric_namespace}", "CacheHitRatio", "Environment", var.environment],
            ["${var.metric_namespace}", "ErrorRate", "Environment", var.environment]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Performance Metrics"
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "ttfb_alarm" {
  alarm_name          = "${local.name_prefix}-high-ttfb"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "TimeToFirstByte"
  namespace           = var.metric_namespace
  period             = var.alarm_period
  statistic          = "Average"
  threshold          = var.latency_threshold
  alarm_description  = "Time to First Byte exceeds ${var.latency_threshold}ms"
  treat_missing_data = "notBreaching"
  
  dimensions = {
    Environment = var.environment
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "error_rate_alarm" {
  alarm_name          = "${local.name_prefix}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ErrorRate"
  namespace           = var.metric_namespace
  period             = var.alarm_period
  statistic          = "Average"
  threshold          = var.error_rate_threshold
  alarm_description  = "Error rate exceeds ${var.error_rate_threshold}%"
  treat_missing_data = "notBreaching"
  
  dimensions = {
    Environment = var.environment
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "cache_hit_ratio_alarm" {
  alarm_name          = "${local.name_prefix}-low-cache-hits"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CacheHitRatio"
  namespace           = var.metric_namespace
  period             = var.alarm_period
  statistic          = "Average"
  threshold          = 90
  alarm_description  = "Cache hit ratio below 90%"
  treat_missing_data = "notBreaching"
  
  dimensions = {
    Environment = var.environment
  }
  
  tags = local.common_tags
}

# Data source for current AWS region
data "aws_region" "current" {}

# Outputs
output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "metric_namespace" {
  description = "Namespace used for CloudWatch metrics"
  value       = var.metric_namespace
}