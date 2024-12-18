# Environment identifier
# As per Technical Specifications/8.1 Deployment Environment
environment = "staging"

# EC2 instance specifications
# As per Technical Specifications/8.1 Deployment Environment/Server Requirements
instance_type = "t2.micro"  # 1 vCPU, 1GB RAM
volume_size   = 10          # 10GB SSD storage

# Domain configuration
# Staging subdomain for testing environment
domain_name = "staging.helloworld.example.com"

# Cloudflare configuration
# Using variable reference for sensitive zone ID
# As per Technical Specifications/8.2 Cloud Services/Service Selection Matrix
cloudflare_zone_id = var.cloudflare_zone_id

# Monitoring configuration
# As per Technical Specifications/8.2 Cloud Services/Service Selection Matrix
cloudwatch_retention_days = 30
enable_monitoring        = true

# Resource tagging
# For resource organization and management
instance_tags = {
  Environment = "staging"
  Project     = "hello-world"
  ManagedBy   = "terraform"
  Purpose     = "Static website hosting"
  Component   = "Web server"
}