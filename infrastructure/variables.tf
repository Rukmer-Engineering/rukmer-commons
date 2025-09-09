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



# ---------------------------------------------
# EC2 Instance
# ---------------------------------------------

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"  # Restrict this in production
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "my-t2-micro"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
  default     = ""
}

variable "auto_generate_ssh_key" {
  description = "Whether to auto-generate SSH key pair with Terraform"
  type        = bool
  default     = true
}
