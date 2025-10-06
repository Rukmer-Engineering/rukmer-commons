# ---------------------------------------------
# Outputs for Local Development
# ---------------------------------------------

output "phoenix_env_vars" {
  description = "Environment variables for local Phoenix development - copy/paste into terminal"
  value = <<-EOT
    # Copy and paste these into your terminal:
    export SECRET_KEY_BASE="${var.phoenix_secret_key_base}"
    export SIGNING_SALT="${var.phoenix_signing_salt}"
    export COGNITO_USER_POOL_ID="${aws_cognito_user_pool.main.id}"
    export COGNITO_CLIENT_ID="${aws_cognito_user_pool_client.client.id}"
    export AWS_REGION="${var.region}"
  EOT
  sensitive = true
}

# ---------------------------------------------
# Outputs for Deployment Scripts
# ---------------------------------------------

output "ecr_repository_url" {
  description = "ECR repository URL (used by local_deploy.sh)"
  value       = local.ecr_repository_url
}

output "aws_region" {
  description = "AWS region (used by deployment scripts)"
  value       = var.region
}

output "instance_id" {
  description = "EC2 instance ID (used by local_deploy.sh)"
  value       = aws_instance.main.id
}

