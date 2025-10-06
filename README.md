# Rukmer Commons

A containerized Elixir marketplace platform for drone software distribution, enabling publishers to distribute C++ packages and subscribers to manage drone fleets.

## Architecture Overview

- **Elixir + Phoenix LiveView**: Real-time web UI with authentication
- **AWS Cognito**: User authentication and authorization
- **Docker**: Containerized deployment
- **AWS ECR**: Private container registry
- **AWS EC2**: Application hosting with Session Manager access
- **AWS RDS (PostgreSQL)**: Database for application data
- **AWS S3**: Artifact storage for drone software packages
- **Terraform**: Infrastructure as Code

### Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Docker Desktop** installed and running
3. **Terraform** installed
4. **Session Manager plugin** for AWS CLI
5. **Elixir & Erlang** (for local Phoenix development)

```bash
# Install Session Manager plugin (macOS)
brew install --cask session-manager-plugin

# Install Elixir/Erlang via asdf (for local development)
brew install asdf
asdf install erlang 27.0
asdf install elixir 1.18.4-otp-27
asdf global erlang 27.0
asdf global elixir 1.18.4-otp-27
```

## Quick Start

### 1. Sync with Terraform Cloud

```bash
# Clone the repository
cd rukmer-commons/infrastructure

# Login to Terraform Cloud (syncs remote state)
terraform login

# Refresh local state from cloud
terraform refresh
```

**Note:** The infrastructure is already deployed and managed via Terraform Cloud. You just need to sync the state locally.

### 2. Local Development (Phoenix LiveView)

**Option A: Automated (Recommended)**
```bash
# From project root - handles everything automatically
./start_dev.sh
```

**Option B: Manual**
```bash
# Get environment variables from Terraform
cd infrastructure
terraform output -raw phoenix_env_vars
# Copy and paste the export commands into your terminal

# Start Phoenix server
cd ../src/marketplace-api
mix deps.get
mix phx.server
```

Visit: http://localhost:4000

**See [src/marketplace-api/SETUP.md](src/marketplace-api/SETUP.md) for detailed setup instructions.**

### 3. Deploy Application to Production

**Option A: Automated (Recommended)**
```bash
# From project root - builds, pushes, and deploys automatically
./local_deploy.sh
```

**Option B: Manual Steps** (see Manual Deployment Steps below)

## Manual Deployment Steps

### Build and Push Docker Image to ECR

```bash
# Get configuration from Terraform
cd infrastructure
export ECR_URL=$(terraform output -raw ecr_repository_url)
export REGION=$(terraform output -raw aws_region)

# Build Docker image (ARM64 for Graviton EC2)
cd ../src
docker build --no-cache -t rukmer-app .

# Tag for ECR
docker tag rukmer-app:latest $ECR_URL:latest

# Login to ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $ECR_URL

# Push to ECR
docker push $ECR_URL:latest
```

### Deploy to EC2

```bash
# Connect to EC2 instance via Session Manager
aws ssm start-session --target $INSTANCE_ID

# Once connected, switch to ec2-user
sudo su - ec2-user

# Run deployment script
./deploy.sh
```

## Port Configuration

- **Internal (Container)**: Port `4000` - Elixir app runs inside Docker container
- **External (EC2)**: Port `8080` - Accessible from outside the container
- **Local Development (Phoenix)**: Port `4000` - Phoenix server runs directly (no Docker)
- **Local Development (Docker)**: Port `8080` - When testing with `docker run -p 8080:4000`

## Infrastructure Management

### Terraform Commands

```bash
# From infrastructure directory
cd infrastructure
terraform init
terraform plan
terraform apply
terraform output
terraform destroy

# OR from project root using -chdir
terraform -chdir=infrastructure init
terraform -chdir=infrastructure plan
terraform -chdir=infrastructure apply
terraform -chdir=infrastructure output
terraform -chdir=infrastructure destroy
```

### Useful Terraform Outputs

```bash
# Get all Phoenix environment variables for local development
terraform -chdir=infrastructure output -raw phoenix_env_vars

# Get ECR repository URL
terraform -chdir=infrastructure output -raw ecr_repository_url

# Get EC2 instance ID
terraform -chdir=infrastructure output -raw instance_id

# Get AWS region
terraform -chdir=infrastructure output -raw aws_region
```


### Debugging Commands

```bash
# List all EC2 instances
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Check EC2 instance status for Session Manager
aws ssm describe-instance-information

# Connect to EC2 instance
export INSTANCE_ID=$(terraform -chdir=infrastructure output -raw instance_id)
aws ssm start-session --target $INSTANCE_ID

# View application logs (run inside EC2)
docker logs app --tail 50

# Check container status (run inside EC2)
docker ps -a

# Terraform state management
cd infrastructure
terraform state list
terraform state rm aws_instance.main  # Remove divergent resource
terraform import aws_instance.main NEW_INSTANCE_ID  # Re-import existing resource

# List S3 buckets
aws s3 ls
```

## Project Structure

```
rukmer-commons/
├── infrastructure/          # Terraform infrastructure code
│   ├── main.tf             # Main infrastructure definitions
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   └── terraform.tfvars    # Secret values (gitignored)
├── src/
│   └── marketplace-api/    # Phoenix LiveView application
│       ├── lib/
│       │   ├── marketplace_api/      # Business logic (services, models)
│       │   └── marketplace_api_web/  # Web interface (LiveView, endpoint, router)
│       ├── config/         # Application configuration
│       └── mix.exs         # Elixir dependencies
├── local_deploy.sh         # Automated deployment script
└── start_dev.sh           # Automated local development setup
```

## Next Steps

1. ✅ AWS Cognito authentication (implemented with Phoenix LiveView)
2. Add S3 artifact upload functionality
3. Create publisher and subscriber workflows
4. Implement drone registration system
5. Add real-time coordination features
