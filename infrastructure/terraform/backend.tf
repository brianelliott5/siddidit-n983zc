# Backend configuration for Terraform state management
# Implements secure state storage in S3 with DynamoDB locking
# Version: 1.0
# Last Updated: 2024-01-22

terraform {
  backend "s3" {
    # S3 bucket for state storage with environment-based isolation
    bucket = "hello-world-terraform-state"
    key    = "${var.environment}/terraform.tfstate"
    region = "us-east-1"

    # Enable encryption for state files at rest
    encrypt = true

    # DynamoDB table for state locking
    dynamodb_table = "hello-world-terraform-locks"

    # Workspace prefix for environment isolation
    workspace_key_prefix = "hello-world"

    # Additional S3 configuration
    versioning = true
    acl        = "private"

    # Enable server-side encryption
    server_side_encryption_configuration {
      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
      }
    }

    # Enable access logging
    logging {
      target_bucket = "hello-world-terraform-logs"
      target_prefix = "state-access-logs/"
    }
  }
}

# Note: The following resources should be created before using this backend:
# 1. S3 bucket: hello-world-terraform-state
# 2. DynamoDB table: hello-world-terraform-locks (with LockID as primary key)
# 3. S3 bucket: hello-world-terraform-logs (for access logging)
# 4. Appropriate IAM roles and policies for access