# Output definitions for web server infrastructure module

# EC2 Instance Outputs
output "instance_id" {
  description = "ID of the EC2 instance running the web server for infrastructure management"
  value       = aws_instance.web_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance for DNS and access configuration"
  value       = aws_instance.web_server.public_ip
}

output "instance_arn" {
  description = "ARN of the EC2 instance for IAM and CloudWatch integration"
  value       = aws_instance.web_server.arn
}

# CloudWatch Monitoring Outputs
output "log_group_name" {
  description = "Name of the CloudWatch log group for web server logs aggregation"
  value       = aws_cloudwatch_log_group.web_logs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for IAM and monitoring configuration"
  value       = aws_cloudwatch_log_group.web_logs.arn
}

# CloudWatch Alarms Outputs
output "cpu_alarm_arn" {
  description = "ARN of the CloudWatch CPU utilization alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_alarm.arn
}

output "memory_alarm_arn" {
  description = "ARN of the CloudWatch memory usage alarm"
  value       = aws_cloudwatch_metric_alarm.memory_alarm.arn
}

# Health Check Output
output "health_check_id" {
  description = "ID of the Route53 health check for web server monitoring"
  value       = aws_route53_health_check.web_health.id
}

# DNS Output
output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance for FQDN configuration"
  value       = aws_instance.web_server.public_dns
}

# Tags Output
output "instance_tags" {
  description = "Tags applied to the EC2 instance for resource management"
  value       = aws_instance.web_server.tags
}