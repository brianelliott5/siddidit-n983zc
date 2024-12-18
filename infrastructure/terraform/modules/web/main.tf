# Required provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# EC2 Instance for Web Server
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu_2204.id
  instance_type = var.instance_type

  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids     = [var.web_security_group_id]
  iam_instance_profile       = var.instance_profile_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type          = "gp3"
    encrypted            = true
    delete_on_termination = true
    tags = {
      Name = "hello-world-web-root-volume-${var.environment}"
    }
  }

  # Enhanced monitoring for CloudWatch metrics
  monitoring = true

  # Instance Metadata Service v2 (IMDSv2) requirements
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # User data script for Nginx installation and configuration
  user_data = templatefile("${path.module}/scripts/nginx_setup.sh", {
    environment          = var.environment
    log_group_name      = var.log_group_name
    rate_limit_requests = var.rate_limit_requests
    security_flags      = var.server_security_flags
  })
  user_data_replace_on_change = true

  # Enable detailed monitoring
  credit_specification {
    cpu_credits = "standard"
  }

  # EBS optimization for consistent I/O performance
  ebs_optimized = true

  tags = {
    Name         = "hello-world-web-server-${var.environment}"
    Environment  = var.environment
    Purpose      = "Static Hello World Web Application"
    Managed-by   = "Terraform"
    CreatedAt    = timestamp()
    BackupPolicy = "daily"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ami,
      user_data,
      user_data_replace_on_change
    ]
  }
}

# CloudWatch Log Group for Web Server Logs
resource "aws_cloudwatch_log_group" "web_logs" {
  name              = var.log_group_name
  retention_in_days = 30

  # Enable encryption using KMS
  kms_key_id = var.kms_key_arn

  tags = {
    Name        = "hello-world-logs-${var.environment}"
    Environment = var.environment
    Purpose     = "Web Server Logs"
    Managed-by  = "Terraform"
  }
}

# CloudWatch Metric Alarm for High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "hello-world-cpu-utilization-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = "300"
  statistic          = "Average"
  threshold          = "80"
  alarm_description  = "This metric monitors EC2 CPU utilization"
  alarm_actions      = []  # Add SNS topic ARN for notifications if needed

  dimensions = {
    InstanceId = aws_instance.web_server.id
  }

  tags = {
    Environment = var.environment
    Purpose     = "CPU Monitoring"
    Managed-by  = "Terraform"
  }
}

# CloudWatch Metric Alarm for Memory Usage
resource "aws_cloudwatch_metric_alarm" "memory_alarm" {
  alarm_name          = "hello-world-memory-usage-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "mem_used_percent"
  namespace          = "CWAgent"
  period             = "300"
  statistic          = "Average"
  threshold          = "80"
  alarm_description  = "This metric monitors memory usage"
  alarm_actions      = []  # Add SNS topic ARN for notifications if needed

  dimensions = {
    InstanceId = aws_instance.web_server.id
  }

  tags = {
    Environment = var.environment
    Purpose     = "Memory Monitoring"
    Managed-by  = "Terraform"
  }
}

# Route 53 Health Check for Web Server
resource "aws_route53_health_check" "web_health" {
  fqdn              = aws_instance.web_server.public_dns
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name        = "hello-world-health-check-${var.environment}"
    Environment = var.environment
    Purpose     = "Web Server Health Monitoring"
    Managed-by  = "Terraform"
  }
}