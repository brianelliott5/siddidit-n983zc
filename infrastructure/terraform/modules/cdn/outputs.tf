# Zone ID output for DNS record management
output "zone_id" {
  description = "The Cloudflare Zone ID for DNS record management and zone configuration"
  value       = cloudflare_zone.site_zone.id
  sensitive   = false
}

# Domain name output for reference by other modules
output "domain_name" {
  description = "The domain name configured for the CDN and website"
  value       = cloudflare_zone.site_zone.name
  sensitive   = false
}

# CDN enablement status
output "cdn_enabled" {
  description = "Boolean indicating whether CDN functionality is enabled"
  value       = true # Always true as per technical requirements
  sensitive   = false
}

# Cache TTL configuration
output "cache_ttl" {
  description = "The configured cache TTL (Time To Live) in seconds for CDN caching"
  value       = var.cache_ttl
  sensitive   = false
}

# Nameservers for DNS configuration
output "nameservers" {
  description = "List of Cloudflare nameservers assigned to the zone"
  value       = cloudflare_zone.site_zone.name_servers
  sensitive   = false
}

# Security headers configuration
output "security_headers" {
  description = "Map of configured security headers for the CDN"
  value       = var.security_headers
  sensitive   = false
}

# SSL/TLS configuration
output "ssl_config" {
  description = "SSL/TLS configuration details including minimum version"
  value = {
    min_tls_version = var.min_tls_version
    ssl_status      = "strict" # As configured in main.tf
  }
  sensitive = false
}