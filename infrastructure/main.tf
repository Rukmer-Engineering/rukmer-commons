provider "aws" {
  region = var.region
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
  
  # Reference to the S3 bucket (either created or existing)
  artifacts_bucket_id = var.create_bucket ? aws_s3_bucket.artifacts[0].id : data.aws_s3_bucket.artifacts[0].id
}

# ---------------------------------------------
# S3 Bucket for App Assets
# ---------------------------------------------
resource "aws_s3_bucket" "artifacts" {
  count  = var.create_bucket ? 1 : 0
  bucket = "${var.project_name}-artifacts-${var.environment}"
  tags   = local.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      bucket,
      tags,
    ]
  }
}

data "aws_s3_bucket" "artifacts" {
  count  = var.create_bucket ? 0 : 1
  bucket = "${var.project_name}-artifacts-${var.environment}"
}


resource "aws_s3_bucket_cors_configuration" "artifacts" {
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

  # ---------------------------------------------
  # LEGACY SSH ACCESS (Traditional SSH on port 22)
  # TODO: REMOVE WHEN DEPRECATING BACKWARD COMPATIBILITY
  # ---------------------------------------------
  dynamic "ingress" {
    for_each = var.enable_backward_compatibility ? [1] : []
    content {
      description = "[LEGACY] SSH access for backward compatibility"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]  # ⚠️ Security risk - restrict this in production
    }
  }

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
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
# EC2 Instance - MODERN (Session Manager enabled)
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
              echo "[MODERN] SSH-via-Session-Manager enabled" >> /var/log/setup.log
              ${var.enable_backward_compatibility ? "echo '[LEGACY] Backward compatibility mode enabled' >> /var/log/setup.log" : ""}
              EOF

  tags = {
    Name = var.instance_name
    AccessMethod = var.enable_backward_compatibility ? "[LEGACY+MODERN] SSH + Session Manager" : "[MODERN] Session Manager Only"
  }
}

# ---------------------------------------------
# IAM Roles for EC2 - MODERN (Session Manager)
# REQUIRED: These enable the EC2 instance to communicate with Session Manager
# ---------------------------------------------

# Data source for existing IAM role (if using existing resources)
data "aws_iam_role" "existing_ec2_role" {
  count = var.use_existing_iam_resources ? 1 : 0
  name  = var.existing_ec2_role_name
}

# Create new IAM role (if not using existing resources)
resource "aws_iam_role" "ec2_session_manager_role" {
  count = var.use_existing_iam_resources ? 0 : 1
  name  = "${var.project_name}-ec2-session-manager-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_session_manager_policy" {
  count      = var.use_existing_iam_resources ? 0 : 1
  role       = aws_iam_role.ec2_session_manager_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_session_manager_profile" {
  count = var.use_existing_iam_resources ? 0 : 1
  name  = "${var.project_name}-ec2-session-manager-profile"
  role  = aws_iam_role.ec2_session_manager_role[0].name
}

# Local value to reference the correct role (existing or created)
locals {
  # Only set instance profile if we have IAM resources (either existing or created)
  has_iam_resources = var.use_existing_iam_resources || length(var.iam_ssh_users) > 0
  ec2_role_name = var.use_existing_iam_resources ? data.aws_iam_role.existing_ec2_role[0].name : (length(var.iam_ssh_users) > 0 ? aws_iam_role.ec2_session_manager_role[0].name : null)
  instance_profile_name = var.use_existing_iam_resources ? var.existing_ec2_role_name : (length(var.iam_ssh_users) > 0 ? aws_iam_instance_profile.ec2_session_manager_profile[0].name : null)
}


# ---------------------------------------------
# IAM User Access - MODERN (Session Manager SSH for Users)
# RECOMMENDED: This grants your existing IAM users permission to SSH via Session Manager
# 
# How it works:
# 1. Add your existing IAM usernames to var.iam_ssh_users in terraform.tfvars
# 2. Terraform creates a policy that allows Session Manager access to THIS specific EC2 instance
# 3. Terraform creates a group and adds your users to it
# 4. Your users can now SSH using: aws ssm start-session --target INSTANCE_ID
# ---------------------------------------------

# Create the Session Manager access policy (only if not using existing resources)
resource "aws_iam_policy" "ssh_session_manager_policy" {
  count       = var.use_existing_iam_resources ? 0 : 1
  name        = "${var.project_name}-ssh-session-manager-policy"
  description = "Policy allowing SSH access to ${var.project_name} EC2 instance via Session Manager"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSessionManagerSSH"
        Effect = "Allow"
        Action = "ssm:StartSession"
        Resource = [
          "arn:aws:ec2:${var.region}:*:instance/${aws_instance.main.id}",
          "arn:aws:ssm:*:*:document/AWS-StartSSHSession"
        ]
      },
      {
        Sid      = "AllowSessionManagerMessaging"
        Effect   = "Allow"
        Action   = "ssmmessages:OpenDataChannel"
        Resource = "arn:aws:ssm:*:*:session/$${aws:userid}-*"
      },
      {
        Sid    = "AllowInstanceDiscovery"
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

# Data sources for existing IAM resources (if using existing resources)
data "aws_iam_group" "existing_user_group" {
  count      = var.use_existing_iam_resources && length(var.iam_ssh_users) > 0 ? 1 : 0
  group_name = var.existing_user_group_name
}

# Create IAM group for users who need SSH access (only if not using existing resources)
resource "aws_iam_group" "ssh_session_users" {
  count = var.use_existing_iam_resources ? 0 : (length(var.iam_ssh_users) > 0 ? 1 : 0)
  name  = "${var.project_name}-ssh-session-users"
}

# Attach the policy to the group (only if not using existing resources)
resource "aws_iam_group_policy_attachment" "ssh_session_policy" {
  count      = var.use_existing_iam_resources ? 0 : (length(var.iam_ssh_users) > 0 ? 1 : 0)
  group      = aws_iam_group.ssh_session_users[0].name
  policy_arn = aws_iam_policy.ssh_session_manager_policy[0].arn
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
