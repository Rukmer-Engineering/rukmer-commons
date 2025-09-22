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

variable "create_new_storage" {
  description = "Whether to create new S3 bucket and ECR repository (false = use existing)"
  type        = bool
  default     = false
}

variable "existing_bucket_name" {
  description = "Name of existing S3 bucket to use for artifacts"
  type        = string
}

variable "existing_ecr_repository_name" {
  description = "Name of existing ECR repository to use"
  type        = string
  default     = ""
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

variable "ec2_session_manager_role" {
  description = "Name of existing IAM role for EC2 Session Manager"
  type        = string
  default     = ""
}

variable "existing_user_group_name" {
  description = "Name of existing IAM group for SSH users"
  type        = string
  default     = ""
}

# ---------------------------------------------
# RDS Database Configuration
# ---------------------------------------------

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"  # Free tier eligible
}

variable "db_allocated_storage" {
  description = "Initial allocated storage for RDS (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for RDS auto-scaling (GB)"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "rukmer_marketplace"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "rukmer_admin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_backup_retention_days" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 7
}

variable "db_pool_size" {
  description = "Database connection pool size for Elixir app"
  type        = number
  default     = 10
}

# ---------------------------------------------
# Database Public Access Configuration
# ---------------------------------------------

variable "db_publicly_accessible" {
  description = "Whether the RDS instance should be publicly accessible"
  type        = bool
  default     = false
}

variable "allowed_db_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the database"
  type        = list(string)
  default     = []
}

variable "existing_rds_monitoring_role_name" {
  description = "Name of existing IAM role for RDS Enhanced Monitoring (managed outside Terraform)"
  type        = string
  default     = ""
}
