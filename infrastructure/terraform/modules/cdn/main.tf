# Configure Cloudflare provider
# Version ~> 4.0
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Create Cloudflare zone for domain
resource "cloudflare_zone" "site_zone" {
  account_id = var.cloudflare_account_id
  zone       = var.domain_name
  plan       = "free" # As specified in technical requirements
  type       = "full"

  lifecycle {
    prevent_destroy = true # Protect against accidental deletion
  }
}

# Configure zone-level settings
resource "cloudflare_zone_settings_override" "site_settings" {
  zone_id = cloudflare_zone.site_zone.id

  settings {
    # SSL/TLS Configuration
    ssl                      = "strict"
    min_tls_version         = var.min_tls_version
    tls_1_3                 = "on"
    automatic_https_rewrites = "on"
    always_use_https        = "on"

    # Security Settings
    security_level        = "medium"
    browser_check        = "on"
    challenge_ttl       = 2700
    privacy_pass        = "on"
    security_header {
      enabled = true
      include_subdomains = true
      max_age = 31536000
      nosniff = true
      preload = true
    }

    # Caching Configuration
    cache_level = "aggressive"
    browser_cache_ttl = var.cache_ttl
    edge_cache_ttl   = var.cache_ttl
    development_mode = var.environment == "staging" ? "on" : "off"

    # Performance Optimizations
    minify {
      css  = "on"
      js   = "on"
      html = "on"
    }
    brotli = "on"
    http3  = "on"
    zero_rtt = "on"
    
    # HTTP/2 and HTTP/3 Support
    http2          = "on"
    http3          = "on"
    websockets     = "off" # Not needed for static content
    opportunistic_encryption = "on"
    
    # Rate Limiting (as per security requirements)
    rate_limiting {
      enabled = true
      threshold = 100
      period   = 60
    }
  }
}

# Configure security headers using Page Rules
resource "cloudflare_page_rule" "security_headers" {
  zone_id  = cloudflare_zone.site_zone.id
  target   = "*${var.domain_name}/*"
  priority = 1

  actions {
    cache_level = "cache_everything"
    edge_cache_ttl = var.cache_ttl
    
    # Security Headers
    security_headers {
      content_security_policy = var.security_headers["Content-Security-Policy"]
      x_frame_options        = var.security_headers["X-Frame-Options"]
      x_content_type_options = var.security_headers["X-Content-Type-Options"]
      strict_transport_security = var.security_headers["Strict-Transport-Security"]
      referrer_policy        = var.security_headers["Referrer-Policy"]
    }
  }
}

# Configure caching behavior for static content
resource "cloudflare_page_rule" "cache_static" {
  zone_id  = cloudflare_zone.site_zone.id
  target   = "*.${var.domain_name}/*"
  priority = 2

  actions {
    cache_level = "cache_everything"
    edge_cache_ttl = var.cache_ttl
    browser_cache_ttl = var.cache_ttl
    cache_by_device_type = "on"
    cache_deception_armor = "on"
    respect_strong_etags = "on"
  }
}

# Configure WAF (Web Application Firewall)
resource "cloudflare_waf_package" "site_waf" {
  zone_id = cloudflare_zone.site_zone.id
  
  sensitivity = "high"
  action_mode = "challenge"
}

# Configure DNS for origin server
resource "cloudflare_record" "site_dns" {
  zone_id = cloudflare_zone.site_zone.id
  name    = "@"
  value   = var.domain_name
  type    = "CNAME"
  proxied = true

  ttl     = 1 # Auto TTL when proxied
}

# Output zone details for reference
output "zone_id" {
  description = "The Cloudflare Zone ID"
  value       = cloudflare_zone.site_zone.id
}

output "name_servers" {
  description = "Cloudflare name servers for the zone"
  value       = cloudflare_zone.site_zone.name_servers
}