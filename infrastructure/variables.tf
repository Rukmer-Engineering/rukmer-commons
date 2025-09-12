variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
  default     = "rukmer-commons"
}

variable "environment" {
  description = "Environment (e.g., dev, prod)"
  type        = string
  default     = "prod"
}

variable "client_domain" {
  description = "Allowed client domain for CORS"
  type        = string
}

variable "allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = []
}

variable "create_bucket" {
  description = "Name of the existing S3 bucket to use for artifacts"
  type        = boolean
  default     = false
}

variable "existing_bucket_name" {
  description = "Name of the existing S3 bucket to use for artifacts"
  type        = string
}

# ---------------------------------------------
# EC2 Instance - General Configuration
# ---------------------------------------------

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "my-t2-micro"
}

# ---------------------------------------------
# SSH Access - MODERN (AWS Session Manager)
# RECOMMENDED: Use this approach for secure SSH access
# ---------------------------------------------

variable "iam_ssh_users" {
  description = <<-EOT
    [MODERN] List of existing IAM usernames for SSH via Session Manager.
    
    How to use:
    1. Create IAM users in AWS Console (or use existing ones)
    2. Add their usernames to this list
    3. Terraform will grant them Session Manager SSH access to your EC2 instance
    4. Users can SSH using: aws ssm start-session --target INSTANCE_ID
    
    Example: ["john.doe", "jane.smith", "developer1"]
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------
# Use Existing IAM Resources (if you don't have IAM create permissions)
# ---------------------------------------------

variable "existing_ec2_role_name" {
  description = "Name of existing IAM role for EC2 Session Manager"
  type        = string
  default     = ""
}

variable "existing_user_group_name" {
  description = "Name of existing IAM group for SSH users"
  type        = string
  default     = ""
}
