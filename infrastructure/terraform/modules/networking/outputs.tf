# Output definitions for the networking module
# These outputs expose essential networking resource identifiers and configurations
# required by other modules for web server deployment and security configuration

# VPC ID output
output "vpc_id" {
  description = "The ID of the VPC where the Hello World infrastructure is deployed"
  value       = aws_vpc.main.id

  # Ensure the VPC ID is never empty
  precondition {
    condition     = aws_vpc.main.id != ""
    error_message = "VPC ID cannot be empty"
  }
}

# Public subnet ID output
output "public_subnet_id" {
  description = "The ID of the public subnet where web servers will be deployed with 100 Mbps network capability"
  value       = aws_subnet.public.id

  # Ensure the subnet ID is never empty
  precondition {
    condition     = aws_subnet.public.id != ""
    error_message = "Public subnet ID cannot be empty"
  }
}

# Web security group ID output
output "web_security_group_id" {
  description = "The ID of the security group controlling web server access (HTTP/HTTPS/SSH)"
  value       = aws_security_group.web.id

  # Ensure the security group ID is never empty
  precondition {
    condition     = aws_security_group.web.id != ""
    error_message = "Web security group ID cannot be empty"
  }
}