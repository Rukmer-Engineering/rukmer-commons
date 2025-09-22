output "instance_id" {
  description = "EC2 instance ID for Session Manager"
  value       = aws_instance.main.id
}

output "ecr_repository_url" {
  description = "ECR repository URL for the Elixir application"
  value       = local.ecr_repository_url
}

output "aws_region" {
  description = "AWS region"
  value       = var.region
}

output "docker_commands" {
  description = "Commands to deploy your Elixir Docker image"
  value = <<EOF

BUILD AND DEPLOY ELIXIR APPLICATION
────────────────────────────────────────

0. Install Session Manager plugin if not installed (one-time):
   brew install --cask session-manager-plugin

1. Build Docker image:
   cd ../src
   docker build --no-cache -t rukmer-app .

2. Tag for ECR:
   docker tag rukmer-app:latest ${local.ecr_repository_url}:latest

3. Login to ECR:
   aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${local.ecr_repository_url}

4. Push to ECR:
   docker push ${local.ecr_repository_url}:latest

5. Deploy to EC2:
   aws ssm start-session --target ${aws_instance.main.id}

6. Run deployment script:
   sudo su - ec2-user
   ./deploy.sh

────────────────────────────────────────
App will be available at: http://[EC2_PUBLIC_IP]:8080/
────────────────────────────────────────
EOF
}

# ---------------------------------------------
# RDS Database Outputs
# ---------------------------------------------

output "database_endpoint" {
  description = "RDS instance endpoint (hostname only)"
  value       = aws_db_instance.main.address
}

output "database_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "database_connection_info" {
  description = "Database connection information for your Elixir app"
  value = <<EOF

DATABASE CONNECTION DETAILS
────────────────────────────────────────
Add these to your Elixir app configuration:

config :rukmer_marketplace, RukmerMarketplace.Repo,
  username: "${aws_db_instance.main.username}",
  password: "${var.db_password}",
  hostname: "${aws_db_instance.main.address}",
  database: "${aws_db_instance.main.db_name}",
  port: ${aws_db_instance.main.port},
  pool_size: ${var.db_pool_size}

Environment variables for production:
DATABASE_URL=postgresql://${aws_db_instance.main.username}:${var.db_password}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}

────────────────────────────────────────
EOF
  sensitive = true
}