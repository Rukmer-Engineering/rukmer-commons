output "instance_id" {
  description = "EC2 instance ID for Session Manager"
  value       = aws_instance.main.id
}

output "connect_to_instance" {
  description = "How to connect to your EC2 instance"
  value = <<EOF

CONNECT TO EC2 INSTANCE
────────────────────────────────────────

1. Install Session Manager plugin (one-time):
   brew install --cask session-manager-plugin

2. Connect to your instance:
   aws ssm start-session --target ${aws_instance.main.id}

────────────────────────────────────────
EOF
}

output "ecr_repository_url" {
  description = "ECR repository URL for the Elixir application"
  value       = local.ecr_repository_url
}

output "docker_commands" {
  description = "Commands to deploy your Elixir Docker image"
  value = <<EOF

BUILD AND DEPLOY ELIXIR APPLICATION
────────────────────────────────────────

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
App will be available at: http://[EC2_PUBLIC_IP]/
────────────────────────────────────────
EOF
}