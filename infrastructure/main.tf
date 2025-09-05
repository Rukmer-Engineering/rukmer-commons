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
