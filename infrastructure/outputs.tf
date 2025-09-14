output "instance_id" {
  description = "EC2 instance ID for Session Manager"
  value       = aws_instance.main.id
}

output "connect_to_instance" {
  description = "How to connect to your EC2 instance"
  value = <<-EOT
    Connect to EC2 Instance via Session Manager:

    1. Install Session Manager plugin (one-time):
       brew install --cask session-manager-plugin

    2. Connect to your instance:
       aws ssm start-session --target ${aws_instance.main.id}
  EOT
}

output "ecr_repository_url" {
  description = "ECR repository URL for the Elixir application"
  value       = aws_ecr_repository.rukmer_app.repository_url
}

output "docker_commands" {
  description = "Commands to deploy your Elixir Docker image"
  value = <<-EOT
    Build and deploy your Elixir application:
    
    1. Build: docker build -t rukmer-app .
    2. Tag: docker tag rukmer-app:latest ${aws_ecr_repository.rukmer_app.repository_url}:latest
    3. Login: aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.rukmer_app.repository_url}
    4. Push: docker push ${aws_ecr_repository.rukmer_app.repository_url}:latest
    5. Deploy: aws ssm start-session --target ${aws_instance.main.id}
              ./deploy.sh
  EOT
}