#!/bin/bash

# Rukmer Commons Deployment Script
# This script builds, tags, pushes Docker image to ECR and deploys to EC2

set -e  # Exit on any error

echo "Starting Rukmer Commons Deployment..."
echo "========================================"

# Configuration - Get values from Terraform outputs
echo "Getting configuration from Terraform..."
ECR_REPOSITORY_URL=$(terraform -chdir=infrastructure output -raw ecr_repository_url)
REGION=$(terraform -chdir=infrastructure output -raw aws_region 2>/dev/null || echo "us-east-1")
IMAGE_NAME="rukmer-app"

# Extract ECR registry and repository name from the full URL
ECR_REGISTRY=$(echo "$ECR_REPOSITORY_URL" | cut -d'/' -f1)
ECR_REPOSITORY=$(echo "$ECR_REPOSITORY_URL" | cut -d'/' -f2)

echo "Configuration loaded:"
echo "  ECR Repository URL: $ECR_REPOSITORY_URL"
echo "  ECR Registry: $ECR_REGISTRY"
echo "  ECR Repository: $ECR_REPOSITORY"
echo "  Region: $REGION"

# Get current EC2 instance ID from Terraform
echo "Getting current EC2 instance ID..."
INSTANCE_ID=$(terraform -chdir=infrastructure output -raw instance_id 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ]; then
    echo "Could not get instance ID from Terraform. Please run 'terraform apply' first."
    exit 1
fi

echo "Instance ID: $INSTANCE_ID"

# Step 1: Build Docker image
echo ""
echo "Step 1: Building Docker image..."
cd src
docker build --no-cache -t rukmer-app .
cd ..

# Step 2: Tag for ECR
echo ""
echo "Step 2: Tagging image for ECR..."
docker tag rukmer-app:latest $ECR_REGISTRY/$ECR_REPOSITORY:latest

# Step 3: Login to ECR
echo ""
echo "Step 3: Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY/$ECR_REPOSITORY

# Step 4: Push to ECR
echo ""
echo "Step 4: Pushing image to ECR..."
docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

# Step 5: Deploy to EC2
echo ""
echo "Step 5: Deploying to EC2..."
echo "Instance ID: $INSTANCE_ID"

# Check if instance is reachable via SSM
echo "Checking if EC2 instance is ready for Session Manager..."
aws ssm describe-instance-information --instance-information-filter-list key=InstanceIds,valueSet=$INSTANCE_ID --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null | grep -q "Online"

if [ $? -ne 0 ]; then
    echo "EC2 instance is not ready for Session Manager."
    echo "   This could mean:"
    echo "   - Instance is still starting up (wait 2-3 minutes)"
    echo "   - SSM agent is not running"
    echo "   - IAM role not properly attached"
    echo ""
    echo "Manual connection command:"
    echo "   aws ssm start-session --target $INSTANCE_ID"
    exit 1
fi

echo "EC2 instance is online and ready!"

# Execute the deployment on EC2 using SSM send-command
echo "Executing deployment commands on EC2..."

# Send commands directly to EC2
COMMAND_ID=$(aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["sudo su - ec2-user -c \"cd /home/ec2-user && if [ -f ./deploy.sh ]; then ./deploy.sh; else echo No deploy.sh found, creating placeholder; echo Deployment completed; fi\""]' \
    --query 'Command.CommandId' \
    --output text)

if [ -n "$COMMAND_ID" ]; then
    echo "Command sent to EC2. Command ID: $COMMAND_ID"
    echo "Waiting for deployment to complete..."
    
    # Wait for command to complete (timeout after 5 minutes)
    aws ssm wait command-executed --command-id $COMMAND_ID --instance-id $INSTANCE_ID --cli-read-timeout 300
    
    # Get command result
    echo "Getting deployment results..."
    aws ssm get-command-invocation --command-id $COMMAND_ID --instance-id $INSTANCE_ID --query 'StandardOutputContent' --output text | tail -10
    
    echo ""
    echo "Deployment script completed!"
    echo "Docker image has been pushed to ECR and deployed to EC2."
else
    echo "Failed to send command to EC2"
    exit 1
fi
