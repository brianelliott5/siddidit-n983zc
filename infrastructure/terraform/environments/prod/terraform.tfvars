# Production environment identifier
environment = "prod"

# EC2 instance type matching technical specs requirement of 1 vCPU, 1GB RAM
instance_type = "t2.micro"

# EBS volume size matching technical specs requirement of 10GB SSD
volume_size = 10

# CloudWatch logs retention period for production monitoring
cloudwatch_retention_days = 30