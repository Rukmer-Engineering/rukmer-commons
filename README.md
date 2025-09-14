# Rukmer Commons

A containerized Elixir marketplace platform for drone software distribution, enabling publishers to distribute C++ packages and subscribers to manage drone fleets.

## Architecture Overview

- **Elixir + Phoenix**: Web application framework with LiveView
- **Docker**: Containerized deployment
- **AWS ECR**: Private container registry
- **AWS EC2**: Application hosting with Session Manager access
- **AWS S3**: Artifact storage for drone software packages
- **AWS Cognito**: User authentication and authorization
- **Terraform**: Infrastructure as Code

### Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Docker Desktop** installed and running
3. **Terraform** installed
4. **Session Manager plugin** for AWS CLI

```bash
# Install Session Manager plugin (macOS)
brew install --cask session-manager-plugin
```

### Initial Setup

1. **Configure Terraform variables**
   ```bash
   cd infrastructure
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your AWS configuration
   ```

2. **Initialize and deploy infrastructure**
   ```bash
   cd infrastructure
   terraform init
   terraform plan
   terraform refresh
   terraform apply
   ```

3. **Get deployment commands**
   ```bash
   terraform output docker_commands
   ```

## Development Workflow

### Local Development

```bash
# Navigate to the src directory
cd src

# Build and test locally
docker build --no-cache -t rukmer-app .
docker run -p 4000:4000 rukmer-app
```

### Deploy to Production

1. **Build and push to ECR**
    Use the terraform output to get build instructions
    ```bash
    cd infrastructure & terraform output docker_commands
    ```

    The terraform output (once terraform has been applied at least once), should have the following
    ```bash
    # Build application (from src directory) - ARM64 for Graviton EC2
    docker build --no-cache -t rukmer-app .

    # Tag for ECR (use output from terraform)
    docker tag rukmer-app:latest {YOUR_ECR_URL}:latest

    # Authenticate with ECR
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ECR_URL

    # Push to registry
    docker push YOUR_ECR_URL:latest
    ```

2. **Deploy to EC2**
   ```bash
    # Find the EC2 instance running the Elixir app if it has previously been deployed
    aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],IamInstanceProfile.Arn]' --output table

    # Connect to EC2 instance
    aws ssm start-session --target YOUR_INSTANCE_ID

    # Switch to ec2-user (deploy.sh is in ec2-user's home directory)
    sudo su - ec2-user

    # Run deployment script
    ./deploy.sh
   ```

## Infrastructure Management

### Terraform Commands

```bash
# Change directory to infrastructure
cd infrastructure

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Refresh state and apply changes
terraform refresh
terraform apply

# View outputs
terraform destroy

# View outputs
terraform output

# alternatively you can use the one-liner commands at the root level
terraform -chdir=infrastructure init
terraform -chdir=infrastructure plan
terraform -chdir=infrastructure refresh
terraform -chdir=infrastructure apply
terraform -chdir=infrastructure output
terraform -chdir=infrastructure destroy
...

cd infrastructure & terraform init
cd infrastructure & terraform plan
cd infrastructure & terraform refresh
cd infrastructure & terraform apply
cd infrastructure & terraform output
cd infrastructure & terraform destroy
...
```


### Useful Debugging Commands

```bash
# list all remote S3 buckets
aws s3 ls

# List all remote EC2 instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],IamInstanceProfile.Arn]' --output table

# Log in to remote EC2 instance
aws ssm start-session --target INSTANCE_ID

# List all docker commands for local image building and remote image management
cd infrastructure & terraform output docker_commands

# list all ec2 remote session management commands
cd infrastructure & terraform output connect_to_instance

# Check EC2 instance status
aws ssm describe-instance-information

# View application logs in EC2
aws ssm start-session --target INSTANCE_ID
docker logs app --tail 50

# Check container status in EC2
docker ps -a

# Test health endpoint in EC2
curl http://PUBLIC_IP/api/health
```

## Next Steps

1. Implement AWS Cognito authentication
2. Add S3 artifact upload functionality
3. Create publisher and subscriber workflows
4. Implement drone registration system
5. Add real-time coordination features
