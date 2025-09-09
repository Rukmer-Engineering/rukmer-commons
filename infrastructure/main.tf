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
resource "aws_s3_bucket" "artifacts" {
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

resource "aws_s3_bucket_cors_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

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
# Cognito User Pool for Authentication
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