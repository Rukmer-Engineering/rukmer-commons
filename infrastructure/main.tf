provider "aws" {
  region = var.region
}

terraform { 
  cloud { 
    organization = "rukmer-inc" 

    workspaces { 
      name = "terraform-rukmer" 
    } 
  } 
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket" "artifacts" {
  count  = var.create_new_storage ? 1 : 0
  bucket = var.existing_bucket_name
  tags   = local.tags

  lifecycle {
    prevent_destroy = true  
    ignore_changes = [
      tags,
    ]
  }
}

resource "aws_s3_bucket_cors_configuration" "artifacts" {
  count  = var.create_new_storage ? 1 : 0
  bucket = var.create_new_storage ? aws_s3_bucket.artifacts[0].id : var.existing_bucket_name

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

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]  # ARM64 AMI
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.instance_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.instance_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.instance_name}-public-subnet"
  }
}

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

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.instance_name}-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "All outbound traffic"
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
# EC2 Instance - Session Manager enabled
# ---------------------------------------------
resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t4g.medium"  # ARM-based Graviton processor
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.public.id
  iam_instance_profile   = var.ec2_session_manager_role != "" ? local.instance_profile_name : null
  
  # EC2 initialization script
  user_data_base64 = base64encode(templatefile("${path.module}/ec2-init.sh", {
    instance_name = var.instance_name
    ecr_repo_url  = local.ecr_repository_url
    region        = var.region
    db_host       = aws_db_instance.main.address
    db_port       = aws_db_instance.main.port
    db_name       = aws_db_instance.main.db_name
    db_user       = aws_db_instance.main.username
    db_password   = aws_db_instance.main.password
  }))

  lifecycle {
    ignore_changes = [user_data_base64, ami]
  }

   metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = var.instance_name
    AccessMethod = "Session Manager Only"
  }
}

# ---------------------------------------------
# IAM Roles for EC2 - Session Manager
# REQUIRED: These enable the EC2 instance to communicate with Session Manager
# ---------------------------------------------

data "aws_iam_role" "existing_ec2_role" {
  count = var.ec2_session_manager_role != "" ? 1 : 0
  name = var.ec2_session_manager_role
}

locals {
  # Always use existing IAM resources
  has_iam_resources = length(var.iam_ssh_users) > 0
  ec2_role_name = var.ec2_session_manager_role != "" ? data.aws_iam_role.existing_ec2_role[0].name : null
  instance_profile_name = var.ec2_session_manager_role
  
  # ECR repository URL - use existing or newly created
  ecr_repository_url = var.create_new_storage ? aws_ecr_repository.rukmer_app[0].repository_url : data.aws_ecr_repository.existing_rukmer_app[0].repository_url
}

data "aws_iam_group" "existing_user_group" {
  count      = length(var.iam_ssh_users) > 0 && var.existing_user_group_name != "" ? 1 : 0
  group_name = var.existing_user_group_name
}

# ---------------------------------------------
# ECR Repository for Elixir Application
# ---------------------------------------------
resource "aws_ecr_repository" "rukmer_app" {
  count                = var.create_new_storage ? 1 : 0
  name                 = "${var.project_name}-rukmer-app-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = local.tags
}

# Data source for existing ECR repository
data "aws_ecr_repository" "existing_rukmer_app" {
  count = var.create_new_storage ? 0 : 1
  name  = var.existing_ecr_repository_name
}

resource "aws_ecr_lifecycle_policy" "rukmer_app_policy" {
  count      = var.create_new_storage ? 1 : 0
  repository = aws_ecr_repository.rukmer_app[0].name

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

# =============================================================================
# ALB WITH HTTP (HTTPS READY)
# =============================================================================
# Current: HTTP-only ALB that forwards traffic to EC2
# Future: Add domain to terraform.tfvars to automatically enable HTTPS
# See: README-HTTPS-UPGRADE.md for upgrade instructions
# =============================================================================

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "${var.instance_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-alb-sg"
  }
}

resource "aws_lb" "main" {
  name               = "${var.instance_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.rukmer_marketplace_db_1.id]

  tags = local.tags
}

resource "aws_lb_target_group" "main" {
  name     = "${var.instance_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/health"
  }

  tags = local.tags
}

resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.main.id
  port             = 8080
}

# HTTPS listener (only created if domain is provided)
resource "aws_lb_listener" "https" {
  count             = var.domain_name != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.main[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# HTTP listener - redirects to HTTPS if domain exists, otherwise forwards
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.domain_name != "" ? "redirect" : "forward"
    
    # Redirect to HTTPS if domain exists
    dynamic "redirect" {
      for_each = var.domain_name != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    
    # Forward to target group if no domain
    target_group_arn = var.domain_name == "" ? aws_lb_target_group.main.arn : null
  }
}

# SSL Certificate (only created if domain is provided)
resource "aws_acm_certificate" "main" {
  count           = var.domain_name != "" ? 1 : 0
  domain_name     = var.domain_name
  validation_method = "DNS"

  tags = local.tags
}

# Certificate validation records
resource "aws_route53_record" "validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "main" {
  count           = var.domain_name != "" ? 1 : 0
  certificate_arn = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

# ---------------------------------------------
# RDS Database for Marketplace API
# ---------------------------------------------

# Private subnets for RDS (security best practice)
# AWS RDS requires a DB Subnet Group with subnets in at least 2 different Availability Zones (AZs)
resource "aws_subnet" "rukmer_marketplace_db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.instance_name}-rukmer-marketplace-db-subnet-1"
  }
}

resource "aws_subnet" "rukmer_marketplace_db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.instance_name}-rukmer-marketplace-db-subnet-2"
  }
}

# Route tables for database subnets 
# Use public route table when db_publicly_accessible is true, private otherwise
resource "aws_route_table" "rukmer_marketplace_db" {
  count  = var.db_publicly_accessible ? 0 : 1
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.instance_name}-rukmer-marketplace-db-rt"
  }
}

resource "aws_route_table_association" "rukmer_marketplace_db_1" {
  subnet_id      = aws_subnet.rukmer_marketplace_db_1.id
  route_table_id = var.db_publicly_accessible ? aws_route_table.public.id : aws_route_table.rukmer_marketplace_db[0].id
}

resource "aws_route_table_association" "rukmer_marketplace_db_2" {
  subnet_id      = aws_subnet.rukmer_marketplace_db_2.id
  route_table_id = var.db_publicly_accessible ? aws_route_table.public.id : aws_route_table.rukmer_marketplace_db[0].id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.rukmer_marketplace_db_1.id, aws_subnet.rukmer_marketplace_db_2.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.instance_name}-rds-sg"
  description = "Security group for RDS PostgreSQL database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  dynamic "ingress" {
    for_each = var.db_publicly_accessible && length(var.allowed_db_cidr_blocks) > 0 ? [1] : []
    content {
      description = "PostgreSQL from allowed IPs"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.allowed_db_cidr_blocks
    }
  }

  tags = {
    Name = "${var.instance_name}-rds-sg"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db-${var.environment}"
  engine         = "postgres"
  engine_version = "15.7"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  publicly_accessible = var.db_publicly_accessible

  backup_retention_period = var.db_backup_retention_days
  backup_window          = "03:00-04:00" 
  maintenance_window     = "sun:04:00-sun:05:00" 

  performance_insights_enabled = false
  monitoring_interval         = 0

  deletion_protection = false  # Allow deletion for dev environment
  skip_final_snapshot = true   # Skip snapshot for faster deletion

  auto_minor_version_upgrade = true

  parameter_group_name = aws_db_parameter_group.main.name

  tags = merge(local.tags, {
    Name = "${var.project_name}-database"
  })

  lifecycle {
    ignore_changes = [password]
  }
}

# Parameter group to disable SSL requirement - allows plain TCP connections
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.project_name}-db-params-${var.environment}"

  parameter {
    name  = "rds.force_ssl"
    value = "0"  # Disable SSL requirement - allows non-SSL connections
  }

  tags = local.tags
}
