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
  value       = local.ecr_repository_url
}

output "docker_commands" {
  description = "Commands to deploy your Elixir Docker image"
  value = <<-EOT
    Build and deploy your Elixir application:
    
    1. Build a new image: 
    cd ../src && docker build --no-cache -t rukmer-app .
    2. Tag the new image: 
    docker tag rukmer-app:latest ${local.ecr_repository_url}:latest
    3. Login to ECR: 
    aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${local.ecr_repository_url}
    4. Push the new image to ECR repository: 
    docker push ${local.ecr_repository_url}:latest
    5. Deploy to EC2: 
    aws ssm start-session --target ${aws_instance.main.id}
    6. Run the deployment script in EC2:
    sudo su - ec2-user
    ./deploy.sh
  EOT
}