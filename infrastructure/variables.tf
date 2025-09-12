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
  description = "Create the S3 bucket"
  type        = bool
  default     = false
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
# SSH Access - LEGACY (Traditional SSH) 
# TODO: DEPRECATE THESE WHEN READY TO REMOVE BACKWARD COMPATIBILITY
# ---------------------------------------------

variable "enable_backward_compatibility" {
  description = "[LEGACY] Enable traditional SSH access on port 22 (backward compatibility)"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidr" {
  description = "[LEGACY] CIDR block allowed for traditional SSH access"
  type        = string
  default     = "0.0.0.0/0"  # Restrict this in production
}

# ---------------------------------------------
# SSH Access - MODERN (AWS Session Manager)
# RECOMMENDED: Use this approach for secure SSH access
# ---------------------------------------------

variable "iam_ssh_users" {
  description = "[MODERN] List of existing IAM usernames for SSH via Session Manager"
  type        = list(string)
  default     = []
  # Example: ["john.doe", "jane.smith"]
}
