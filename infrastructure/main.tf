provider "aws" {
  region = var.region
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ---------------------------------------------
# S3 Bucket for App Assets
# ---------------------------------------------
data "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts-${var.environment}"
}

resource "aws_s3_bucket_cors_configuration" "artifacts" {
  bucket = data.aws_s3_bucket.artifacts.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = concat([var.client_domain], var.allowed_origins)
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

#resource "aws_s3_bucket_policy" "artifacts" {
#  bucket = aws_s3_bucket.artifacts.id
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

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
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
# SSH Key Pair (auto-generated)
# ---------------------------------------------

# Generate private key
resource "tls_private_key" "main" {
  count     = var.auto_generate_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair with generated public key
resource "aws_key_pair" "main" {
  count      = var.auto_generate_ssh_key ? 1 : 0
  key_name   = var.key_pair_name
  public_key = tls_private_key.main[0].public_key_openssh
  
  tags = {
    Name = var.key_pair_name
  }
}

# ---------------------------------------------
# EC2 Instance
# ---------------------------------------------

resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.public.id

  # User data script (optional)
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from ${var.instance_name}</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = var.instance_name
  }
}