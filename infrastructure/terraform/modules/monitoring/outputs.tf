# Terraform configuration block to specify minimum required version
terraform {
  required_version = ">= 1.0"
}

# Dashboard outputs
output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_id" {
  description = "ID of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.id
}

# Log group outputs
output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app_logs.arn
}

# Metric alarm outputs
output "metric_alarms" {
  description = "Map of CloudWatch metric alarm ARNs"
  value = {
    ttfb_alarm         = aws_cloudwatch_metric_alarm.ttfb_alarm.arn
    error_rate_alarm   = aws_cloudwatch_metric_alarm.error_rate_alarm.arn
    cache_hit_alarm    = aws_cloudwatch_metric_alarm.cache_hit_ratio_alarm.arn
  }
}

# Performance metrics configuration output
output "performance_metrics" {
  description = "Map of performance metric configurations"
  value = {
    ttfb = {
      id          = aws_cloudwatch_metric_alarm.ttfb_alarm.id
      threshold   = var.latency_threshold
      period      = var.alarm_period
    }
    error_rate = {
      id          = aws_cloudwatch_metric_alarm.error_rate_alarm.id
      threshold   = var.error_rate_threshold
      period      = var.alarm_period
    }
    cache_hit = {
      id          = aws_cloudwatch_metric_alarm.cache_hit_ratio_alarm.id
      threshold   = 90 # Fixed threshold as per main.tf
      period      = var.alarm_period
    }
  }
}

# Monitoring configuration output
output "monitoring_config" {
  description = "General monitoring configuration values"
  value = {
    metric_namespace        = var.metric_namespace
    evaluation_periods     = var.alarm_evaluation_periods
    log_retention_days    = var.log_retention_days
    environment           = var.environment
  }
}