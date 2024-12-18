# Root-level outputs for Hello World web application infrastructure
# Terraform version ~> 1.0

# Environment Information
output "environment" {
  description = "Current deployment environment (prod/staging)"
  value       = var.environment
}

# Web Server Instance Details
output "web_instance_details" {
  description = "Comprehensive web server instance information"
  value = {
    instance_id        = module.web.instance_id
    public_ip         = module.web.instance_public_ip
    instance_arn      = module.web.instance_arn
    public_dns        = module.web.instance_public_dns
    log_group_name    = module.web.log_group_name
    log_group_arn     = module.web.log_group_arn
    health_check_id   = module.web.health_check_id
    instance_tags     = module.web.instance_tags
  }
}

# Monitoring and Alerting Configuration
output "monitoring_configuration" {
  description = "CloudWatch monitoring and alerting setup"
  value = {
    cpu_alarm_arn    = module.web.cpu_alarm_arn
    memory_alarm_arn = module.web.memory_alarm_arn
    log_group_name   = module.web.log_group_name
    health_check_id  = module.web.health_check_id
  }
}

# CDN Configuration
output "cdn_configuration" {
  description = "Cloudflare CDN configuration details"
  value = {
    zone_id          = module.cdn.zone_id
    domain_name      = module.cdn.domain_name
    cdn_enabled      = module.cdn.cdn_enabled
    nameservers      = module.cdn.nameservers
    ssl_config       = module.cdn.ssl_config
  }
}

# Cache Settings
output "cache_settings" {
  description = "CDN and server-side caching configuration"
  value = {
    cdn_cache_ttl = module.cdn.cache_ttl
    cdn_enabled   = module.cdn.cdn_enabled
  }
}

# Security Configuration
output "security_configuration" {
  description = "Security settings and compliance status"
  value = {
    security_headers = module.cdn.security_headers
    ssl_config      = module.cdn.ssl_config
  }
  sensitive = true # Marking as sensitive to protect security configurations
}

# DNS Configuration
output "dns_configuration" {
  description = "DNS settings for the web application"
  value = {
    domain_name = module.cdn.domain_name
    nameservers = module.cdn.nameservers
    zone_id     = module.cdn.zone_id
  }
}

# Performance Monitoring Endpoints
output "monitoring_endpoints" {
  description = "Endpoints for monitoring and observability"
  value = {
    web_server = {
      health_check_endpoint = "http://${module.web.instance_public_dns}"
      metrics_endpoint      = "/metrics" # If metrics endpoint is configured
    }
    cloudwatch = {
      log_group_name = module.web.log_group_name
      log_group_arn  = module.web.log_group_arn
    }
  }
}

# Infrastructure Status
output "infrastructure_status" {
  description = "Overall infrastructure deployment status"
  value = {
    web_server_healthy = module.web.health_check_id != ""
    cdn_enabled       = module.cdn.cdn_enabled
    ssl_enabled       = module.cdn.ssl_config.ssl_status == "strict"
    environment       = var.environment
  }
}