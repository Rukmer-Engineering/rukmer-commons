provider "aws" {
  region = var.region
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
  

# ---------------------------------------------
# S3 Bucket for App Assets
# ---------------------------------------------
# Reference to the S3 bucket (conditional)
  artifacts_bucket_id = var.create_bucket ? aws_s3_bucket.artifacts[0].id : var.existing_bucket_name
}

# Create bucket - Terraform will manage it going forward
resource "aws_s3_bucket" "artifacts" {
  count  = var.create_bucket ? 1 : 0
  bucket = var.existing_bucket_name
  tags   = local.tags

  lifecycle {
    prevent_destroy = true  
    ignore_changes = [
      bucket,
      tags,
    ]
  }
}

resource "aws_s3_bucket_cors_configuration" "artifacts" {
  count  = var.create_bucket ? 1 : 0
  bucket = local.artifacts_bucket_id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = concat([var.client_domain], var.allowed_origins)
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

#resource "aws_s3_bucket_policy" "artifacts" {
#  bucket = local.artifacts_bucket_id
#  policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = []
#  })
#}

# ---------------------------------------------
# EC2 Instance Resources
# ---------------------------------------------

# Data sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.instance_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.instance_name}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.instance_name}-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.instance_name}-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "${var.instance_name}-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  # Ingress rules
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Egress rules - REQUIRED for SSM to work
  egress {
    description = "All outbound traffic for SSM and updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# ---------------------------------------------
# EC2 Instance - MODERN Session Manager enabled
# ---------------------------------------------
resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.public.id
  iam_instance_profile   = local.instance_profile_name # [MODERN] Session Manager access (optional)
  
  # Enhanced user data for both access methods
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd amazon-ssm-agent
              systemctl start httpd amazon-ssm-agent
              systemctl enable httpd amazon-ssm-agent
              echo "<h1>Hello from ${var.instance_name}</h1>" > /var/www/html/index.html
              
              # Log setup completion
              echo "Instance setup completed at $(date)" >> /var/log/setup.log
              echo "SSH-via-Session-Manager enabled" >> /var/log/setup.log
              EOF

  tags = {
    Name = var.instance_name
    AccessMethod = "Session Manager Only"
  }
}

# ---------------------------------------------
# IAM Roles for EC2 - Session Manager
# REQUIRED: These enable the EC2 instance to communicate with Session Manager
# ---------------------------------------------

# Data source for existing IAM role
data "aws_iam_role" "existing_ec2_role" {
  name = var.existing_ec2_role_name
}

# Local value to reference existing IAM resources
locals {
  # Always use existing IAM resources
  has_iam_resources = length(var.iam_ssh_users) > 0
  ec2_role_name = data.aws_iam_role.existing_ec2_role.name 
  instance_profile_name = var.existing_ec2_role_name
}

# Data source for existing IAM group
data "aws_iam_group" "existing_user_group" {
  count      = length(var.iam_ssh_users) > 0 ? 1 : 0
  group_name = var.existing_user_group_name
}

# ---------------------------------------------
# ECR Repository for Elixir Application
# ---------------------------------------------
resource "aws_ecr_repository" "rukmer_app" {
  name                 = "${var.project_name}-elixir-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "rukmer_app_policy" {
  repository = aws_ecr_repository.rukmer_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ---------------------------------------------
# Cognito User Pool for Marketplace API Authentication
# ---------------------------------------------
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-user-pool-${var.environment}"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  schema {
    attribute_data_type = "String"
    name               = "email"
    required           = true
    mutable           = true

    string_attribute_constraints {
      min_length = 7
      max_length = 256
    }
  }

   schema {
    attribute_data_type = "String"
    name               = "preferred_roles"
    required           = false
    mutable           = true
    
    string_attribute_constraints {
      min_length = 1
      max_length = 100
    }
  }

  #lambda_config {
  #  post_confirmation = aws_lambda_function.user.arn
  #}

  tags = local.tags
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "${var.project_name}-app-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

#resource "aws_cognito_user_group" "subscriber" {
#  name         = "Subscriber"
#  description  = "Subscriber group with access to app marketplace"
#  user_pool_id = aws_cognito_user_pool.main.id
#  precedence   = 1
#}

resource "aws_cognito_user_group" "publisher" {
  name         = "Publisher"
  description  = "Publisher group with access to publishing features"
  user_pool_id = aws_cognito_user_pool.main.id
  precedence   = 2
}
